--[[
lua event manager -- aquietone
]]
local mq = require 'mq'
require 'ImGui'
local persistence = require('lem.persistence')
local version = '0.4.1'

-- application state
local state = {
    terminate = false,
    ui = {
        main = {
            title = ('Lua Event Manager (v%s)###lem'):format(version),
            open_ui = true,
            draw_ui = true,
            menu_idx = 0,
            event_idx = nil,
            category_idx = 0,
            menu_width = 120,
            filter = '',
        },
        editor = {
            open_ui = false,
            draw_ui = false,
            action = nil,
            event_idx = nil,
            event_type = nil,
            template = '',
        },
    },
    inputs = {
        import = '',
        add_event = {name='', category='', enabled=false, pattern='', code=''},
        add_category = {name=''},
    },
}

local table_flags = bit32.bor(ImGuiTableFlags.Hideable, ImGuiTableFlags.RowBg, ImGuiTableFlags.ScrollY, ImGuiTableFlags.BordersOuter)
local actions = {add=1,edit=2,view=3,add_category=4}
local event_types = {text='events',cond='conditions'}
local base_dir = mq.luaDir .. '/lem'
local menu_default_width = 120

local templates = {'event_runout', 'react_bane'}
local text_code_template = "local mq = require('mq')\n\
local function event_handler()\n    \nend\n\
return event_handler"

local condition_code_template = "local mq = require('mq')\n\
local function condition()\n    \nend\n\
local function action()\n    \nend\n\
return {condfunc=condition, actionfunc=action}"

local settings, text_events, condition_events, categories, char_settings, filtered_events

-- character table string
local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

