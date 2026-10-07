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
local function ReadRaw(field,db)
    local value
    if field.get then value=field.get(db) else value=db[field.key] end
    return value
end
local function Read(field,db)
    local value=ReadRaw(field,db)
    if value==nil then return field.default end
    return value
end
local function Change(provider,db,field,value)
    local raw=ReadRaw(field,db)
    local logical=raw
    if logical==nil then logical=field.default end
    return {provider=provider,db=db,field=field,value=Copy(value),old=Copy(logical),restore=Copy(raw)}
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
        change.group=group
    end
    return groups
end
local function BeginBatches(groups)
    for _,group in ipairs(groups) do
        if group.provider.BeginSettingsBatch then group.begun=true;group.provider.BeginSettingsBatch() end
    end
end
local function EndBatches(groups,success)
    local failures={}
    for index=table.getn(groups),1,-1 do
        local group=groups[index]
        if group.begun and group.provider.EndSettingsBatch then
            local ok,message=pcall(group.provider.EndSettingsBatch,success)
            if ok then group.begun=nil
            else table.insert(failures,tostring(group.provider.id)..": "..tostring(message)) end
        else group.begun=nil end
    end
    return table.getn(failures)==0,table.concat(failures,"; ")
end
local function DurableSnapshots(changes)
    local snapshots,stores={},{}
    local function Capture(change,key)
        local keys=stores[change.db]
        if not keys then keys={};stores[change.db]=keys end
        local snapshot=keys[key]
        if not snapshot then
            snapshot={db=change.db,key=key,value=Copy(rawget(change.db,key)),groups={}}
            keys[key]=snapshot;table.insert(snapshots,snapshot)
        end
        snapshot.groups[change.group]=true
    end
    for _,change in ipairs(changes) do
        Capture(change,change.field.durableKey or change.field.key)
        for _,key in ipairs(change.field.rollbackKeys or {}) do Capture(change,key) end
    end
    return snapshots
end
local function NotifyGroup(group)
    local provider=group.provider
    if provider.OnSettingsProfileApplied then provider.OnSettingsProfileApplied(group.keys)
    else
        if provider.OnSettingChanged then provider.OnSettingChanged("profile") end
        if provider.OnSettingsChanged then provider.OnSettingsChanged("profile") end
    end
end
local function Notify(changes,groups)
    for _,change in ipairs(changes) do
        if not change.provider.OnSettingsProfileApplied and change.field.onChange then change.field.onChange(change.value) end
    end
    for _,group in ipairs(groups) do NotifyGroup(group) end
end
local function Attempt(failures,label,callback,a,b,c)
    local ok,message=pcall(callback,a,b,c)
    if not ok then table.insert(failures,label..": "..tostring(message)) end
    return ok
