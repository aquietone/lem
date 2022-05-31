local mq = require('mq')

local function on_load()
    -- Perform any initial setup here when the event is loaded.
end

local function event_handler()
    -- Implement the handling for the event here.
    print(mq.TLO.Me.CleanName())
end

return {onload=on_load, eventfunc=event_handler}