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
local function AppearanceRecord(name,profile)
    return type(name)=="string" and string.sub(name,1,12)=="@appearance:"
        or type(profile)=="table" and (profile.version==3 or profile.scope=="appearance")
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
        if AppearanceRecord(name,profiles[name]) then return false,"Appearance presets use their own editor." end
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
        local names={};for name,profile in pairs(Root().settingsProfiles) do if type(name)=="string" and not AppearanceRecord(name,profile) then table.insert(names,name) end end
        table.sort(names);return names
    end
    function context.Exists(name)
        name=Name(name);local profile=Root().settingsProfiles[name or ""]
        return not AppearanceRecord(name,profile) and profile~=nil
    end
    function context.CanAdd(name)
        name=Name(name);if not name then return false,"Enter a profile name (1-64 characters)." end
        if AppearanceRecord(name,Root().settingsProfiles[name]) then return false,"Appearance presets use their own editor." end
        if context.Exists(name) then return false,"This profile already exists." end
        return true
    end
    function context.GetCurrent()
        local root=Root()
        local name=root.currentSettingsProfiles[context.id] or context.id=="suite" and root.currentSettingsProfile
        if name then
            if AppearanceRecord(name,root.settingsProfiles[name]) then error("Appearance presets cannot be current general profiles.") end
            return name
        end
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
        if AppearanceRecord(name,profile) then return false,"Appearance presets use their own editor." end
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
        if AppearanceRecord(name,profiles[name or ""]) then return false,"Appearance presets use their own editor." end
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
        if AppearanceRecord(name,profile) then return nil,"Appearance presets use their own editor." end
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

