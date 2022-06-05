local mq = require('mq')
local library = require('lem.library')

local itemname = 'Journeyman\'s Boots'
local buffname = 'Journeyman Boots'

---@return boolean @Returns true if the action should fire, otherwise false.
local function condition()
    return mq.TLO.FindItem(itemname)() and 
        not mq.TLO.Me.Buff(buffname)() and
        mq.TLO.Spell(buffname).Stacks() and
        mq.TLO.Me.FreeBuffSlots() > 0 and
        not mq.TLO.Me.Invis() and
        not mq.TLO.Me.Casting() and
        mq.TLO.Me.Standing() and
        library.in_control()
end

local function action()
    mq.cmdf('/useitem "%s"', itemname)
end

return {condfunc=condition, actionfunc=action}