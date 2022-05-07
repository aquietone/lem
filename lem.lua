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

local settings = require('lem.settings')
local text_events = settings.text_events
local condition_events = settings.condition_events

local selected_menu_item = 0
local selected_event_idx = 0

local left_panel_width = 120
local left_panel_default_width = 120

local TABLE_FLAGS = bit32.bor(ImGuiTableFlags.Hideable, ImGuiTableFlags.RowBg, ImGuiTableFlags.ScrollY, ImGuiTableFlags.BordersOuter)

local function read_file(file)
    local f = io.open(mq.luaDir..'/lem/'..file, 'r')
    local contents = f:read('*a')
    io.close(f)
    return contents
end

local function write_file(file, contents)
    local f = io.open(mq.luaDir..'/lem/'..file, 'w')
    f:write(contents)
    io.close(f)
end

local add_event_name = ''
local add_event_enabled = false
local add_event_pattern = ''
local add_event_code = ''

local function save_text_event()
    if add_event_code:len() > 0 and add_event_name:len() > 0 and add_event_pattern:len() > 0 then
        local new_event = {name=add_event_name, enabled=add_event_enabled, pattern=add_event_pattern}
        write_file(add_event_name..'.lua', add_event_code)
        if editor_action == actions.add then
            table.insert(text_events, new_event)
        else
            text_events[selected_event_idx] = new_event
        end
    end
end

local function draw_text_event_editor()
    if not open_editor_ui then return end
    open_editor_ui, draw_editor_ui = ImGui.Begin('Event Editor###lemeditor', open_editor_ui)
    if draw_editor_ui then
        if ImGui.Button('Save') then
            save_text_event()
        end
        add_event_name,_ = ImGui.InputText('Event Name', add_event_name)
        add_event_enabled,_ = ImGui.Checkbox('Event Enabled', add_event_enabled, add_event_enabled)
        add_event_pattern,_ = ImGui.InputText('Event Pattern', add_event_pattern)
        add_event_code,_ = ImGui.InputTextMultiline('Event Code', add_event_code)
    end
    ImGui.End()
end

local function draw_text_event_viewer()
    if not open_editor_ui then return end
    open_editor_ui, draw_editor_ui = ImGui.Begin('Event Viewer###lemeditor', open_editor_ui)
    if draw_editor_ui and text_events[selected_event_idx] then
        ImGui.TextColored(1, 1, 0, 1, 'Name: ')
        ImGui.SameLine()
        if text_events[selected_event_idx].enabled then
            ImGui.TextColored(0, 1, 0, 1, text_events[selected_event_idx].name)
        else
            ImGui.TextColored(1, 0, 0, 1, text_events[selected_event_idx].name .. ' (Disabled)')
        end
        ImGui.TextColored(1, 1, 0, 1, 'Pattern: ')
        ImGui.SameLine()
        ImGui.Text(text_events[selected_event_idx].pattern)
        ImGui.TextColored(1, 1, 0, 1, 'Code:')
        ImGui.Text(text_events[selected_event_idx].code)
    end
    ImGui.End()
end

local function reset_add_event_inputs()
    add_event_name = ''
    add_event_enabled = false
    add_event_pattern = ''
    add_event_code = ''
end

local function set_add_event_inputs(event)
    add_event_name = event.name
    add_event_enabled = event.enabled
    add_event_pattern = event.pattern
    add_event_code = event.code
end

local function draw_text_event_control_buttons()
    if ImGui.Button('Add Text Event...') then
        open_editor_ui = true
        editor_action = actions.add
        reset_add_event_inputs()
    end
    if selected_event_idx > 0 then
        local event = text_events[selected_event_idx]
        ImGui.SameLine()
        if ImGui.Button('View Event') then
            open_editor_ui = true
            editor_action = actions.view
            if not event.code then
                event.code = read_file(event.name..'.lua')
            end
        end
        ImGui.SameLine()
        if ImGui.Button('Edit Event') then
            open_editor_ui = true
            editor_action = actions.edit
            if not event.code then
                event.code = read_file(event.name..'.lua')
            end
            set_add_event_inputs(event)
        end
        ImGui.SameLine()
        if ImGui.Button('Remove Event') then
            if event.enabled then
                mq.unevent(event.name)
            end
            table.remove(text_events, selected_event_idx)
            os.execute(('del %s/lem/%s'):format(mq.luaDir, event.name..'.lua'))
        end
    end
end

local function draw_text_events_table()
    if ImGui.BeginTable('TextEventTable', 1, TABLE_FLAGS, 0, 0, 0.0) then
        ImGui.TableSetupColumn('Event Name',     0,   -1.0, 1)
        ImGui.TableSetupScrollFreeze(0, 1) -- Make row always visible
        ImGui.TableHeadersRow()

        local clipper = ImGuiListClipper.new()
        clipper:Begin(#text_events)
        while clipper:Step() do
            for row_n = clipper.DisplayStart, clipper.DisplayEnd - 1, 1 do
                local event = text_events[row_n + 1]
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
                        event.code = read_file(event.name..'.lua')
                    end
                end
                ImGui.TableNextRow()
                ImGui.TableNextColumn()
            end
        end
        ImGui.EndTable()
    end
end

local function draw_text_events_section()
    draw_text_event_control_buttons()
    draw_text_events_table()

    if open_editor_ui then
        if editor_action == actions.add or editor_action == actions.edit then
            draw_text_event_editor()
        elseif editor_action == actions.view then
            draw_text_event_viewer()
        end
    end
end

local function draw_cond_events_section()

end

local function draw_characters_section()

end

local function draw_settings_section()

end

local sections = {
    {
        name='Text Events', 
        handler=draw_text_events_section,
    },
    {
        name='Condition Events',
        handler=draw_cond_events_section,
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
            sections[selected_menu_item].handler()
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
        --ImGui.SetWindowSize(727,487)
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

mq.imgui.init('LUA Event Manager', lem_ui)

while not terminate do
    for _,event in ipairs(text_events) do
        if event.enabled and not event.registered then
            print('Registering event: \ay'..event.name..'\ax')
            event.func = require('lem.'..event.name)
            mq.event(event.name, event.pattern, event.func)
            event.registered = true
        elseif not event.enabled and event.registered then
            print('Deregistering event: \ay'..event.name..'\ax')
            mq.unevent(event.name)
            event.registered = false
            event.func = nil
        end
    end
    mq.doevents()
    mq.delay(1000)
end
