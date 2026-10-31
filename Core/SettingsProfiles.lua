local Lib = BootyLib
local Profiles = {}
Lib.Core.SettingsProfiles = Profiles
local settingTypes = {checkbox=true,slider=true,color=true,choice=true,dropdown=true,multiselect=true,text=true,number=true,percentage=true}

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
local function SavedValue(field,value)
    if field.readSaved then return field.readSaved(value) end
    return value
end
local function ProviderSaved(section,field)
    if section and type(section.settings)=="table" then
        if section.keys and section.keys[field.key] or section.settings[field.key]~=nil then return true,SavedValue(field,section.settings[field.key]) end
        if field.legacyKey and field.legacyKey~=field.key and (section.keys and section.keys[field.legacyKey] or section.settings[field.legacyKey]~=nil) then
            local value=section.settings[field.legacyKey]
            if field.readLegacy then value=field.readLegacy(value,section.settings) end
            return true,SavedValue(field,value)
        end
    end
    return false
end
local function Saved(profile,id,field)
    local section=profile.version==2 and profile.providers and profile.providers[id]
    local found,value=ProviderSaved(section,field)
    if found then return true,value end
    local legacy=profile.version==1 and profile or profile.legacy
    local key=field.legacyKey or field.key
    local owner=Lib.Data and Lib.Data.GetOwner and Lib.Data.GetOwner(id)
    -- New product preferences can reuse an old shell key. Explicit V2 sections
    -- remain authoritative; unscoped data follows that key's legacy owner.
    -- Schema adapters for shared preferences retain their existing behavior.
    if owner and owner.OwnsLegacyField and owner.OwnsField(key) and not owner.OwnsLegacyField(key) then return false end
    -- Unscoped V1 keys belong to the declared legacy namespace. Only an
    -- explicit retiredKey rename permits its new spelling in the old shape.
    if field.retiredKey and type(legacy)=="table" and type(legacy.settings)=="table" and legacy.settings[field.key]~=nil then
        return true,SavedValue(field,legacy.settings[field.key])
    end
    if type(legacy)=="table" and type(legacy.settings)=="table" and field.legacyGet then
        local value=field.legacyGet(legacy.settings)
        if value~=nil then return true,SavedValue(field,value) end
    end
    if type(legacy)=="table" and type(legacy.settings)=="table" then
        local value=legacy.settings[key]
        if field.readLegacy then value=field.readLegacy(value,legacy.settings) end
        if value~=nil then return true,SavedValue(field,value) end
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
    local protectedName
    for _,provider in ipairs(context.providers) do
        if provider.id==context.id then protectedName=Name(provider.protectedProfileName) end
    end
    function context.IsProtected(name) return protectedName~=nil and Name(name)==protectedName end
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
    local checkedStore
    local function Store()
        local root=Root()
        if not options.scoped then return root.settingsProfiles end
        local function Owns(source,name)
            if source.owner then return source.owner==context.id end
            if context.id=="suite" then return source.addonProfiles~=nil or source.providers and source.providers.suite~=nil or root.currentSettingsProfile==name end
            if source.addonProfiles or source.providers and source.providers.suite then return false end
            if root.currentSettingsProfiles[context.id]==name then return true end
            if source.version~=2 then return false end
            for id in pairs(source.providers) do if id~=context.id then return false end end
            return source.providers[context.id]~=nil
        end
        local existing=root.addonSettingsProfiles and root.addonSettingsProfiles[context.id]
        if existing then
            if checkedStore==existing then return existing end
            for name,profile in pairs(existing) do
                if not profile.owner then
                    local source=root.settingsProfiles[name]
                    -- Remove only unchanged broad imports; the complete source
                    -- remains in the retained legacy store. Authored edits stay.
                    if Valid(source) and not Owns(source,name) and source.providers and profile.providers
                        and source.providers[context.id] and profile.providers[context.id]
                        and Equal(source.providers[context.id].settings,profile.providers[context.id].settings) then existing[name]=nil
                    else profile.owner=context.id end
                end
            end
            checkedStore=existing;return existing
        end
        -- Copy owned values from old shared profiles once. Retain the original
        -- payloads, including unknown/absent owners, for lossless compatibility.
        local profiles={}
        for name,source in pairs(root.settingsProfiles) do
            if Valid(source) and Owns(source,name) then
                local snapshot={version=2,owner=context.id,providers={}}
                if context.id=="suite" then snapshot=Copy(source);snapshot.owner="suite";snapshot.providers=snapshot.providers or {} end
                if source.version==2 then
                    for _,provider in ipairs(context.providers) do
                        if source.providers[provider.id] then snapshot.providers[provider.id]=Copy(source.providers[provider.id]) end
                    end
                end
                Schemas(function(provider,db,field)
                    local found,value=Saved(source,provider.id,field)
                    if found then
                        local section=snapshot.providers[provider.id] or {settings={},keys={}}
                        snapshot.providers[provider.id]=section;section.settings=section.settings or {};section.keys=section.keys or {}
                        section.settings[field.key]=Copy(value);section.keys[field.key]=true
                    end
                end)
                if next(snapshot.providers) then profiles[name]=snapshot end
            end
        end
        root.addonSettingsProfiles=root.addonSettingsProfiles or {};root.addonSettingsProfiles[context.id]=profiles
        checkedStore=profiles
        return profiles
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
        snapshot.owner=context.id
        Schemas(function(provider,db,field)
            local section=snapshot.providers[provider.id]
            if not section then section={settings={},keys={}};snapshot.providers[provider.id]=section end
            section.settings=section.settings or {};section.keys=section.keys or {}
            section.settings[field.key]=Copy(Read(field,db));section.keys[field.key]=true
            if field.retiredKey and field.retiredKey~=field.key then
                section.settings[field.retiredKey],section.keys[field.retiredKey]=nil,nil
            end
        end)
        return snapshot
    end
    function context.PrepareCurrentSnapshot()
        local profiles=Store()
        local name=Name(Root().currentSettingsProfiles[context.id])
        if context.IsProtected(name) and not context.IsDirty() then
            return {store=profiles,id=context.id,name=name,snapshot=Copy(profiles[name])}
        end
        if not name or not Valid(profiles[name]) or context.IsProtected(name) then
            local base=(context.providers[1] and context.providers[1].name or "Booty").." custom"
            local index=1;name=base
            while profiles[name] do index=index+1;name=base.." "..index end
        end
        return {store=profiles,id=context.id,name=name,snapshot=Capture(profiles[name])}
    end
    local function PublishChildren(pending)
        for _,entry in ipairs(pending) do entry.store[entry.name]=entry.snapshot;Root().currentSettingsProfiles[entry.id]=entry.name end
    end
    local function Save(name,add)
        name=Name(name);if not name then return false,"Enter a profile name (1-64 characters)." end
        local profiles=Store()
        if context.IsProtected(name) then return false,"This profile is protected. Use Add to save a custom copy." end
        if add and profiles[name] then return false,"This profile already exists. Use Save to update it." end
        if not add and not profiles[name] then return false,"Profile not found. Use Add first." end
        local pending={}
        local ok,snapshot=pcall(function()
            local captured=Capture(profiles[name])
            if context.addons then
                captured.addonProfiles=captured.addonProfiles or {}
                for _,id in ipairs(context.addonOrder) do
                    local entry=context.addons[id].PrepareCurrentSnapshot()
                    table.insert(pending,entry);captured.addonProfiles[id]=entry.name
                    captured.providers[id]=Copy(entry.snapshot.providers[id])
                end
            end
            return captured
        end)
        if not ok then return false,tostring(snapshot) end
        PublishChildren(pending);profiles[name]=snapshot
        return true,"Saved profile: "..name
    end
    function context.List()
        local names={};for name in pairs(Store()) do if type(name)=="string" then table.insert(names,name) end end
        table.sort(names);return names
    end
    function context.Exists(name) return Store()[Name(name) or ""]~=nil end
    function context.CanAdd(name)
        name=Name(name);if not name then return false,"Enter a profile name (1-64 characters)." end
        if context.Exists(name) then return false,"This profile already exists." end
        return true
    end
    function context.GetCurrent()
        local root=Root()
        local name=root.currentSettingsProfiles[context.id] or context.id=="suite" and root.currentSettingsProfile
        if name and (not options.scoped or context.Exists(name)) then return name end
        if protectedName and context.Exists(protectedName) then Select(protectedName);return protectedName end
        local base=options.defaultName or (context.id=="suite" and "Default" or (context.providers[1] and context.providers[1].name or "Booty")..(options.scoped and " custom" or " Default"))
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
        local profile=Store()[context.GetCurrent()]
        if not Valid(profile) then return true end
        local dirty=false
        Schemas(function(provider,db,field)
            local source=profile
            local selected=context.addons and profile.addonProfiles and profile.addonProfiles[provider.id]
            if selected and context.addons[provider.id] then source=context.addons[provider.id].GetStore()[selected] or profile end
            local found,saved=Saved(source,provider.id,field)
            if not found then saved=nil end
            if not Equal(saved,Read(field,db)) then dirty=true end
        end)
        if context.addons and profile.addonProfiles then
            for _,id in ipairs(context.addonOrder) do
                if profile.addonProfiles[id] and profile.addonProfiles[id]~=Root().currentSettingsProfiles[id] then dirty=true end
            end
        end
        return dirty
    end
    function context.Load(name)
        name=Name(name)
        local profile=Store()[name or ""]
        if not Valid(profile) then return false,"Profile not found or unsupported." end
        local changes,pending={},{}
        local effective=profile
        local ok,failure=pcall(function()
            if context.addons and profile.addonProfiles then
                effective=Copy(profile)
                for _,id in ipairs(context.addonOrder) do
                    local selected=profile.addonProfiles[id]
                    if selected then
                        assert(Name(selected),"Invalid addon profile name.")
                        local childStore=context.addons[id].GetStore()
                        local child=childStore[selected]
                        local section=child and child.providers and child.providers[id] or profile.providers and profile.providers[id]
                        assert(type(section)=="table" and type(section.settings)=="table","Missing addon profile snapshot: "..id)
                        effective.providers[id]=Copy(section)
                        table.insert(pending,{store=childStore,id=id,name=selected,snapshot=child or {version=2,owner=id,providers={[id]=Copy(section)}}})
                    end
                end
            end
            Schemas(function(provider,db,field)
                local found,value=Saved(effective,provider.id,field)
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
        PublishChildren(pending);Select(name);if options.onApplied then options.onApplied() end
        return true,"Loaded profile: "..name
    end
    function context.Delete(name)
        name=Name(name);local profiles=Store()
        if not name or not profiles[name] then return false,"Profile not found." end
        if context.IsProtected(name) then return false,"This profile is protected and cannot be deleted." end
        profiles[name]=nil
        if options.scoped and Root().currentSettingsProfiles[context.id]==name then Select(nil) end
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
        name=Name(name);local profile=Store()[name or ""]
        if not Valid(profile) then return nil,"Profile not found or unsupported. Save or Add it first." end
        local ok,text=pcall(function()
            local checked=Copy(profile)
            -- Preserve the version and normalize only declared owned values in
            -- this copy. Never capture current preferences or create an absent
            -- provider; unknown data and the retained legacy source survive.
            Schemas(function(provider,db,field)
                if not field.retiredKey and not field.readSaved then return end
                local settings,keys,found,value
                if checked.version==1 then
                    settings=checked.settings
                    found,value=Saved(checked,provider.id,field)
                else
                    local section=checked.providers[provider.id]
                    if section and type(section.settings)=="table" then
                        settings,keys=section.settings,section.keys
                        found,value=ProviderSaved(section,field)
                    end
                end
                if found then
                    settings[field.key]=Copy(value)
                    if keys then keys[field.key]=true end
                    if field.retiredKey and field.retiredKey~=field.key then
                        settings[field.retiredKey]=nil
                        if keys then keys[field.retiredKey]=nil end
                    end
                end
            end)
            local lines={checked.version==1 and "BOOTY_SETTINGS_PROFILE_V1" or "BOOTY_SETTINGS_PROFILE_V2","name="..Encode(name)}
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
    context.GetStore=Store
    if protectedName then
        local profiles=Store()
        -- Capture the live settings once, after SavedVariables/defaults load.
        -- Later activations and Suite saves must never replace this baseline.
        if not profiles[protectedName] or not profiles[protectedName].protected then
            local snapshot=Capture();snapshot.protected=true;profiles[protectedName]=snapshot
        end
    end
    if options.bundle then
        context.addons,context.addonOrder={},{}
        for _,provider in ipairs(context.providers) do
            local schema=provider.id~=context.id and provider.id~="lib" and provider.GetSettings and provider.GetSettings()
            local available=false
            if schema and type(schema.db)=="table" then
                for _,field in ipairs(schema.fields or {}) do if IsSetting(field) then available=true;break end end
            end
            if available then
                context.addons[provider.id]=Profiles.Create({provider},{id=provider.id,store=options.store,scoped=true,onApplied=options.onApplied})
                table.insert(context.addonOrder,provider.id)
            end
        end
    end
    return context
end
