local mq = require('mq')

local function event_handler()
    -- pause automation, alternatively have autostand off
    mq.cmd('/boxr pause')
    mq.cmd('/keypress d')
end

return {eventfunc=event_handler}