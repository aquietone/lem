local mq = require('mq')

local counter = 0

local function event_handler()
    counter = counter + 1
    print(tostring(counter)..': '..mq.TLO.Me.Class())
end

return event_handler