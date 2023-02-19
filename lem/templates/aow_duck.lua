---@type Mq
local mq = require('mq')

if not package.loaded['lem.events'] then print('This script is intended to be imported to Lua Event Manager (LEM). Try "\a-t/lua run lem\a-t"') end

local function event_handler()
    -- pause automation, alternatively have autostand off
    mq.cmd('/boxr pause')
    mq.cmd('/keypress d')
end

return {eventfunc=event_handler}
