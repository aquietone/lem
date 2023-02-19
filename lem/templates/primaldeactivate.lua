-- Swap to 'main' bandolier when avatar weapon procs
---@type Mq
local mq = require('mq')

if not package.loaded['lem.events'] then print('This script is intended to be imported to Lua Event Manager (LEM). Try "\a-t/lua run lem\a-t"') end

---@return boolean @Returns true if the action should fire, otherwise false.
local function condition()
    return mq.TLO.Me.CombatState() == 'COMBAT' and
        mq.TLO.Me.Buff('Avatar')() and
        mq.TLO.InvSlot(13).Item.Name():find('Primal') and
        mq.TLO.Me.Buff('Avatar').Duration() >= 45000
end

local function action()
    mq.cmdf('/bandolier activate main')
end

return {condfunc=condition, actionfunc=action}
