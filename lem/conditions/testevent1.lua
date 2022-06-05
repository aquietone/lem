local mq = require('mq')

local function on_load()
    -- Perform any initial setup here when the event is loaded.
end

local function condition()
    -- this condition will always evaluate to true
    return true
end

local function action()
    print('test event 1')
end

return {onload=on_load, condfunc=condition, actionfunc=action}