-- encoding
local function enc(data)
    return ((data:gsub('.', function(x) 
        local r,b='',x:byte()
        for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
        return r;
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c=0
        for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return b:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data%3+1])
end

-- decoding
local function dec(data)
    data = string.gsub(data, '[^'..b..'=]', '')
    return (data:gsub('.', function(x)
        if (x == '=') then return '' end
        local r,f='',(b:find(x)-1)
        for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
        return r;
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if (#x ~= 8) then return '' end
        local c=0
        for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
        return string.char(c)
    end))
end

local function save_settings()
    persistence.store(('%s/settings.lua'):format(base_dir), settings)
end

local function save_character_settings()
    persistence.store(('%s/characters/%s.lua'):format(base_dir, mq.TLO.Me.CleanName():lower()), char_settings)
end

local function init_settings()
    local ok, module = pcall(require, 'lem.settings')
    if not ok then
        settings = {
            text_events = {},
            condition_events = {},
            categories = {},
            settings = {
                frequency = 250,
            },
        }
        save_settings()
    else
        settings = module
    end
    text_events = settings.text_events or {}
    condition_events = settings.condition_events or {}
    categories = settings.categories or {}
    if not settings.settings or not settings.settings.frequency then
        settings['settings'] = {frequency = 250}
    end
end

local function init_char_settings()
    local my_name = mq.TLO.Me.CleanName():lower()
    local ok, module = pcall(require, 'lem.characters.'..my_name)
    if not ok then
        char_settings = {events={}, conditions={}}
        save_character_settings()
    else
        char_settings = module
    end
end

local function file_exists(file)
    local f = io.open(file, "r")
    if f ~= nil then io.close(f) return true else return false end
end

local function read_file(file)
    local f,e = io.open(file, 'r')
    if not f then return error(e) end
    local contents = f:read('*a')
    io.close(f)
    return contents
end

local function write_file(file, contents)
    local f,e = io.open(file, 'w')
    if not f then return error(e) end
    f:write(contents)
    io.close(f)
end

local function delete_file(filename)
    local command = ('del %s'):format(filename):gsub('/', '\\')
    local pipe = io.popen(command)
    if pipe then pipe:close() end
end

local function template_filename(name)
    return ('%s/templates/%s.lua'):format(base_dir, name)
end

local function event_filename(event_type, event_name)
    return ('%s/%s/%s.lua'):format(base_dir, event_type, event_name)
end

local function event_packagename(event_type, event_name)
    return 'lem.'..event_type..'.'..event_name
end

local function unload_event_package(event_type, event_name)
    package.loaded[event_packagename(event_type, event_name)] = nil
end

local function reset_add_event_inputs(event_type)
    state.inputs.add_event = {name='', category='', enabled=false, pattern=''}
    if event_type == event_types.text then
        state.inputs.add_event.code = text_code_template
    elseif event_type == event_types.cond then
        state.inputs.add_event.code = condition_code_template
    end
end

local function set_add_event_inputs(event)
    state.inputs.add_event = {
        name=event.name,
        category=event.category,
        enabled=char_settings[state.ui.editor.event_type][event.name],
        pattern=event.pattern,
        code=event.code
    }
end

local function get_event_list(event_type)
    if event_type == event_types.text then
        return text_events
    else
        return condition_events
    end
end

--local event_ui_ids = {}

local function toggle_event(event, event_type)
    char_settings[event_type][event.name] = not char_settings[event_type][event.name]
    if not char_settings[event_type][event.name] then
--        if event.ui_id and event.ui_id ~= '' then
--            table.insert(event_ui_ids, event.ui_id)
--        end
        unload_event_package(event_type, event.name)
        event.loaded = false
        event.func = nil
        event.failed = nil
    end
    save_character_settings()
end

local function did_event_config_change(original_event, new_event)
    if original_event.code ~= new_event.code then
        return true
    end
    if original_event.pattern and original_event.pattern ~= new_event.pattern then
        return true
    end
    if original_event.category ~= new_event.category then
        return true
    end
    return false
end

local function save_event()
    local event_type = state.ui.editor.event_type
    local add_event = state.inputs.add_event
    if add_event.code:len() == 0 or add_event.name:len() == 0 then return end
    if event_type == event_types.text and add_event.pattern:len() == 0 then return end

    local events = get_event_list(event_type)
    local original_event = events[add_event.name]
    if original_event and not did_event_config_change(original_event, add_event) then
        -- code and pattern did not change
        if add_event.enabled ~= char_settings[event_type][add_event.name] then
            -- just enabling or disabling the event
            toggle_event(original_event, event_type)
        end
    else
        local new_event = {name=add_event.name,category=add_event.category}
        if event_type == event_types.text then
            new_event.pattern = add_event.pattern
        end
        if state.ui.editor.action == actions.edit then
            -- replacing event, disable then unload it first before it is saved
            char_settings[event_type][add_event.name] = nil
            if event_type == event_types.text then mq.unevent(add_event.name) end
            unload_event_package(event_type, add_event.name)
        end
        write_file(event_filename(event_type, add_event.name), add_event.code)
        events[add_event.name] = new_event
        save_settings()
        char_settings[event_type][add_event.name] = add_event.enabled
        save_character_settings()
    end
    state.ui.editor.open_ui = false
end

local function draw_event_editor()
    if not state.ui.editor.open_ui then return end
    local title = 'Event Editor###lemeditor'
    if state.ui.editor.action == actions.add then
        title = 'Add Event###lemeditor'
    end
    state.ui.editor.open_ui, state.ui.editor.draw_ui = ImGui.Begin(title, state.ui.editor.open_ui)
    if state.ui.editor.draw_ui then
        if ImGui.Button('Save') then
            save_event()
        end
        local add_event = state.inputs.add_event
        add_event.name,_ = ImGui.InputText('Event Name', add_event.name)
        if ImGui.BeginCombo('Category', add_event.category or '') then
            for _,j in pairs(categories) do
                if ImGui.Selectable(j, j == add_event.category) then
                    add_event.category = j
                end
            end
            ImGui.EndCombo()
        end
        --
        add_event.enabled,_ = ImGui.Checkbox('Event Enabled', add_event.enabled, add_event.enabled)
        if state.ui.editor.event_type == event_types.text then
            add_event.pattern,_ = ImGui.InputText('Event Pattern', add_event.pattern)
        end
        if ImGui.BeginCombo('Code Templates', state.ui.editor.template or '') then
            for _,template in ipairs(templates) do
                if ImGui.Selectable(template, state.ui.editor.template == template) then
                    state.ui.editor.template = template
                end
            end
            ImGui.EndCombo()
        end
        local buttons_active = true
        if state.ui.editor.template == '' then
            ImGui.PushStyleColor(ImGuiCol.Button, .3, 0, 0,1)
            ImGui.PushStyleColor(ImGuiCol.ButtonActive, .3, 0, 0,1)
            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, .3, 0, 0,1)
            buttons_active = false
        end
        if ImGui.Button('Load Template') and state.ui.editor.template ~= '' then
            add_event.code = read_file(template_filename(state.ui.editor.template))
        end
        if not buttons_active then
            ImGui.PopStyleColor(3)
        end
        ImGui.SameLine()
        ImGui.TextColored(1, 0, 0, 1, 'This will OVERWRITE the existing event code')
        ImGui.NewLine()
        ImGui.Text('Event Code')
        local x, y = ImGui.GetContentRegionAvail()
        add_event.code,_ = ImGui.InputTextMultiline('###EventCode', add_event.code, x-100, y-20)
    end
    ImGui.End()
end

local function serialize_table(val, name, skipnewlines, depth)
    skipnewlines = skipnewlines or false
    depth = depth or 0

    local tmp = string.rep(" ", depth)

    if name then tmp = tmp .. name .. " = " end

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

local function export_event(event, event_type)
    if not event.code then
        event.code = read_file(event_filename(event_type, event.name))
    end
    local exported_event = {
        name = event.name,
        pattern = event.pattern,
        category = event.category,
        code = enc(event.code),
        type = event_type,
    }
    ImGui.SetClipboardText(enc('return '..serialize_table(exported_event)))
end

local function draw_event_viewer()
    if not state.ui.editor.open_ui then return end
    state.ui.editor.open_ui, state.ui.editor.draw_ui = ImGui.Begin('Event Viewer###lemeditor', state.ui.editor.open_ui)
    local events = get_event_list(state.ui.editor.event_type)
    local event = events[state.ui.editor.event_idx]
    if state.ui.editor.draw_ui and event then
        local width = ImGui.GetContentRegionAvail()
        ImGui.PushTextWrapPos(width-15)
        if ImGui.Button('Edit Event') then
            state.ui.editor.action = actions.edit
            set_add_event_inputs(event)
        end
        ImGui.SameLine()
        if ImGui.Button('Export Event') then
            export_event(event, state.ui.editor.event_type)
        end
        if event.failed then
            ImGui.TextColored(1, 0, 0, 1, 'ERROR: Event failed to load!')
        end
        ImGui.TextColored(1, 1, 0, 1, 'Name: ')
        ImGui.SameLine()
        ImGui.SetCursorPosX(100)
        if char_settings[state.ui.editor.event_type][event.name] then
            ImGui.TextColored(0, 1, 0, 1, event.name)
        else
            ImGui.TextColored(1, 0, 0, 1, event.name .. ' (Disabled)')
        end
        ImGui.TextColored(1, 1, 0, 1, 'Category: ')
        ImGui.SameLine()
        ImGui.SetCursorPosX(100)
        ImGui.Text(event.category or '')
        if state.ui.editor.event_type == event_types.text then
            ImGui.TextColored(1, 1, 0, 1, 'Pattern: ')
            ImGui.SameLine()
            ImGui.SetCursorPosX(100)
            ImGui.TextColored(1, 0, 1, 1, event.pattern)
        end
        ImGui.TextColored(1, 1, 0, 1, 'Code:')
        ImGui.PushStyleColor(ImGuiCol.Text, 0, 1, 1, 1)
        ImGui.TextUnformatted(event.code)
        ImGui.PopStyleColor()
        ImGui.PopTextWrapPos()
    end
    ImGui.End()
end

local function set_editor_state(open, action, event_type, event_idx)
    state.ui.editor.open_ui = open
    state.ui.editor.action = action
    state.ui.editor.event_idx = event_idx
    state.ui.editor.event_type = event_type
end

local function draw_event_control_buttons(event_type)
    local events = get_event_list(event_type)
    if ImGui.Button('Add Event...') then
        set_editor_state(true, actions.add, event_type, nil)
        reset_add_event_inputs(event_type)
    end
    local buttons_active = true
    if not state.ui.main.event_idx then
        ImGui.PushStyleColor(ImGuiCol.Button, .3, 0, 0,1)
        ImGui.PushStyleColor(ImGuiCol.ButtonActive, .3, 0, 0,1)
        ImGui.PushStyleColor(ImGuiCol.ButtonHovered, .3, 0, 0,1)
        buttons_active = false
    end
    local event = events[state.ui.main.event_idx]
    ImGui.SameLine()
    if ImGui.Button('View Event') and state.ui.main.event_idx then
        set_editor_state(true, actions.view, event_type, state.ui.main.event_idx)
        if not event.code then
            event.code = read_file(event_filename(event_type, event.name))
        end
    end
    ImGui.SameLine()
    if ImGui.Button('Edit Event') and state.ui.main.event_idx then
        set_editor_state(true, actions.edit, event_type, state.ui.main.event_idx)
        if not event.code then
            event.code = read_file(event_filename(event_type, event.name))
        end
        set_add_event_inputs(event)
    end
    ImGui.SameLine()
    if ImGui.Button('Remove Event') and state.ui.main.event_idx then
        events[event.name] = nil
        if event_type == event_types.text and char_settings[event_type][event.name] then
            mq.unevent(event.name)
        end
        char_settings[event_type][event.name] = nil
        unload_event_package(event_type, event.name)
        state.ui.main.event_idx = nil
        delete_file(event_filename(event_type, event.name))
        save_settings()
        save_character_settings()
        set_editor_state(false, nil, nil, nil)
    end
    if not buttons_active then
        ImGui.PopStyleColor(3)
    end
end

local function draw_event_table_context_menu(event, event_type)
    if ImGui.BeginPopupContextItem() then
        if ImGui.MenuItem('Export') then
            export_event(event, event_type)
        end
        ImGui.EndPopup()
    end
end

local function draw_event_table_row(event, event_type)
    local enabled = ImGui.Checkbox('##'..event.name, char_settings[event_type][event.name])
    if enabled ~= char_settings[event_type][event.name] then
        toggle_event(event, event_type)
    end
    ImGui.TableNextColumn()
    local row_label = event.name
    if char_settings[event_type][event.name] and not event.failed then
        ImGui.PushStyleColor(ImGuiCol.Text, 0, 1, 0, 1)
    else
        ImGui.PushStyleColor(ImGuiCol.Text, 1, 0, 0, 1)
        if event.failed then
            row_label = row_label .. ' (Failed to load)'
        end
    end
    if ImGui.Selectable(row_label, state.ui.main.event_idx == event.name, ImGuiSelectableFlags.SpanAllColumns) then
        if state.ui.main.event_idx ~= event.name then
            state.ui.main.event_idx = event.name
        end
    end
    if ImGui.IsItemHovered() and ImGui.IsMouseDoubleClicked(0) then
        set_editor_state(true, actions.view, event_type, event.name)
        if not event.code then
            event.code = read_file(event_filename(event_type, event.name))
        end
    end
    ImGui.PopStyleColor()
    draw_event_table_context_menu(event, event_type)
end

local function draw_events_table(event_type)
    local events = get_event_list(event_type)
    local new_filter,_ = ImGui.InputTextWithHint('##tablefilter', 'Filter...', state.ui.main.filter, 0)
    if new_filter ~= state.ui.main.filter then
        state.ui.main.filter = new_filter
        filtered_events = {}
        for event_name,event in pairs(events) do
            if event_name:find(state.ui.main.filter) then
                filtered_events[event_name] = event
            end
        end
    end
    if ImGui.BeginTable('EventTable', 2, table_flags, 0, 0, 0.0) then
        local column_label = 'Event Name'
        ImGui.TableSetupColumn('On/Off', ImGuiTableColumnFlags.NoSort, 1, 0)
        ImGui.TableSetupColumn(column_label,     ImGuiTableColumnFlags.DefaultSort,   3, 1)
        ImGui.TableSetupScrollFreeze(0, 1) -- Make row always visible
        ImGui.TableHeadersRow()

        if state.ui.main.filter ~= '' then
            for _,event in pairs(filtered_events) do
                ImGui.TableNextRow()
                ImGui.TableNextColumn()
                draw_event_table_row(event, event_type)
            end
        else
            for _,category in ipairs(categories) do
                ImGui.TableNextRow()
                ImGui.TableNextColumn()
                local open = ImGui.TreeNodeEx(category, ImGuiTreeNodeFlags.SpanFullWidth)
                ImGui.TableNextColumn()
                if open then
                    for _,event in pairs(events) do
                        if event.category == category then
                            ImGui.TableNextRow()
                            ImGui.TableNextColumn()
                            draw_event_table_row(event, event_type)
                        end
                    end
                    ImGui.TreePop()
                end
            end
            for _,event in pairs(events) do
                if not event.category or event.category == '' then
                    ImGui.TableNextRow()
                    ImGui.TableNextColumn()
                    draw_event_table_row(event, event_type)
                end
            end
        end
        ImGui.EndTable()
    end
end

local function draw_events_section(event_type)
    draw_event_control_buttons(event_type)
    draw_events_table(event_type)
end

local function draw_characters_section()

end

local function draw_settings_section()
    ImGui.PushStyleColor(ImGuiCol.Text, 1, 1, 0, 1)
    settings.settings.frequency = ImGui.InputInt('Frequency', settings.settings.frequency)
    ImGui.PopStyleColor()
    if ImGui.Button('Save') then
        save_settings()
    end
end

local function draw_reload_section()
    if ImGui.Button('Reload Settings') then
        mq.cmd('/timed 10 /lua run lem')
        state.terminate = true
    end
    ImGui.Text('Reload currently just restarts the script.')
end

local function save_category()
    if state.inputs.add_category.name:len() > 0 then
        table.insert(settings.categories, state.inputs.add_category.name)
        save_settings()
        state.ui.editor.open_ui = false
    end
end

local function draw_category_editor()
    state.ui.editor.open_ui, state.ui.editor.draw_ui = ImGui.Begin('Add Category###lemeditor', state.ui.editor.open_ui)
    if state.ui.editor.draw_ui then
        if ImGui.Button('Save') then
            save_category()
        end
        state.inputs.add_category.name,_ = ImGui.InputText('Category Name', state.inputs.add_category.name)
    end
    ImGui.End()
end

local function draw_categories_control_buttons()
    if ImGui.Button('Add Category...') then
        state.ui.editor.open_ui = true
        state.ui.editor.action = actions.add_catogory
    end
    if state.ui.main.category_idx then
        ImGui.SameLine()
        if ImGui.Button('Remove Category') then
            for _,event in pairs(text_events) do
                if event.category == categories[state.ui.main.category_idx] then
                    event.category = nil
                end
            end
            for _,event in pairs(condition_events) do
                if event.category == categories[state.ui.main.category_idx] then
                    event.category = nil
                end
            end
            table.remove(categories, state.ui.main.category_idx)
            state.ui.main.category_idx = 0
            save_settings()
        end
    end
end

local function draw_categories_table_row(idx, category)
    if ImGui.Selectable(category, state.ui.main.category_idx == idx, ImGuiSelectableFlags.SpanAllColumns) then
        if state.ui.main.category_idx ~= idx then
            state.ui.main.category_idx = idx
        end
    end
end

local function draw_categories_table()
    if ImGui.BeginTable('CategoryTable', 1, table_flags, 0, 0, 0.0) then
        ImGui.TableSetupColumn('Category',     ImGuiTableColumnFlags.NoSort,   -1, 1)
        ImGui.TableSetupScrollFreeze(0, 1) -- Make row always visible
        ImGui.TableHeadersRow()

        local clipper = ImGuiListClipper.new()
        clipper:Begin(#categories)
        while clipper:Step() do
            for row_n = clipper.DisplayStart, clipper.DisplayEnd - 1, 1 do
                local category = categories[row_n + 1]
                ImGui.TableNextRow()
                ImGui.TableNextColumn()
                draw_categories_table_row(row_n + 1, category)
            end
        end
        ImGui.EndTable()
    end
end

local function draw_categories_section()
    draw_categories_control_buttons()
    draw_categories_table()
end

local function import_event()
    if not state.inputs.import or state.inputs.import == '' then return end
    local decoded = dec(state.inputs.import)
    if not decoded or decoded == '' then return end
    local ok, imported_event = pcall(loadstring(decoded))
    if not ok then
        print('\arERROR: Failed to import event\ax')
        return
    end
    local temp_code = dec(imported_event.code)
    if not temp_code or temp_code == '' then return end
    imported_event.code = temp_code
    if imported_event.category and imported_event.category ~= '' then
        local category_found = false
        for _,category in ipairs(categories) do
            if category == imported_event.category then
                category_found = true
                break
            end
        end
        if not category_found then event.category = '' end
    end
    set_editor_state(true, actions.add, imported_event.type, nil)
    set_add_event_inputs(imported_event)
end

local function draw_import_window()
    if ImGui.Button('Import Event') then
        import_event()
        state.inputs.import = ''
    end
    ImGui.SameLine()
    if ImGui.Button('Paste from clipboard') then
        state.inputs.import = ImGui.GetClipboardText()
    end
    state.inputs.import = ImGui.InputTextMultiline('##importeventtext', state.inputs.import)
end

local sections = {
    {
        name='Text Events', 
        handler=draw_events_section,
        arg=event_types.text,
    },
    {
        name='Condition Events',
        handler=draw_events_section,
        arg=event_types.cond,
    },
    {
        name='Categories',
        handler=draw_categories_section,
    },
    --{
    --    name='Characters',
    --    handler=draw_characters_section,
    --},
    {
        name='Settings',
        handler=draw_settings_section,
    },
    {
        name='Reload',
        handler=draw_reload_section,
    },
    {
        name='Import',
        handler=draw_import_window,
    }
}

local function draw_selected_section()
    local x,y = ImGui.GetContentRegionAvail()
    if ImGui.BeginChild("right", x, y-1, true) then
        if state.ui.main.menu_idx > 0 then
            sections[state.ui.main.menu_idx].handler(sections[state.ui.main.menu_idx].arg)
        end
    end
    ImGui.EndChild()
end

local function draw_menu()
    local _,y = ImGui.GetContentRegionAvail()
    if ImGui.BeginChild("left", state.ui.main.menu_width, y-1, true) then
        if ImGui.BeginTable('MenuTable', 1, table_flags, 0, 0, 0.0) then
            for idx,section in ipairs(sections) do
                ImGui.TableNextRow()
                ImGui.TableNextColumn()
                if ImGui.Selectable(section.name, state.ui.main.menu_idx == idx) then
                    if state.ui.main.menu_idx ~= idx then
                        sorted_items = {}
                        state.ui.main.menu_idx = idx
                        state.ui.main.event_idx = nil
                    end
                end
            end
            ImGui.EndTable()
        end
    end
    ImGui.EndChild()
end

local function draw_splitter(thickness, size0, min_size0)
    local x,y = ImGui.GetCursorPos()
    local delta = 0
    ImGui.SetCursorPosX(x + size0)

    ImGui.PushStyleColor(ImGuiCol.Button, 0, 0, 0, 0)
    ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0, 0, 0, 0)
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.6, 0.6, 0.6, 0.1)
    ImGui.Button('##splitter', thickness, -1)
    ImGui.PopStyleColor(3)

    ImGui.SetItemAllowOverlap()

    if ImGui.IsItemActive() then
        delta,_ = ImGui.GetMouseDragDelta()

        if delta < min_size0 - size0 then
            delta = min_size0 - size0
        end
        if delta > 200 - size0 then
            delta = 200 - size0
        end

        size0 = size0 + delta
        state.ui.main.menu_width = size0
    else
        menu_default_width = state.ui.main.menu_width
    end
    ImGui.SetCursorPosX(x)
    ImGui.SetCursorPosY(y)
