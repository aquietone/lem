local mq = require('mq')

local counter = 0

local function on_load()
    -- Initialize anything here when the event loads
    Write.Debug('ENTER on_load')
end

local function event_handler()
    Write.Debug('ENTER event_handler')
    counter = counter + 1
    Write.Info('My class is %s, and this event has fired %d times.', mq.TLO.Me.Class(), counter)
end

return {onload=on_load, eventfunc=event_handler}