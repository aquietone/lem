---@type Mq
local mq = require('mq')

local required_zone = 'akhevatwo_mission'
local bane_mob_name = 'datiar xi tavuelim'

local banes = {
    BRD={name='Slumber of the Diabo',type='spell'},
    CLR={name='Shackle',type='spell'},
    ENC={name='Beguiler\'s Banishment',type='aa'},
    SHM={name='Virulent Paralysis',type='aa'},
}

if not package.loaded['lem.events'] then print('This script is intended to be imported to Lua Event Manager (LEM). Try "\a-t/lua run lem\a-t"') end

local function on_load()
    if mq.TLO.Zone.ShortName() ~= required_zone then return end
    local bane = banes[mq.TLO.Me.Class.ShortName()]
    if bane and bane.type == 'spell' then
        mq.cmd('/boxr pause')
        mq.cmdf('/memspell 13 "%s"', bane.name)
        mq.delay('4s')
        mq.TLO.Window('SpellBookWnd').DoClose()
        mq.cmd('/boxr unpause')
    end
end

---@return boolean @Returns true if the action should fire, otherwise false.
local function condition()
    return mq.TLO.Zone.ShortName() == required_zone and mq.TLO.SpawnCount(('%s npc'):format(bane_mob_name))() > 0
end

local function target_bane_mob()
    if mq.TLO.Target.CleanName() ~= bane_mob_name then
        mq.cmdf('/mqtar %s npc', bane_mob_name)
        mq.delay(50)
    end
end

local function cast(spell)
    mq.cmdf('/cast %s', spell.RankName())
    mq.delay(500+spell.MyCastTime())
end

local function use_aa(aa)
    mq.cmdf('/alt activate %s', aa.ID())
    mq.delay(500+aa.Spell.CastTime())
end

local function bane_ready(bane)
    if bane.type == 'spell' then
        return mq.TLO.Me.SpellReady(bane.name) and not mq.TLO.Me.Casting()
    elseif bane.type == 'aa' then
        return mq.TLO.Me.AltAbilityReady(bane.name) and not mq.TLO.Me.Casting()
    end
end

local function action()
    local my_class = mq.TLO.Me.Class.ShortName()
    local bane = banes[my_class]
    -- if not a bane class, return
    if not bane then return end
    -- if bane ability isn't ready, return
    if my_class ~= 'BRD' and not bane_ready(bane) then return end

    mq.cmd('/boxr pause')
    target_bane_mob()
    if my_class == 'BRD' then mq.cmd('/stopsong') end
    if bane.type == 'spell' then
        cast(mq.TLO.Spell(bane.name))
    else
        use_aa(mq.TLO.Me.AltAbility(bane.name))
    end
    mq.cmd('/boxr unpause')
end

return {onload=on_load, condfunc=condition, actionfunc=action}
