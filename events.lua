local mq = require('mq')
local base64 = require('base64')
local base_dir = mq.luaDir .. '/lem'

local events = {
    types = {text='events',cond='conditions'}
}

local settings
function events.setSettings(s)
    settings = s
end

function events.read_event_file(file)
    local f,e = io.open(file, 'r')
    if not f then return error(e) end
    local contents = f:read('*a')
    io.close(f)
    return contents
end

function events.write_event_file(file, contents)
    local f,e = io.open(file, 'w')
    if not f then return error(e) end
    f:write(contents)
    io.close(f)
end

function events.delete_event_file(filename)
    local command = ('del %s'):format(filename):gsub('/', '\\')
    local pipe = io.popen(command)
    if pipe then pipe:close() end
end

events.filename = function(event_name, event_type)
    return ('%s/%s/%s.lua'):format(base_dir, event_type, event_name)
end

events.packagename = function(event_name, event_type)
    return event_type..'.'..event_name
end

events.unload_package = function(event_name, event_type)
    package.loaded[events.packagename(event_name, event_type)] = nil
end

events.changed = function(original_event, new_event)
    if original_event.code ~= new_event.code then
        return true
    end
    if original_event.pattern and original_event.pattern ~= new_event.pattern then
        return true
    end
    if original_event.command and original_event.command ~= new_event.command then
        return true
    end
    if original_event.category ~= new_event.category then
        return true
    end
    if (original_event.load and not new_event.load) or (new_event.load and not original_event.load) then
        return true
    end
    if original_event.load and new_event.load then
        if original_event.load.zone ~= new_event.load.zone then
            return true
        end
        if original_event.load.class ~= new_event.load.class then
            return true
        end
        if original_event.load.characters ~= new_event.load.characters then
            return true
        end
    end
    return false
end

events.should_load = function(event, event_type, char_settings)
    -- per character enabled flag currently in use instead of dynamic load options
    if char_settings[event_type][event.name] then return true else return false end
    local load = event.load
    if load then
        if load.always then return true end
        local classmatch = load.class and load.class ~= ''
        local namematch = load.characters and load.characters ~= ''
        local zonematch = load.zone and load.zone ~= ''
        local nonempty = classmatch or namematch or zonematch
        if nonempty then
            if classmatch and not load.class:lower():find(mq.TLO.Me.Class.ShortName():lower()) then return false end
            if namematch and not load.characters:lower():find(mq.TLO.Me.CleanName():lower()) then return false end
            if zonematch and not load.zone:lower():find(mq.TLO.Zone.ShortName():lower()) then return false end
        else
            return false
        end
    end
    return true
end

events.initialize = function(event)
    local success, result = true, nil
    if event.func.onload then
        success, result = pcall(event.func.onload)
        if not success then
            event.failed = true
            event.func = nil
            print('Event onload failed: \ay'..event.name..'\ax')
            print('\t\ar'..result..'\ax')
        end
    end
    return success
end

events.reload = function(event, event_type)
    events.unload(event, event_type)
    events.load(event, event_type)
end

local function logMessage(message)
    if settings.settings.broadcast == 'None' then
        print(message)
    elseif settings.settings.broadcast == 'DanNet' then
        mq.cmdf('/dgt all ' .. message)
    elseif settings.settings.broadcast == 'EQBC' then
        mq.cmdf('/bc ' .. message)
    end
end

events.load = function(event, event_type)
    local success, result = pcall(require, events.packagename(event.name, event_type))
    if not success then
        event.failed = true
        logMessage(string.format('Event registration failed: \ay%s\ax', event.name))
        printf('\ar%s\ax', result)
        result = nil
        events.unload_package(event.name, event_type)
        --mq.cmdf('/lua run lem/%s/%s', subfolder, event.name)
    else
        event.func = result
        if type(event.func) == 'function' then
            local tmpfunc = event.func
            event.func = {eventfunc=tmpfunc}
        end
        if type(event.func) ~= 'table' then
            result = nil
            event.failed = true
            logMessage(string.format('Event registration failed: \ay%s\ax, event functions not correctly defined.', event.name))
            events.unload_package(event.name, event_type)
            return
        end
        success = events.initialize(event)
        if success then
            logMessage(string.format('Registering event: \ay%s\ax', event.name))
            if event_type == events.types.text then
                mq.unevent(event.name)
                mq.delay(1)
                mq.event(event.name, event.pattern, event.func.eventfunc)
            end
            event.loaded = true
        else
            events.unload_package(event.name, event_type)
        end
    end
