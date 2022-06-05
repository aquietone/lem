local mq = require('mq')

local function condition()
    return true
end

local function action()
    print('perform testevent1 action')
end

return {condfunc=condition, actionfunc=action}