-- A visual preset is one appearance owner's declared values. It never goes
-- through ordinary settings Load, aggregate providers or a durable field setter.
function Profiles.CreateAppearance(options)
    if type(options)~="table" or type(options.id)~="string" or options.id==""
        or string.find(options.id,"[^%w_%.%-]") or type(options.getProvider)~="function" then
        error("Expected an appearance target and its provider getter.")
    end
    local id=options.id
    local prefix,index="@appearance:"..id..":","appearance:"..id
    local context,busy={id=id},false
    local deleteGuards=setmetatable({}, {__mode="k"})
    local function Message(value) return type(value)=="table" and tostring(value.message or value.code) or tostring(value) end
    local function Root()
        local root=options.store
        if root==nil then root=BootyLibDB end
        if type(root)~="table" then error("Shared appearance preset data is not ready.") end
        if root.settingsProfiles~=nil and type(root.settingsProfiles)~="table" then error("Invalid saved profile collection; preserve it before repair.") end
        if root.currentSettingsProfiles~=nil and type(root.currentSettingsProfiles)~="table" then error("Invalid saved profile selection; preserve it before repair.") end
        return root,root.settingsProfiles,root.currentSettingsProfiles
    end
    local function CheckedName(value)
        local name=Name(value)
        if not name then error("Enter a preset name (1-64 characters).") end
        return name
    end
    local function Record(profiles,name,required)
        local record=profiles and profiles[prefix..name]
        if record==nil then if required then error("Appearance preset not found.") end;return nil end
        if type(record)~="table" or record.version~=3 or record.scope~="appearance" or record.target~=id
            or record.name~=name or type(record.values)~="table" then error("Invalid appearance preset; preserve it before repair.") end
        for key in pairs(record) do
            if key~="version" and key~="scope" and key~="target" and key~="name" and key~="values" then error("Unsupported appearance preset field.") end
        end
        return record
    end
    local function Current(profiles,currents)
        local name=currents and currents[index]
        if name==nil then return nil end
        if type(name)~="string" or name~=CheckedName(name) then error("Invalid saved appearance preset selection.") end
        Record(profiles,name,true)
        return name
    end
    local function OwnerCall(owner,method,first)
        if type(owner[method])~="function" then return false,"Update the appearance owner to use presets." end
        local ok,result,detail=pcall(owner[method],first)
        if not ok then return false,Message(result) end
        if result~=true then return false,Message(detail or "The appearance owner declined this operation.") end
        return true,detail
    end
    local function Owner()
        local owner=options.getProvider(id)
        if type(owner)~="table" or owner.id~=id or owner.apiVersion~=1 then error("The appearance owner is unavailable or incompatible.") end
        return owner
    end
    local function Finite(value) return type(value)=="number" and value==value and value-value==0 end
    local function Model(owner)
        local ok,data=OwnerCall(owner,"ReadAppearance",id)
        if not ok then error(data) end
        if type(data)~="table" or data.available~=true then error(Message(type(data)=="table" and data.reason or "Appearance is unavailable.")) end
        local fields=data.fields
        if id=="booty.shared.appearance" then fields={{key="skin",type="choice",choices=data.choices}} end
        if type(fields)~="table" or table.getn(fields)==0 then error("The appearance owner has no explicit field schema.") end
        local schema={}
        for _,field in ipairs(fields) do
            if type(field)~="table" or type(field.key)~="string" or field.key=="" or schema[field.key] then error("Invalid appearance field schema.") end
            local entry={type=field.type,min=field.min,max=field.max,step=field.step}
            if field.type=="slider" then
                if not Finite(entry.min) or not Finite(entry.max) or entry.min>entry.max
                    or entry.step~=nil and (not Finite(entry.step) or entry.step<=0) then error("Invalid appearance slider schema.") end
            elseif field.type=="choice" then
                if type(field.choices)~="table" or table.getn(field.choices)==0 then error("Invalid appearance choices.") end
                entry.choices={}
                for _,choice in ipairs(field.choices) do
                    local value=type(choice)=="table" and choice.value
                    if type(value)~="string" and type(value)~="boolean" and not Finite(value) or entry.choices[value] then error("Invalid appearance choice.") end
                    entry.choices[value]=true
                end
            elseif field.type~="checkbox" and field.type~="color" then error("Unsupported appearance field type.") end
            schema[field.key]=entry
        end
        return schema,data
    end
    local function Validate(values,schema)
        if type(values)~="table" then error("Invalid appearance preset values.") end
        for key in pairs(values) do if not schema[key] then error("Unknown appearance field: "..tostring(key)) end end
        local detached={}
        for key,field in pairs(schema) do
            local value,valid=values[key],false
            if field.type=="color" then
                valid=type(value)=="table"
                if valid then
                    for part in pairs(value) do if part~=1 and part~=2 and part~=3 then valid=false end end
                    for part=1,3 do if not Finite(value[part]) or value[part]<0 or value[part]>1 then valid=false end end
                end
            elseif field.type=="checkbox" then valid=type(value)=="boolean"
            elseif field.type=="choice" then valid=value~=nil and field.choices[value]==true
            else
                valid=Finite(value) and value>=field.min and value<=field.max
                if valid and field.step then
                    local steps=(value-field.min)/field.step
                    valid=math.abs(steps-math.floor(steps+0.5))<0.000001
                end
            end
            if not valid then error("Invalid appearance field: "..key) end
            detached[key]=Copy(value)
        end
        return detached
    end
    local function ReadModel(owner)
        local schema,data=Model(owner)
        Validate(data.defaults,schema)
        return schema,Validate(data.values,schema)
    end
    local function Capture()
        local owner=Owner()
        local begun,token=OwnerCall(owner,"BeginAppearancePreview",id)
        if not begun then error(token) end
        if token==nil then error("The appearance owner returned no capture token.") end
        local read,schema,values=pcall(ReadModel,owner)
        local cancelled,restored=OwnerCall(owner,"CancelAppearance",token)
        if not read then error(Message(schema)..(not cancelled and ("; capture cleanup: "..Message(restored)) or "")) end
        if not cancelled then error("Appearance capture could not finish: "..Message(restored)) end
        if not Equal(values,Validate(restored,schema)) then error("Appearance changed during preset capture.") end
        return schema,values
    end
    local function Run(callback,mutation)
        if mutation and busy then return false,"An appearance preset operation is already in progress." end
        if mutation then busy=true end
        local ok,result,detail,guard=pcall(callback)
        if mutation then busy=false end
        if not ok then return false,Message(result) end
        return result,detail,guard
    end
    local function Snapshot(root,profiles,currents,name)
        Current(profiles,currents)
        local old=profiles and profiles[prefix..name]
        return {root=root,profiles=profiles,currents=currents,key=prefix..name,old=old,oldCopy=Copy(old),current=currents and currents[index]}
    end
    local function Commit(snapshot,record,writeRecord,selected,writeSelection)
        local profiles,currents=snapshot.profiles,snapshot.currents
        local createdProfiles,createdCurrents,recordAttempt,selectionAttempt
        local expected=Copy(record)
        local function Check(currentRecord,currentSelection,recordReference)
            local root,collection,selection=Root()
            if root~=snapshot.root or collection~=profiles or selection~=currents
                or (collection and collection[snapshot.key])~=recordReference or not Equal(collection and collection[snapshot.key],currentRecord)
                or (selection and selection[index])~=currentSelection then error("Appearance presets changed during this operation.") end
        end
        local ok,failure=pcall(function()
            Check(snapshot.oldCopy,snapshot.current,snapshot.old)
            if writeRecord and not profiles then
                createdProfiles={};profiles=createdProfiles;snapshot.root.settingsProfiles=profiles
                Check(snapshot.oldCopy,snapshot.current,snapshot.old)
            end
            if writeSelection and not currents then
                createdCurrents={};currents=createdCurrents;snapshot.root.currentSettingsProfiles=currents
                Check(snapshot.oldCopy,snapshot.current,snapshot.old)
            end
            if writeRecord then recordAttempt=true;profiles[snapshot.key]=record;Check(expected,snapshot.current,record) end
            if writeSelection then selectionAttempt=true;currents[index]=selected end
            local finalRecord,finalSelection,finalReference=snapshot.oldCopy,snapshot.current,snapshot.old
            if writeRecord then finalRecord=expected;finalReference=record end
            if writeSelection then finalSelection=selected end
            Check(finalRecord,finalSelection,finalReference)
        end)
        if ok then return true end
        local rollback={}
        local function Restore(callback)
            local restored,message=pcall(callback)
            if not restored then table.insert(rollback,Message(message)) end
        end
        local root=options.store;if root==nil then root=BootyLibDB end
        if root~=snapshot.root then table.insert(rollback,"A later shared profile store was preserved.")
        else
            if recordAttempt then Restore(function()
                if root.settingsProfiles~=profiles then error("A later profile collection was preserved.") end
                if profiles[snapshot.key]==record and Equal(profiles[snapshot.key],expected) then profiles[snapshot.key]=snapshot.old
                elseif profiles[snapshot.key]~=snapshot.old or not Equal(profiles[snapshot.key],snapshot.oldCopy) then error("A later appearance preset was preserved.") end
            end) end
            if selectionAttempt then Restore(function()
                if root.currentSettingsProfiles~=currents then error("A later selection collection was preserved.") end
                if currents[index]==selected then currents[index]=snapshot.current
                elseif currents[index]~=snapshot.current then error("A later preset selection was preserved.") end
            end) end
            if createdCurrents and root.currentSettingsProfiles==createdCurrents and next(createdCurrents)==nil then Restore(function() root.currentSettingsProfiles=snapshot.currents end) end
            if createdProfiles and root.settingsProfiles==createdProfiles and next(createdProfiles)==nil then Restore(function() root.settingsProfiles=snapshot.profiles end) end
        end
        return false,Message(failure)..(table.getn(rollback)>0 and ("; rollback: "..table.concat(rollback,"; ")) or "")
    end
    local function Save(name,add)
        return Run(function()
            name=CheckedName(name)
            local root,profiles,currents=Root()
            local old=Record(profiles,name,not add)
            if add and old then return false,"This appearance preset already exists. Use Save to update it." end
            local snapshot=Snapshot(root,profiles,currents,name)
            local schema,values=Capture()
            if old then Validate(old.values,schema) end
            local record={version=3,scope="appearance",target=id,name=name,values=values}
            local ok,failure=Commit(snapshot,record,true,name,add)
            if not ok then return ok,failure end
            return true,"Saved appearance preset: "..name
        end,true)
    end
    function context.List()
        return Run(function()
            local _,profiles=Root();local names={}
            for key in pairs(profiles or {}) do
                if type(key)=="string" and string.sub(key,1,string.len(prefix))==prefix then
                    local name=string.sub(key,string.len(prefix)+1)
                    if name~=CheckedName(name) then error("Invalid appearance preset name.") end
                    Record(profiles,name,true);table.insert(names,name)
                end
            end
            table.sort(names);return names
        end)
    end
    function context.Exists(name)
        return Run(function() name=CheckedName(name);local _,profiles=Root();return Record(profiles,name,false)~=nil end)
    end
    function context.CanAdd(name)
        return Run(function()
            name=CheckedName(name);local _,profiles=Root()
            if Record(profiles,name,false) then return false,"This appearance preset already exists." end
            return true
        end)
    end
    function context.GetCurrent() return Run(function() local _,profiles,currents=Root();return Current(profiles,currents) end) end
    function context.GetValues(name)
        return Run(function()
            name=CheckedName(name);local root,profiles=Root();local record=Record(profiles,name,true)
            local snapshot=Copy(record)
            local schema=ReadModel(Owner())
            local values=Validate(record.values,schema)
            local current,collection=Root()
            if current~=root or collection~=profiles or collection[prefix..name]~=record or not Equal(record,snapshot) then
                error("Appearance preset changed during its read.")
            end
            local guard={}
            deleteGuards[guard]={root=root,profiles=profiles,record=record,snapshot=snapshot,name=name}
            return true,values,guard
        end)
    end
    function context.Add(name) return Save(name,true) end
    function context.Save(name) return Save(name,false) end
    function context.Select(name)
        return Run(function()
            name=CheckedName(name);local root,profiles,currents=Root();local record=Record(profiles,name,true)
            local snapshot=Snapshot(root,profiles,currents,name)
            local schema=ReadModel(Owner());Validate(record.values,schema)
            local ok,failure=Commit(snapshot,nil,false,name,true)
            if not ok then return ok,failure end
            return true,"Selected appearance preset: "..name
        end,true)
    end
    function context.Delete(name,guard)
        return Run(function()
            name=CheckedName(name);local root,profiles,currents=Root();local record=Record(profiles,name,true)
            if guard~=nil then
                local expected=deleteGuards[guard]
                deleteGuards[guard]=nil
                if not expected or expected.name~=name or expected.root~=root or expected.profiles~=profiles
                    or expected.record~=record or not Equal(expected.snapshot,record) then
                    return false,"Appearance preset changed after the delete confirmation was opened."
                end
            end
            local snapshot=Snapshot(root,profiles,currents,name)
            local ok,failure=Commit(snapshot,nil,true,nil,snapshot.current==name)
            if not ok then return ok,failure end
            return true,"Deleted appearance preset: "..name
        end,true)
    end
    return context
end
