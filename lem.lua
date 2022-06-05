--[[
lua event manager v0.1.0 -- aquietone
]]
local mq = require 'mq'
require 'ImGui'
local persistence = require('lem.persistence')
local version = '0.1.0'

-- application state
local state = {
    terminate = false,
    ui = {
        main = {
            title = ('Lua Event Manager (v%s)###lem'):format(version),
            open_ui = true,
            draw_ui = true,
            menu_idx = 0,
            event_idx = 0,
            menu_width = 120,
        },
        editor = {
            open_ui = false,
            draw_ui = false,
            action = nil,
            event_idx = 0,
            event_type = nil,
        }
    }
}

local table_flags = bit32.bor(ImGuiTableFlags.Hideable, ImGuiTableFlags.RowBg, ImGuiTableFlags.ScrollY, ImGuiTableFlags.BordersOuter)
local actions = {add=1,edit=2,view=3}
local event_types = {text='events',cond='conditions'}
local base_dir = mq.luaDir .. '/lem'
local menu_default_width = 120

local text_code_template = "local mq = require('mq')\
\
local function event_handler()\
    \
end\
\
return event_handler"

local condition_code_template = "local mq = require('mq')\
\
local function condition()\
    \
end\
\
local function action()\
    \
end\
\
return {condfunc=condition, actionfunc=action}"

local settings = require('lem.settings')
local text_events = settings.text_events
local condition_events = settings.condition_events

local char_settings = nil

local function init_char_settings()
    local my_name = mq.TLO.Me.CleanName():lower()
    local ok, module = pcall(require, 'lem.characters.'..my_name)
    if not ok then
        char_settings = {events={}, conditions={}}
        persistence.store(('%s/characters/%s.lua'):format(base_dir, my_name), char_settings)
        char_settings = require('lem.characters.'..my_name)
    else
        char_settings = module
    end
end

local function save_settings()
    persistence.store(('%s/settings.lua'):format(base_dir), settings)
    persistence.store(('%s/characters/%s.lua'):format(base_dir, mq.TLO.Me.CleanName():lower()), char_settings)
end

local function file_exists(file)
    local f = io.open(file, "r")
    if f ~= nil then io.close(f) return true else return false end
end

local function read_file(file)
    local f = io.open(file, 'r')
    local contents = f:read('*a')
    io.close(f)
    return contents
end

local function write_file(file, contents)
    local f = io.open(file, 'w')
    f:write(contents)
    io.close(f)
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

local add_event = {name='', enabled=false, pattern='', code=''}

local function reset_add_event_inputs(event_type)
    add_event = {name='', enabled=false, pattern=''}
    if event_type == event_types.text then
        add_event.code = text_code_template
    elseif event_type == event_types.cond then
        add_event.code = condition_code_template
    end
end

