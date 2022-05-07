--[[
lua event manager
]]
local mq = require 'mq'
require 'ImGui'

-- GUI Control variables
local open_lem_ui = true
local draw_lem_ui = true
local terminate = false

local open_editor_ui = false
local draw_editor_ui = false
local editor_action = nil
local actions = {add=1,edit=2,view=3}
local event_types = {text='events',cond='conditions'}

local settings = require('lem.settings')
local text_events = settings.text_events
local condition_events = settings.condition_events

local base_dir = mq.luaDir .. '/lem'

local selected_menu_item = 0
local selected_event_idx = 0

local left_panel_width = 120
local left_panel_default_width = 120

local TABLE_FLAGS = bit32.bor(ImGuiTableFlags.Hideable, ImGuiTableFlags.RowBg, ImGuiTableFlags.ScrollY, ImGuiTableFlags.BordersOuter)

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

local add_event_name = ''
local add_event_enabled = false
local add_event_pattern = ''
local add_event_code = ''

local function save_event(event_type)
    local events = text_events
    if event_type == event_types.cond then
        events = condition_events
    end
    if add_event_code:len() > 0 and add_event_name:len() > 0 then
        if event_type == event_types.text and add_event_pattern:len() == 0 then
            return
        end
        local new_event = {name=add_event_name, enabled=add_event_enabled}
        if event_type == event_types.text then
            new_event.pattern = add_event_pattern
        end
        write_file(event_filename(event_type, add_event_name), add_event_code)
        if editor_action == actions.add then
            table.insert(events, new_event)
        else
            events[selected_event_idx] = new_event
        end
        open_editor_ui = false
    end
end

local function draw_event_editor(event_type)
    if not open_editor_ui then return end
    open_editor_ui, draw_editor_ui = ImGui.Begin('Event Editor###lemeditor', open_editor_ui)
    if draw_editor_ui then
        if ImGui.Button('Save') then
            save_event(event_type)
        end
        add_event_name,_ = ImGui.InputText('Event Name', add_event_name)
        add_event_enabled,_ = ImGui.Checkbox('Event Enabled', add_event_enabled, add_event_enabled)
        if event_type == event_types.text then
            add_event_pattern,_ = ImGui.InputText('Event Pattern', add_event_pattern)
        end
        ImGui.Text('Event Code')
        local x, y = ImGui.GetContentRegionAvail()
        add_event_code,_ = ImGui.InputTextMultiline('###EventCode', add_event_code, x-100, y-20)
    end
    ImGui.End()
end

local function draw_event_viewer(event_type)
    if not open_editor_ui then return end
    open_editor_ui, draw_editor_ui = ImGui.Begin('Event Viewer###lemeditor', open_editor_ui)
    local events = text_events
    if event_type == event_types.cond then
        events = condition_events
    end
    local event = events[selected_event_idx]
    if draw_editor_ui and event then
        ImGui.TextColored(1, 1, 0, 1, 'Name: ')
        ImGui.SameLine()
        if event.enabled then
            ImGui.TextColored(0, 1, 0, 1, event.name)
        else
            ImGui.TextColored(1, 0, 0, 1, event.name .. ' (Disabled)')
        end
        if event_type == event_types.text then
            ImGui.TextColored(1, 1, 0, 1, 'Pattern: ')
            ImGui.SameLine()
            ImGui.Text(event.pattern)
        end
        ImGui.TextColored(1, 1, 0, 1, 'Code:')
        ImGui.Text(event.code)
    end
    ImGui.End()
end

local function reset_add_event_inputs(event_type)
    add_event_name = ''
    add_event_enabled = false
    add_event_pattern = ''
    if event_type == event_types.text then
        add_event_code = text_code_template
    elseif event_type == event_types.cond then
        add_event_code = condition_code_template
    end
end

local function set_add_event_inputs(event)
    add_event_name = event.name
    add_event_enabled = event.enabled
    add_event_pattern = event.pattern
    add_event_code = event.code
end

local function draw_event_control_buttons(event_type)
    local events = text_events
    if event_type == event_types.cond then
        events = condition_events
    end
    if ImGui.Button('Add Event...') then
        open_editor_ui = true
        editor_action = actions.add
        reset_add_event_inputs(event_type)
    end
    if selected_event_idx > 0 then
        local event = events[selected_event_idx]
        ImGui.SameLine()
        if ImGui.Button('View Event') then
            open_editor_ui = true
            editor_action = actions.view
            if not event.code then
                event.code = read_file(event_filename(event_type, event.name))
            end
        end
        ImGui.SameLine()
        if ImGui.Button('Edit Event') then
            open_editor_ui = true
            editor_action = actions.edit
            if not event.code then
                event.code = read_file(event_filename(event_type, event.name))
            end
            set_add_event_inputs(event)
        end
        ImGui.SameLine()
        if ImGui.Button('Remove Event') then
            if event.enabled then
                mq.unevent(event.name)
            end
            table.remove(events, selected_event_idx)
            os.execute(('del %s'):format(event_filename(event_type, event.name)))
        end
    end