end

local function push_style()
    ImGui.PushStyleColor(ImGuiCol.WindowBg, 0, 0, 0, .9)
    ImGui.PushStyleColor(ImGuiCol.TitleBg, .3, 0, 0, 1)
    ImGui.PushStyleColor(ImGuiCol.TitleBgActive, .5, 0, 0, 1)
    ImGui.PushStyleColor(ImGuiCol.FrameBg, .2, .2, .2, 1)
    ImGui.PushStyleColor(ImGuiCol.FrameBgHovered, .3, 0, 0, 1)
    ImGui.PushStyleColor(ImGuiCol.FrameBgActive, .3, 0, 0, 1)
    ImGui.PushStyleColor(ImGuiCol.Button, .5, 0, 0,1)
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, .6, 0, 0,1)
    ImGui.PushStyleColor(ImGuiCol.ButtonActive, .5, 0, 0,1)
    ImGui.PushStyleColor(ImGuiCol.PopupBg, .1,.1,.1,1)
    ImGui.PushStyleColor(ImGuiCol.TextDisabled, 1, 1, 1, 1)
    ImGui.PushStyleColor(ImGuiCol.CheckMark, .5, 0, 0, 1)
    ImGui.PushStyleColor(ImGuiCol.Separator, .4, 0, 0, 1)
