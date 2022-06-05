local text_code_template = "local mq = require('mq')\n\
local function on_load()\n    -- Perform any initial setup here when the event is loaded.\nend\n\
local function event_handler()\n    -- Implement the handling for the event here.\nend\n\
return {onload=on_load, eventfunc=event_handler}"

local condition_code_template = "local mq = require('mq')\n\
---@return boolean @Returns true if the action should fire, otherwise false.\n\
local function on_load()\n    -- Perform any initial setup here when the event is loaded.\nend\n\
local function condition()\n    -- Implement the condition to evaluate here.\nend\n\
local function action()\n    -- Implement the action to perform here.\nend\n\
return {onload=on_load, condfunc=condition, actionfunc=action}"

local templates = {
    files={'event_runout', 'react_bane'},
    text_base=text_code_template,
    condition_base=condition_code_template,
}

return templates