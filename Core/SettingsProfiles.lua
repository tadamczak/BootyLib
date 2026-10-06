local Lib = BootyLib
local Profiles = {}
Lib.Core.SettingsProfiles = Profiles
local settingTypes = {checkbox=true,slider=true,color=true,choice=true,dropdown=true,text=true,number=true,percentage=true}

local function Name(value)
    local name=string.gsub(string.gsub(tostring(value or ""),"^%s+",""),"%s+$","")
    if name=="" or string.len(name)>64 or string.find(name,"[%c]") then return nil end
    return name
end
local function Copy(value, copies, active)
    local kind=type(value)
    if kind=="number" then if value~=value or value-value~=0 then error("Invalid profile number.") end;return value end
    if kind=="nil" or kind=="string" or kind=="boolean" then return value end
    if kind~="table" then error("Unsupported profile value: "..kind) end
    copies,active=copies or {},active or {}
    if active[value] then error("Cyclic profile value.") end
    if copies[value] then return copies[value] end
    local target={};copies[value],active[value]=target,true
    for key,child in pairs(value) do
        if type(key)~="string" and type(key)~="number" then error("Unsupported profile key.") end
        target[Copy(key,copies,active)]=Copy(child,copies,active)
    end
    active[value]=nil
    return target
end
Profiles.Copy=Copy
local function Equal(a,b,seen)
    if type(a)~=type(b) then return false end
    if type(a)~="table" then return a==b end
    seen=seen or {};if seen[a]==b then return true end;seen[a]=b
    for key,value in pairs(a) do if not Equal(value,b[key],seen) then return false end end
    for key in pairs(b) do if a[key]==nil then return false end end
    return true
end
local function IsSetting(field)
    return field.profile~=false and field.persist~=false and settingTypes[field.type or "text"] and type(field.key)=="string"
end
local function Read(field,db)
    local value
    if field.get then value=field.get(db) else value=db[field.key] end
    if value==nil then return field.default end
    return value
end
local function WriteField(field,db,value)
    if field.set then field.set(value,db) else db[field.key]=value end
end
local function Saved(profile,id,field)
    local section=profile.version==2 and profile.providers and profile.providers[id]
    if section and type(section.settings)=="table" then
        if section.keys and section.keys[field.key] or section.settings[field.key]~=nil then return true,section.settings[field.key] end
    end
    local legacy=profile.version==1 and profile or profile.legacy
    local key=field.legacyKey or field.key
    if type(legacy)=="table" and type(legacy.settings)=="table" and field.legacyGet then
        local value=field.legacyGet(legacy.settings)
        if value~=nil then return true,value end
    end
    if type(legacy)=="table" and type(legacy.settings)=="table" then
        local value=legacy.settings[key]
        if field.readLegacy then value=field.readLegacy(value,legacy.settings) end
        if value~=nil then return true,value end
    end
    return false
end
local function Valid(profile)
    return type(profile)=="table" and (profile.version==1 and type(profile.settings)=="table"
        or profile.version==2 and type(profile.providers)=="table")
end
local function Keys(value)
    local keys={};for key in pairs(value) do table.insert(keys,key) end
    table.sort(keys,function(a,b) if type(a)==type(b) then return a<b end;return type(a)<type(b) end)
    return keys
end
local function Encode(value)
    if type(value)=="string" then return string.format("%q",value) end
    if type(value)~="table" then return tostring(value) end
    local pieces={}
    for _,key in ipairs(Keys(value)) do table.insert(pieces,"["..Encode(key).."]="..Encode(value[key])) end
    return "{"..table.concat(pieces,",").."}"
end
local function Groups(changes)
    local byId,groups={},{}
    for _,change in ipairs(changes) do
        local group=byId[change.provider.id]
        if not group then group={provider=change.provider,keys={},changes={}};byId[change.provider.id]=group;table.insert(groups,group) end
        group.keys[change.field.key]=true;table.insert(group.changes,change)
    end
    return groups
end
local function BeginBatches(groups)
    for _,group in ipairs(groups) do
        if group.provider.BeginSettingsBatch then group.begun=true;group.provider.BeginSettingsBatch() end
    end