end
local function RestoreRaw(snapshot) snapshot.db[snapshot.key]=snapshot.value end
local function Rollback(changes,written,groups,snapshots,reapply,original)
    local failures={}
    -- End may fail before releasing its batch or while flushing after release.
    -- Retry cancellation before acquiring a restoration batch. Product End(false)
    -- handlers are idempotent at depth zero; uncertain owners remain diagnostic.
    if reapply then
        for index=table.getn(groups),1,-1 do
            local group=groups[index]
            if group.begun then
                if Attempt(failures,group.provider.id.." cancel batch",group.provider.EndSettingsBatch,false) then group.begun=nil
                else group.rollbackBlocked=true;group.cleanupFailed=true end
            end
        end
        for _,group in ipairs(groups) do
            if group.touched and not group.rollbackBlocked and group.provider.BeginSettingsBatch then
                group.begun=true
                if not Attempt(failures,group.provider.id.." begin restoration",group.provider.BeginSettingsBatch) then
                    group.rollbackBlocked=true
                end
            end
        end
    end
    -- Logical setters restore nested/external preferences; raw owned keys then
    -- preserve absent values, complete masks and declared adapter side effects.
    for index=written,1,-1 do
        local change=changes[index]
        if change.group.touched and change.field.set then
            Attempt(failures,change.provider.id.." restore "..change.field.key,WriteField,change.field,change.db,change.restore)
        end
    end
    for _,snapshot in ipairs(snapshots) do
        local touched=false
        for group in pairs(snapshot.groups) do if group.touched then touched=true;break end end
        if touched then Attempt(failures,"restore durable "..snapshot.key,RestoreRaw,snapshot) end
    end
    for index=1,written do
        local change=changes[index]
        if change.group.touched and not change.group.rollbackBlocked and not change.provider.OnSettingsProfileApplied and change.field.onChange then
            Attempt(failures,change.provider.id.." restore callback "..change.field.key,change.field.onChange,change.old)
        end
    end
    if reapply then
        for _,group in ipairs(groups) do
            if group.touched and not group.rollbackBlocked then Attempt(failures,group.provider.id.." restore owner",NotifyGroup,group) end
        end
    else
        for _,group in ipairs(groups) do
            if group.touched and not group.provider.BeginSettingsBatch then Attempt(failures,group.provider.id.." restore owner",NotifyGroup,group) end
        end
    end
    for index=table.getn(groups),1,-1 do
        local group=groups[index]
        if group.begun and not group.cleanupFailed then
            local apply=reapply and group.touched and not group.rollbackBlocked
            if Attempt(failures,group.provider.id.." end restoration",group.provider.EndSettingsBatch,apply and true or false) then group.begun=nil
            elseif apply then
                if Attempt(failures,group.provider.id.." cancel restoration",group.provider.EndSettingsBatch,false) then group.begun=nil end
            end
        end
    end
    local message=tostring(original)
    if table.getn(failures)>0 then message=message.." Rollback failed: "..table.concat(failures,"; ") end
    return false,message
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
                if found then table.insert(changes,Change(provider,db,field,value)) end
            end)
        end)
        if not ok then return false,tostring(failure) end
        local written=0
        local groups=Groups(changes)
        local snapshots
        ok,snapshots=pcall(DurableSnapshots,changes)
        if not ok then return false,tostring(snapshots) end
        local notifying=false
        ok,failure=pcall(function()
            BeginBatches(groups)
            for index,change in ipairs(changes) do written=index;change.group.touched=true;WriteField(change.field,change.db,change.value) end
            notifying=true
            Notify(changes,groups)
        end)
        if not ok then
            return Rollback(changes,written,groups,snapshots,notifying,failure)
        end
        ok,failure=EndBatches(groups,true)
        if not ok then return Rollback(changes,written,groups,snapshots,true,failure) end
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
                    local change=Change(provider,db,field,field.default)
                    table.insert(changes,change)
                end
            end)
        end)
        if not ok then return false,tostring(failure) end
        groups=Groups(changes)
        local snapshots
        ok,snapshots=pcall(DurableSnapshots,changes)
        if not ok then return false,tostring(snapshots) end
        local notifying=false
        ok,failure=pcall(function()
            BeginBatches(groups)
            for _,group in ipairs(groups) do
                group.touched=true
                -- Computed/masked preferences may clear different durable keys.
                -- Their product owns that policy and its exact default values.
                if group.provider.ResetSettings then group.provider.ResetSettings(group.keys)
                else for _,change in ipairs(group.changes) do WriteField(change.field,change.db,change.value) end end
                if group.provider.GetDatabase then group.provider.GetDatabase()
                elseif group.provider.GetSettings then group.provider.GetSettings() end
            end
            for _,change in ipairs(changes) do change.value=Read(change.field,change.db) end
            notifying=true
            Notify(changes,groups)
        end)
        if not ok then
            return Rollback(changes,table.getn(changes),groups,snapshots,notifying,failure)
        end
        ok,failure=EndBatches(groups,true)
        if not ok then return Rollback(changes,table.getn(changes),groups,snapshots,true,failure) end
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