local function set_add_event_inputs(event)
    add_event = {
        name=event.name,
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

local function save_event()
    local events = get_event_list(state.ui.editor.event_type)
    if add_event.code:len() > 0 and add_event.name:len() > 0 then
        if state.ui.editor.event_type == event_types.text and add_event.pattern:len() == 0 then
            return
        end
        local new_event = {name=add_event.name}
        if state.ui.editor.event_type == event_types.text then
            new_event.pattern = add_event.pattern
            mq.unevent(new_event.name)
        end
        write_file(event_filename(state.ui.editor.event_type, add_event.name), add_event.code)
        if state.ui.editor.action == actions.add then
            table.insert(events, new_event)
        else
            unload_event_package(state.ui.editor.event_type, add_event.name)
            events[state.ui.editor.event_idx] = new_event
        end
        char_settings[state.ui.editor.event_type][add_event.name] = add_event.enabled
        save_settings()
        state.ui.editor.open_ui = false
    end
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
        add_event.name,_ = ImGui.InputText('Event Name', add_event.name)
        add_event.enabled,_ = ImGui.Checkbox('Event Enabled', add_event.enabled, add_event.enabled)
        if state.ui.editor.event_type == event_types.text then
            add_event.pattern,_ = ImGui.InputText('Event Pattern', add_event.pattern)
        end
        ImGui.Text('Event Code')
        local x, y = ImGui.GetContentRegionAvail()
        add_event.code,_ = ImGui.InputTextMultiline('###EventCode', add_event.code, x-100, y-20)
    end
    ImGui.End()
end

local function draw_event_viewer()
    if not state.ui.editor.open_ui then return end
    state.ui.editor.open_ui, state.ui.editor.draw_ui = ImGui.Begin('Event Viewer###lemeditor', state.ui.editor.open_ui)
    local events = get_event_list(state.ui.editor.event_type)
    local event = events[state.ui.editor.event_idx]
    if state.ui.editor.draw_ui and event then
        if ImGui.Button('Edit Event') then
            state.ui.editor.action = actions.edit
            set_add_event_inputs(event)
        end
        ImGui.TextColored(1, 1, 0, 1, 'Name: ')
        ImGui.SameLine()
        ImGui.SetCursorPosX(100)
        if char_settings[state.ui.editor.event_type][event.name] then
            ImGui.TextColored(0, 1, 0, 1, event.name)
        else
            ImGui.TextColored(1, 0, 0, 1, event.name .. ' (Disabled)')
        end
        if state.ui.editor.event_type == event_types.text then
            ImGui.TextColored(1, 1, 0, 1, 'Pattern: ')
            ImGui.SameLine()
            ImGui.SetCursorPosX(100)
            ImGui.TextColored(1, 0, 1, 1, event.pattern)
        end
        ImGui.TextColored(1, 1, 0, 1, 'Code:')
        ImGui.TextColored(0, 1, 1, 1, event.code)
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
        state.ui.main.event_idx = 0
        set_editor_state(true, actions.add, event_type, 0)
        reset_add_event_inputs(event_type)
    end
    if state.ui.main.event_idx > 0 then
        local event = events[state.ui.main.event_idx]
        ImGui.SameLine()
        if ImGui.Button('View Event') then
            set_editor_state(true, actions.view, event_type, state.ui.main.event_idx)
            state.ui.main.event_idx = 0
            if not event.code then
                event.code = read_file(event_filename(event_type, event.name))
            end
        end
        ImGui.SameLine()
        if ImGui.Button('Edit Event') then
            set_editor_state(true, actions.edit, event_type, state.ui.main.event_idx)
            state.ui.main.event_idx = 0
            if not event.code then
                event.code = read_file(event_filename(event_type, event.name))
            end
            set_add_event_inputs(event)
        end
        ImGui.SameLine()
        if ImGui.Button('Remove Event') then
            table.remove(events, state.ui.main.event_idx)
            if event_type == event_types.text and char_settings[event_type][event.name] then
                mq.unevent(event.name)
            end
            unload_event_package(event_type, event.name)
            state.ui.main.event_idx = 0
            os.execute(('del %s'):format(event_filename(event_type, event.name):gsub('/', '\\')))
            save_settings()
            set_editor_state(false, nil, nil, 0)
        end
    end
end

local function draw_events_table(event_type)
    if ImGui.BeginTable('EventTable', 1, table_flags, 0, 0, 0.0) then
        ImGui.TableSetupColumn('Event Name',     0,   -1.0, 1)
        ImGui.TableSetupScrollFreeze(0, 1) -- Make row always visible
        ImGui.TableHeadersRow()

        local events = get_event_list(event_type)
        local clipper = ImGuiListClipper.new()
        clipper:Begin(#events)
        while clipper:Step() do
            for row_n = clipper.DisplayStart, clipper.DisplayEnd - 1, 1 do
                local event = events[row_n + 1]
                ImGui.TableNextRow()
                ImGui.TableNextColumn()
                if char_settings[event_type][event.name] then
                    ImGui.PushStyleColor(ImGuiCol.Text, 0, 1, 0, 1)
                else
                    ImGui.PushStyleColor(ImGuiCol.Text, 1, 0, 0, 1)
                end
                if ImGui.Selectable(event.name, state.ui.main.event_idx == row_n + 1, ImGuiSelectableFlags.SpanAllColumns) then
                    if state.ui.main.event_idx ~= row_n + 1 then
                        state.ui.main.event_idx = row_n + 1
                    end
                end
                ImGui.PopStyleColor()
                if ImGui.IsItemHovered() and ImGui.IsMouseDoubleClicked(0) then
                    set_editor_state(true, actions.view, event_type, row_n + 1)
                    state.ui.main.event_idx = 0
                    if not event.code then
                        event.code = read_file(event_filename(event_type, event.name))
                    end
                end
                ImGui.TableNextRow()
                ImGui.TableNextColumn()
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
                    state.ui.main.menu_idx = idx
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
        end
    end

    pop_style()
end

local function manage_events()
    for _,event in ipairs(text_events) do
        if char_settings[event_types.text][event.name] and not event.registered and not event.failed then
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
        elseif not char_settings[event_types.text][event.name] and event.registered then
            print('Deregistering event: \ay'..event.name..'\ax')
            mq.unevent(event.name)
            event.registered = false
            event.func = nil
        end
    end
end

local function manage_conditions()
    for _,event in ipairs(condition_events) do
        if char_settings[event_types.cond][event.name] then
            if not event.loaded and not event.failed then
                local success, result = pcall(require, 'lem.conditions.'..event.name)
                if not success then
                    result = nil
                    event.failed = true
                    print('Event registration failed: \ay'..event.name..'\ax')
                else
                    event.funcs = result
                    event.loaded = true
                end
            end
            if event.funcs.condfunc() then
                event.funcs.actionfunc()
            end
        end
    end
end

local function toggle_event(event, event_type)
    char_settings[event_type][event.name] = not char_settings[event_type][event.name]
    if not char_settings[event_type][event.name] then
        unload_event_package(event_type, event.name)
        event.loaded = false
        event.func = nil
        event.funcs = nil
        event.failed = nil
    end
    save_settings()
end

local function print_help()
    print(('\a-t[\ax\ayLua Event Manager v%s\ax\a-t]\ax'):format(version))
    print('\axAvailable Commands:')
    print('\t- \ay/lem help\ax -- Display this help output.')
    print('\t- \ay/lem event <event_name>\ax -- Toggle the named text event on/off.')
    print('\t- \ay/lem cond <event_name>\ax -- Toggle the named condition event on/off.')
    print('\t- \ay/lem show\ax -- Show the UI.')
    print('\t- \ay/lem hide\ax -- Hide the UI.')
    print('\t- \ay/lem reload\ax -- Reload settings (Currently just restarts the script).')
end

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
        local event_name = args[2]
        for _,event in ipairs(text_events) do
            if event.name == event_name then
                toggle_event(event, event_types.text)
            end
        end
    elseif command == 'cond' then
        if #args < 2 then return end
        local event_name = args[2]
        for _,event in ipairs(condition_events) do
            if event.name == event_name then
                toggle_event(event, event_types.cond)
                print(('Condition event \ay%s\ax enabled: %s'):format(event.name, char_settings[event_types.cond][event.name]))
            end
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

init_char_settings()
mq.imgui.init('Lua Event Manager', lem_ui)
mq.bind('/lem', cmd_handler)

while not state.terminate do
    manage_events()
    manage_conditions()
    mq.doevents()
    mq.delay(settings.settings.frequency)
end