end
local function EndBatches(groups,success)
    local failure
    for index=table.getn(groups),1,-1 do
        local group=groups[index]
        if group.begun and group.provider.EndSettingsBatch then
            local ok,message=pcall(group.provider.EndSettingsBatch,success)
            if not ok and not failure then failure=tostring(message) end
        end
        group.begun=nil
    end
    return failure==nil,failure
end
local function Rollback(changes,written)
    for index=written,1,-1 do local change=changes[index];pcall(WriteField,change.field,change.db,change.old) end
    for index=1,written do
        local change=changes[index]
        if not change.provider.OnSettingsProfileApplied and change.field.onChange then pcall(change.field.onChange,change.old) end
    end
end

-- A context sees only loaded providers' declared preferences. Histories and
-- absent products are never instantiated; existing profile payloads remain.
function Profiles.Create(providers,options)
    options=options or {}
    local context={id=options.id or "suite",providers=providers or {}}
    local function Root()
        local root=options.store or Lib.Data.Get("lib")
        if type(root)~="table" then error("Shared profile data is unavailable.") end
        if type(root.settingsProfiles)~="table" then root.settingsProfiles={} end
        if type(root.currentSettingsProfiles)~="table" then root.currentSettingsProfiles={} end
        return root
    end
    local function Schemas(callback)
        for _,provider in ipairs(context.providers) do
            local schema=provider.GetSettings and provider.GetSettings()
            if schema and type(schema.db)=="table" then
                for _,field in ipairs(schema.fields or {}) do if IsSetting(field) then callback(provider,schema.db,field) end end
            end
        end
    end
    local function Select(name)
        local root=Root();root.currentSettingsProfiles[context.id]=name
        if context.id=="suite" then root.currentSettingsProfile=name end
    end
    local function Capture(previous)
        local snapshot
        if previous and previous.version==2 then snapshot=Copy(previous)
        else snapshot={version=2,providers={}};if previous then snapshot.legacy=Copy(previous) end end
        snapshot.providers=snapshot.providers or {}
        Schemas(function(provider,db,field)
            local section=snapshot.providers[provider.id]
            if not section then section={settings={},keys={}};snapshot.providers[provider.id]=section end
            section.settings=section.settings or {};section.keys=section.keys or {}
            section.settings[field.key]=Copy(Read(field,db));section.keys[field.key]=true
        end)
        return snapshot
    end
    local function Save(name,add)
        name=Name(name);if not name then return false,"Enter a profile name (1-64 characters)." end
        local profiles=Root().settingsProfiles
        if add and profiles[name] then return false,"This profile already exists. Use Save to update it." end
        if not add and not profiles[name] then return false,"Profile not found. Use Add first." end
        local ok,snapshot=pcall(Capture,profiles[name])
        if not ok then return false,tostring(snapshot) end
        profiles[name]=snapshot
        return true,"Saved profile: "..name
    end
    local function Notify(changes,groups)
        for _,change in ipairs(changes) do
            if not change.provider.OnSettingsProfileApplied and change.field.onChange then change.field.onChange(change.value) end
        end
        for _,group in ipairs(groups) do
            local provider=group.provider
            if provider.OnSettingsProfileApplied then provider.OnSettingsProfileApplied(group.keys)
            else
                if provider.OnSettingChanged then provider.OnSettingChanged("profile") end
                if provider.OnSettingsChanged then provider.OnSettingsChanged("profile") end
            end
        end
    end
    function context.List()
        local names={};for name in pairs(Root().settingsProfiles) do if type(name)=="string" then table.insert(names,name) end end
        table.sort(names);return names
    end
    function context.Exists(name) return Root().settingsProfiles[Name(name) or ""]~=nil end
    function context.CanAdd(name)
        name=Name(name);if not name then return false,"Enter a profile name (1-64 characters)." end
        if context.Exists(name) then return false,"This profile already exists." end
        return true
    end
    function context.GetCurrent()
        local root=Root()
        local name=root.currentSettingsProfiles[context.id] or context.id=="suite" and root.currentSettingsProfile
        if name then return name end
        local base=options.defaultName or (context.id=="suite" and "Default" or (context.providers[1] and context.providers[1].name or "Booty").." Default")
        local index=1;name=base
        while context.Exists(name) do index=index+1;name=base.." "..index end
        local ok,failure=Save(name,true);if not ok then error(failure) end
        Select(name);return name
    end
    function context.Add(name)
        local ok,message=Save(name,true)
        if ok then Select(Name(name));if options.onApplied then options.onApplied() end end
        return ok,message
    end
    function context.Save(name) return Save(name,false) end
    function context.SaveCurrent()
        local name=context.GetCurrent();return Save(name,not context.Exists(name))
    end
    function context.IsDirty()
        local profile=Root().settingsProfiles[context.GetCurrent()]
        if not Valid(profile) then return true end
        local dirty=false
        Schemas(function(provider,db,field)
            local found,saved=Saved(profile,provider.id,field)
            if not found then saved=nil end
            if not Equal(saved,Read(field,db)) then dirty=true end
        end)
        return dirty
    end
    function context.Load(name)
        name=Name(name)
        local profile=Root().settingsProfiles[name or ""]
        if not Valid(profile) then return false,"Profile not found or unsupported." end
        local changes={}
        local ok,failure=pcall(function()
            Schemas(function(provider,db,field)
                local found,value=Saved(profile,provider.id,field)
                if found then table.insert(changes,{provider=provider,db=db,field=field,value=Copy(value),old=Copy(Read(field,db))}) end
            end)
        end)
        if not ok then return false,tostring(failure) end
        local written=0
        local groups=Groups(changes)
        ok,failure=pcall(function()
            BeginBatches(groups)
            for index,change in ipairs(changes) do written=index;WriteField(change.field,change.db,change.value) end
            Notify(changes,groups)
        end)
        if not ok then
            Rollback(changes,written);EndBatches(groups,false)
            return false,tostring(failure)
        end
        ok,failure=EndBatches(groups,true)
        if not ok then return false,tostring(failure) end
        Select(name);if options.onApplied then options.onApplied() end
        return true,"Loaded profile: "..name
    end
    function context.Delete(name)
        name=Name(name);local profiles=Root().settingsProfiles
        if not name or not profiles[name] then return false,"Profile not found." end
        profiles[name]=nil
        return true,"Deleted profile: "..name
    end
    function context.ResetDefaults(selected)
        local changes,groups={},{}
        local ok,failure=pcall(function()
            Schemas(function(provider,db,field)
                if not selected or selected[field.key] then
                    local change={provider=provider,db=db,field=field,value=Copy(field.default),old=Copy(Read(field,db))}
                    table.insert(changes,change)
                end
            end)
        end)
        if not ok then return false,tostring(failure) end
        groups=Groups(changes)
        ok,failure=pcall(function()
            BeginBatches(groups)
            for _,group in ipairs(groups) do
                -- Computed/masked preferences may clear different durable keys.
                -- Their product owns that policy and its exact default values.
                if group.provider.ResetSettings then group.provider.ResetSettings(group.keys)
                else for _,change in ipairs(group.changes) do WriteField(change.field,change.db,change.value) end end
                if group.provider.GetDatabase then group.provider.GetDatabase()
                elseif group.provider.GetSettings then group.provider.GetSettings() end
            end
            for _,change in ipairs(changes) do change.value=Read(change.field,change.db) end
            Notify(changes,groups)
        end)
        if not ok then
            Rollback(changes,table.getn(changes));EndBatches(groups,false)
            return false,tostring(failure)
        end
        ok,failure=EndBatches(groups,true);if not ok then return false,tostring(failure) end
        if options.onApplied then options.onApplied() end
        return true,"Reset settings to defaults."
    end
    function context.Export(name)
        name=Name(name);local profile=Root().settingsProfiles[name or ""]
        if not Valid(profile) then return nil,"Profile not found or unsupported. Save or Add it first." end
        local ok,text=pcall(function()
            local checked=Copy(profile)
            local lines={checked.version==1 and "MOS_SETTINGS_PROFILE_V1" or "BOOTY_SETTINGS_PROFILE_V2","name="..Encode(name)}
            if checked.version==1 then
                for _,key in ipairs(Keys(checked.settings or {})) do
                    local value=checked.settings[key]
                    if type(value)=="table" and table.getn(value)==3 then value="["..Encode(value[1])..","..Encode(value[2])..","..Encode(value[3]).."]"
                    else value=Encode(value) end
                    table.insert(lines,tostring(key).."="..value)
                end
            else table.insert(lines,"profile="..Encode(checked)) end
            return table.concat(lines,"\n")
        end)
        if not ok then return nil,tostring(text) end
        return text
    end
    return context
end