end

events.unload = function(event, event_type)
    logMessage(string.format('Deregistering event: \ay%s\ax', event.name))
    if event_type == events.types.text then mq.unevent(event.name) end
    events.unload_package(event.name, event_type)
    event.loaded = false
    event.func = nil
    event.failed = nil
end

events.evaluate_condition = function(event)
    local success, result = pcall(event.func.condfunc)
    if success and result then
        success, result = pcall(event.func.actionfunc)
        if not success then
            logMessage(string.format('Failed to invoke action for event: \ax\ay%s\ax', event.name))
            print('\t\ar'..result..'\ax')
        end
    elseif not success then
        logMessage(string.format('Failed to invoke condition for event: \ax\ay%s\ax', event.name))
        print('\t\ar'..result..'\ax')
    end
end

events.manage = function(event_list, event_type, char_settings)
    for _, event in pairs(event_list) do
        local load_event = events.should_load(event, event_type, char_settings)
        if not event.loaded and not event.failed and load_event then
            events.load(event, event_type)
        elseif event.loaded and not load_event then
            events.unload(event, event_type)
        end
        if event_type == events.types.cond and event.loaded then
            events.evaluate_condition(event)
        end
    end
end

events.draw = function(event_list)
    for _, event in pairs(event_list) do
        if event.loaded and event.func.draw then
            event.func.draw()
        end
    end
end

local function serialize_table(val, name, skipnewlines, depth)
    skipnewlines = skipnewlines or false
    depth = depth or 0

    local tmp = string.rep(" ", depth)

    if name then
        if type(name) ~= 'number' then
            tmp = tmp .. '["' .. name .. '"] = '
        else
            tmp = tmp .. '[' .. name .. '] = '
        end
    end

    if type(val) == "table" then
        tmp = tmp .. "{" .. (not skipnewlines and "\n" or "")

        for k, v in pairs(val) do
            tmp =  tmp .. serialize_table(v, k, skipnewlines, depth + 1) .. "," .. (not skipnewlines and "\n" or "")
        end

        tmp = tmp .. string.rep(" ", depth) .. "}"
    elseif type(val) == "number" then
        tmp = tmp .. tostring(val)
    elseif type(val) == "string" then
        tmp = tmp .. string.format("%q", val)
    elseif type(val) == "boolean" then
        tmp = tmp .. (val and "true" or "false")
    else
        tmp = tmp .. "\"[inserializeable datatype:" .. type(val) .. "]\""
    end

    return tmp
end

events.export = function(event, event_type)
    local code = events.read_event_file(events.filename(event.name, event_type))
    local exported_event = {
        name = event.name,
        pattern = event.pattern,
        singlecommand = event.singlecommand,
        command = event.command,
        category = event.category,
        code = base64.enc(code),
        type = event_type,
        load = event.load,
    }
    if exported_event.load then
        exported_event.load.characters = nil
    end
    return base64.enc('return '..serialize_table(exported_event))
end

events.import = function(import_string, categories)
    if not import_string or import_string == '' then return end
    local decoded = base64.dec(import_string)
    if not decoded or decoded == '' then return end
    local ok, imported_event = pcall(loadstring(decoded))
    if not ok or not type(imported_event) == 'table' then
        print('\arERROR: Failed to import event\ax')
        return
    end
    local temp_code = base64.dec(imported_event.code)
    if not temp_code or temp_code == '' then return end
    imported_event.code = temp_code
    if imported_event.category and imported_event.category ~= '' then
        local category_found = false
        for _,category in ipairs(categories) do
            if category.name == imported_event.category then
                category_found = true
                break
            end
            for _,subcategory in ipairs(category.children) do
                if subcategory.name == imported_event.category then
                    category_found = true
                end
            end
        end
        if not category_found then imported_event.category = '' end
    end
    if imported_event.load then
        imported_event.load.characters = ''
    end
    return imported_event
end

return events