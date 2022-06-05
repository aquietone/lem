local mq = require('mq')

local function condition()
    if mq.TLO.Me.PctHPs() < 50 then return true end
    return false
end

local function action()
    print('oh no im dying!')
end

return {condfunc=condition, actionfunc=action}
