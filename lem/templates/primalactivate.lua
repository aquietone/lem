-- Swap to 'primal' bandolier when avatar buff is missing in combat
local mq = require('mq')

---@return boolean @Returns true if the action should fire, otherwise false.
local function condition()
    local remaining = mq.TLO.Me.Buff('Avatar').Duration()
    return mq.TLO.Me.CombatState() == 'COMBAT' and
        not mq.TLO.Me.Buff('Avatar')() and
        mq.TLO.Spell('Avatar').Stacks() and
        not mq.TLO.InvSlot(13).Item.Name():find('Primal') and
        (not remaining or remaining < 45000)
end

local function action()
    mq.cmdf('/bandolier activate primal')
end

return {condfunc=condition, actionfunc=action}