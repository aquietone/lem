local mq = require('mq')

local function testevent1()
    print(mq.TLO.Me.Name())
end

return testevent1