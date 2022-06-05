local mq = require('mq')

local function event_handler()
    mq.cmd('/stand')
    mq.cmd('/boxr unpause')
end

return {eventfunc=event_handler}