end

local function draw_events_table(event_type)
    if ImGui.BeginTable('TextEventTable', 1, TABLE_FLAGS, 0, 0, 0.0) then
        ImGui.TableSetupColumn('Event Name',     0,   -1.0, 1)
        ImGui.TableSetupScrollFreeze(0, 1) -- Make row always visible
        ImGui.TableHeadersRow()

        local events = text_events
        if event_type == event_types.cond then
            events = condition_events
        end
        local clipper = ImGuiListClipper.new()
        clipper:Begin(#events)
        while clipper:Step() do
            for row_n = clipper.DisplayStart, clipper.DisplayEnd - 1, 1 do
                local event = events[row_n + 1]
                ImGui.TableNextRow()
                ImGui.TableNextColumn()
                if event.enabled then
                    ImGui.PushStyleColor(ImGuiCol.Text, 0, 1, 0, 1)
                else
                    ImGui.PushStyleColor(ImGuiCol.Text, 1, 0, 0, 1)
                end
                if ImGui.Selectable(event.name, selected_event_idx == row_n + 1, ImGuiSelectableFlags.SpanAllColumns) then
                    if selected_event_idx ~= row_n + 1 then
                        selected_event_idx = row_n + 1
                    end
                end
                ImGui.PopStyleColor()
                if ImGui.IsItemHovered() and ImGui.IsMouseDoubleClicked(0) then
                    open_editor_ui = true
                    editor_action = actions.view
                    selected_event_idx = row_n + 1
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

    if open_editor_ui then
        if editor_action == actions.add or editor_action == actions.edit then
            draw_event_editor(event_type)
        elseif editor_action == actions.view then
            draw_event_viewer(event_type)
        end
    end
end

local function draw_characters_section()

end

local function draw_settings_section()

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
        name='Characters',
        handler=draw_characters_section,
    },
    {
        name='Settings',
        handler=draw_settings_section,
    }
}

local function draw_selected_section()
    local x,y = ImGui.GetContentRegionAvail()
    if ImGui.BeginChild("right", x, y-1, true) then
        if selected_menu_item > 0 then
            sections[selected_menu_item].handler(sections[selected_menu_item].arg)
        end
    end
    ImGui.EndChild()
end

local function draw_menu()
    local _,y = ImGui.GetContentRegionAvail()
    if ImGui.BeginChild("left", left_panel_width, y-1, true) then
        if ImGui.BeginTable('MenuTable', 1, TABLE_FLAGS, 0, 0, 0.0) then
            for idx,section in ipairs(sections) do
                ImGui.TableNextRow()
                ImGui.TableNextColumn()
                if ImGui.Selectable(section.name, selected_menu_item == idx) then
                    selected_menu_item = idx
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
        left_panel_width = size0
    else
        left_panel_default_width = left_panel_width
    end
    ImGui.SetCursorPosX(x)
    ImGui.SetCursorPosY(y)
end

-- ImGui main function for rendering the UI window
local lem_ui = function()
    open_lem_ui, draw_lem_ui = ImGui.Begin('LUA Event Manager', open_lem_ui)
    if draw_lem_ui then
        draw_splitter(8, left_panel_default_width, 75)
        ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 2, 2)
        draw_menu()
        ImGui.SameLine()
        draw_selected_section()
        ImGui.PopStyleVar()
    end
    ImGui.End()
    if not open_lem_ui then
        terminate = true
    end
end

local function manage_events()
    for _,event in ipairs(text_events) do
        if event.enabled and not event.registered then
            print('Registering event: \ay'..event.name..'\ax')
            event.func = require('lem.events.'..event.name)
            mq.event(event.name, event.pattern, event.func)
            event.registered = true
        elseif not event.enabled and event.registered then
            print('Deregistering event: \ay'..event.name..'\ax')
            mq.unevent(event.name)
            event.registered = false
            event.func = nil
        end
    end
end

local function manage_conditions()
    for _,event in ipairs(condition_events) do
        if event.enabled then
            if not event.loaded then
                event.funcs = require('lem.conditions.'..event.name)
                event.loaded = true
            end
            if event.funcs.condfunc() then
                event.funcs.actionfunc()
            end
        end
    end
end

mq.imgui.init('LUA Event Manager', lem_ui)

while not terminate do
    manage_events()
    manage_conditions()
    mq.doevents()
    mq.delay(settings.settings.frequency)
end