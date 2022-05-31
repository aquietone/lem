local mq = require('mq')

local counter = 0

local function on_load()
    -- Initialize anything here when the event loads
end

local function event_handler()
    counter = counter + 1
    print(tostring(counter)..': '..mq.TLO.Me.Class())
end

return {onload=on_load, eventfunc=event_handler}