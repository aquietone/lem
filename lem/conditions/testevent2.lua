local mq = require('mq')

local function condition()
    return mq.TLO.Me.PctHPs() < 50
end

local function action()
    print('Just a Flesh Wound')
end

return {condfunc=condition, actionfunc=action}