end

local function pop_style()
    ImGui.PopStyleColor(13)
end

-- ImGui main function for rendering the UI window
local lem_ui = function()
    if not state.ui.main.open_ui then return end
    push_style()
    state.ui.main.open_ui, state.ui.main.draw_ui = ImGui.Begin(state.ui.main.title, state.ui.main.open_ui)
    if state.ui.main.draw_ui then
        local x, y = ImGui.GetWindowSize() -- 148 42
        if x == 148 and y == 42 then
            ImGui.SetWindowSize(510, 200)
        end
        draw_splitter(8, menu_default_width, 75)
        ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 2, 2)
        draw_menu()
        ImGui.SameLine()
        draw_selected_section()
        ImGui.PopStyleVar()
    end
    ImGui.End()

    if state.ui.editor.open_ui then
        if state.ui.editor.action == actions.add or state.ui.editor.action == actions.edit then
            draw_event_editor()
        elseif state.ui.editor.action == actions.view then
            draw_event_viewer()
        elseif state.ui.editor.action == actions.add_catogory then
            draw_category_editor()
        end
    end

    pop_style()
end

local function load_event(event)
    local success, result = pcall(require, 'lem.events.'..event.name)
    if not success then
        result = nil
        event.failed = true
        print('Event registration failed: \ay'..event.name..'\ax')
    else
        print('Registering event: \ay'..event.name..'\ax')
        event.func = result
        mq.event(event.name, event.pattern, event.func)
        event.registered = true
    end
