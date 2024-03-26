local mq = require('mq')

local function on_load()
    -- Perform any initial setup here when the event is loaded.
end

local function condition()
    -- this condition will evaluate to true when your HP is below 50%
    return mq.TLO.Me.PctHPs() < 50
end

local function action()
    print('test event 2')
end

return {onload=on_load, condfunc=condition, actionfunc=action}
