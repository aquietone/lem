local mq = require('mq')

local function on_load()
    -- Perform any initial setup here when the event is loaded.
    Write.Debug('ENTER on_load')
end

local function event_handler()
    -- Implement the handling for the event here.
    Write.Debug('ENTER event_handler')
    Write.Info('My name is %s, prepare to die!', mq.TLO.Me.CleanName())
end

return {onload=on_load, eventfunc=event_handler}