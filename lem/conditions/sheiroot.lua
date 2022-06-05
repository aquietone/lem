local mq = require('mq')

local function condition()
    return mq.TLO.SpawnCount('datiar xi tavuelim npc')() > 0
end

local function action()
    local my_class = mq.TLO.Me.Class.ShortName():lower()
    local shackle = mq.TLO.Spell('Shackle').RankName()

    mq.cmdf('/%s pause on', my_class)
    if mq.TLO.Target.CleanName() ~= 'datiar xi tavuelim' then
        mq.cmd('/mqtar datiar xi tavuelim npc')
        mq.delay(50)
    end
    if mq.TLO.Me.SpellReady(shackle)() and not mq.TLO.Me.Casting() then
        mq.cmdf('/cast %s', shackle)
        mq.delay(1000+mq.TLO.Spell(shackle).MyCastTime())
    end
    mq.cmdf('/%s pause off', my_class)
end

return {condfunc=condition, actionfunc=action}