end

local function unload_event(event)
    print('Deregistering event: \ay'..event.name..'\ax')
    mq.unevent(event.name)
    event.registered = false
    event.func = nil
end

local function manage_events()
    for event_name, enabled in pairs(char_settings[event_types.text]) do
        local event = text_events[event_name]
        if event then
            if enabled and not event.registered and not event.failed then
                load_event(event)
            elseif not enabled and event.registered then
                unload_event(event)
            end
        end
    end
end

local function load_condition(event)
    local success, result = pcall(require, 'lem.conditions.'..event.name)
    if not success then
        result = nil
        event.failed = true
        print('Event registration failed: \ay'..event.name..'\ax')
    else
        event.func = result
--      event.ui_id = result.ui_id
        event.loaded = true
    end
end

local function evaluate_condition(event)
    local success, result = pcall(event.func.condfunc)
    if success and result then
        success, result = pcall(event.func.actionfunc)
        if not success then
            print('\arERROR: Failed to invoke action for event: \ax\ay'..event.name..'\ax')
            print('\t\ar'..result..'\ax')
        end
    elseif not success then
        print('\arERROR: Failed to invoke condition for event: \ax\ay'..event.name..'\ax')
        print('\t\ar'..result..'\ax')
    end
end

local function manage_conditions()
    for event_name, enabled in pairs(char_settings[event_types.cond]) do
        local event = condition_events[event_name]
        if enabled and event then
            if not event.loaded and not event.failed then
                load_condition(event)
            end
            if event.loaded then
                evaluate_condition(event)
            end
        end
    end
