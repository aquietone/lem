local mq = require('mq')
local library = require('library')

local itemname = 'Journeyman\'s Boots'
local buffname = 'Journeyman Boots'

if not package.loaded['events'] then print('This script is intended to be imported to Lua Event Manager (LEM). Try "\a-t/lua run lem\a-x"') end

---@return boolean @Returns true if the action should fire, otherwise false.
local function condition()
    Write.Debug('ENTER condition')
    -- Check everything under the sun just as an example. Usually you can get away with checking a lot less before casting.
    return mq.TLO.FindItem(itemname)() ~= nil and
        not mq.TLO.Me.Buff(buffname)() and
        mq.TLO.Spell(buffname).Stacks() and
        mq.TLO.Me.FreeBuffSlots() > 0 and
        not mq.TLO.Me.Invis() and
        not mq.TLO.Me.Casting() and
        mq.TLO.Me.Standing() and
        library.in_control()
end

local function action()
    Write.Debug('ENTER action')
    Write.Info('Using item: %s', itemname)
    mq.cmdf('/useitem "%s"', itemname)
end

return {condfunc=condition, actionfunc=action}