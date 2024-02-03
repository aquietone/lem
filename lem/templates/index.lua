local mq = require('mq')
local base_dir = mq.luaDir .. '/lem'

local text_code_template = "local mq = require('mq')\n\
-- Do not edit this if condition\
if not package.loaded['events'] then\
    print('This script is intended to be imported to Lua Event Manager (LEM). Try \"\\a-t/lua run lem\\a-x\"')\
end\n\
local function on_load()\n    -- Perform any initial setup here when the event is loaded.\nend\n\
local function event_handler()\n    -- Implement the handling for the event here.\nend\n\
return {onload=on_load, eventfunc=event_handler}"

local condition_code_template = "local mq = require('mq')\n\
-- Do not edit this if condition\
if not package.loaded['events'] then\
    print('This script is intended to be imported to Lua Event Manager (LEM). Try \"\\a-t/lua run lem\\a-x\"')\
end\n\
local function on_load()\n    -- Perform any initial setup here when the event is loaded.\nend\n\
---@return boolean @Returns true if the action should fire, otherwise false.\
local function condition()\n    -- Implement the condition to evaluate here.\nend\n\
local function action()\n    -- Implement the action to perform here.\nend\n\
return {onload=on_load, condfunc=condition, actionfunc=action}"

local command_code_template = "--This is a single command event. The code should not be edited manually.\
local mq = require('mq')\n\
-- Do not edit this if condition\
if not package.loaded['events'] then\
    print('This script is intended to be imported to Lua Event Manager (LEM). Try \"\\a-t/lua run lem\\a-x\"')\
end\n\
local function event_handler()\n    mq.cmd('%s')\nend\n\
return {eventfunc=event_handler}"

local templates = {
    files={'event_runout', 'react_bane', 'react_click_jboots', 'curedisease', 'primalactivate', 'primaldeactivate', 'aow_duck', 'aow_stand'},
    text_base=text_code_template,
    condition_base=condition_code_template,
    command_base=command_code_template,
    filename = function(name)
        return ('%s/templates/%s.lua'):format(base_dir, name)
    end;
}

return templates