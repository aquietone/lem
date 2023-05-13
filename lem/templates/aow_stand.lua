---@type Mq
local mq = require('mq')

if not package.loaded['lem.events'] then print('This script is intended to be imported to Lua Event Manager (LEM). Try "\a-t/lua run lem\a-t"') end

local function event_handler()
    mq.cmd('/stand')
    -- mq.cmdf('/%s pause off', mq.TLO.Me.Class.ShortName())
    -- mq.cmd('/mqp off')
    mq.cmd('/boxr unpause')
end

return {eventfunc=event_handler}