end

local function print_help()
    print(('\a-t[\ax\ayLua Event Manager v%s\ax\a-t]\ax'):format(version))
    print('\axAvailable Commands:')
    print('\t- \ay/lem help\ax -- Display this help output.')
    print('\t- \ay/lem event <event_name> [on|1|true|off|0|false]\ax -- Toggle the named text event on/off.')
    print('\t- \ay/lem cond <event_name> [on|1|true|off|0|false]\ax -- Toggle the named condition event on/off.')
    print('\t- \ay/lem show\ax -- Show the UI.')
    print('\t- \ay/lem hide\ax -- Hide the UI.')
    print('\t- \ay/lem reload\ax -- Reload settings (Currently just restarts the script).')
end

local ON_VALUES = {['on']=1,['1']=1,['true']=1}
local OFF_VALUES = {['off']=1,['0']=1,['false']=1}
local function cmd_handler(...)
    local args = {...}
    if #args < 1 then
        print_help()
        return
    end
    local command = args[1]
    if command == 'help' then
        print_help()
    elseif command == 'event' then
        if #args < 2 then return end
        local enable
        if #args > 2 then enable = args[3] end
        local event_name = args[2]
        local event = text_events[event_name]
        if event then
            if enable and ON_VALUES[enable] and char_settings.events[event_name] then
                return -- event is already on, do nothing
            elseif enable and OFF_VALUES[enable] and not char_settings.events[event_name] then
                return -- event is already off, do nothing
            end
            toggle_event(event, event_types.text)
        end
    elseif command == 'cond' then
        if #args < 2 then return end
        local event_name = args[2]
        local enable
        if #args > 2 then enable = args[3] end
        local event = condition_events[event_name]
        if event then
            if enable and ON_VALUES[enable] and char_settings.conditions[event_name] then
                return -- event is already on, do nothing
            elseif enable and OFF_VALUES[enable] and not char_settings.conditions[event_name] then
                return -- event is already off, do nothing
            end
            toggle_event(event, event_types.cond)
            print(('Condition event \ay%s\ax enabled: %s'):format(event.name, char_settings[event_types.cond][event.name]))
        end
    elseif command == 'show' then
        state.ui.main.open_ui = true
    elseif command == 'hide' then
        state.ui.main.open_ui = false
    elseif command == 'reload' then
        mq.cmd('/timed 10 /lua run lem')
        state.terminate = true
    end
end

init_settings()
init_char_settings()
mq.imgui.init('Lua Event Manager', lem_ui)
mq.bind('/lem', cmd_handler)

while not state.terminate do
--    for idx, ui_id in ipairs(event_ui_ids) do
--        mq.imgui.destroy(ui_id)
--        table.remove(event_ui_ids, idx)
--    end
    manage_events()
    manage_conditions()
    mq.doevents()
    mq.delay(settings.settings.frequency)
end
