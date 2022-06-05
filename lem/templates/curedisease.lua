local mq = require('mq')

---@return boolean @Returns true if the action should fire, otherwise false.
local function condition()
    local counter = mq.TLO.Me.Diseased.CounterNumber()
    return counter and counter > 0 and
        mq.TLO.Me.ItemReady('Shield of the Immaculate')()
end

local function action()
    mq.cmd('/useitem "Shield of the Immaculate"')
end

return {condfunc=condition, actionfunc=action}