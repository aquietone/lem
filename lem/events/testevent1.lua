local mq = require('mq')

local function event_handler()
    print(mq.TLO.Me.Name())
end

return event_handler