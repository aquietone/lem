--[[
Helper functions for use in writing events.

To use, add the following line to your event code:

    local library = require('lem.library')

]]
local mq = require('mq')

local library = {}

---Wait the specified amount of time for navigation to complete.
---@param wait_time number @Optional, the time to wait to reach the location
library.wait_for_nav = function(wait_time)
    if wait_time and wait_time > 0 then
        mq.delay(50)
        mq.delay(wait_time, function() return not mq.TLO.Navigation.Active() end)
    end
end

---Navigate to the specified spawn ID and optionally wait for arrival.
---@param x number @The spawn ID to nav to
---@param wait_time number @Optional, the time to wait to reach the location
library.nav_to_id = function(id, wait_time)
    mq.cmdf('/nav id %d', id)
    library.wait_for_nav(wait_time)
end

---Navigate to the specified x,y,z coordinates and optionally wait for arrival.
---@param x number @The X location value
---@param y number @The Y location value
---@param z number @The Z location value
---@param wait_time number @Optional, the time to wait to reach the location
library.nav_to_locxyz = function(x, y, z, wait_time)
    mq.cmdf('/nav locxyz %d %d %d', x, y, z)
    library.wait_for_nav(wait_time)
end

---Target the spawn with the given ID
---@param id string @The ID of the spawn to target
library.get_target_by_id = function(id)
    if mq.TLO.Target.ID() ~= id then
        mq.cmdf('/mqt id %d', id)
        mq.delay(100, function() return mq.TLO.Target.ID() == id end)
    end
end

---Target the spawn with the given name
---@param name string @The name of the spawn to target
---@param type string @Optional. The type of spawn to target, such as pc or npc
library.get_target_by_name = function(name, type)
    if mq.TLO.Target.CleanName() ~= name then
        mq.cmdf('/mqt %s %s', name, type)
        mq.delay(100, function() return mq.TLO.Target.CleanName() == name end)
    end
end

---Return whether you are currently in control of your character.
---@return boolean @True if not under any loss of control effects, otherwise false.
library.in_control = function()
    local me = mq.TLO.Me
    return not me.Dead() and not me.Ducking() and not me.Charmed() and
        not me.Stunned() and not me.Silenced() and not me.Feigning() and
        not me.Mezzed() and not me.Invulnerable() and not me.Hovering()
end

---Return whether any UI windows are open which block doing things in game like casting spells.
---@return boolean @True if bank, merchant, trade or give windows are open, otherwise false.
library.blocking_window_open = function()
    -- check blocking windows -- BigBankWnd, MerchantWnd, GiveWnd, TradeWnd
    return mq.TLO.Window('BigBankWnd').Open() or mq.TLO.Window('MerchantWnd').Open() or mq.TLO.Window('GiveWnd').Open() or mq.TLO.Window('TradeWnd').Open()
end

---Return whether XTarget contains any auto-hater targets
---@return boolean @True if any auto hater slots have a target, otherwise false.
library.hostile_xtargets = function()
    if mq.TLO.Me.XTarget() == 0 then return false end
    for i=1,13 do
        if mq.TLO.Me.XTarget(i).TargetType() == 'Auto Hater' and mq.TLO.Me.XTarget(i).Type() == 'NPC' then
            return true
        end
    end
    return false
end

library.spell_types = {spell=1,disc=1,item=1,aa=1}
---Check whether a spell can be used (mana cost, in control of character, have reagents, spell ready)
---@param spell userdata @The spell userdata object.
---@param spell_type number @The type of spell (spell_types.spell, item or aa).
library.can_use_spell = function(spell, spell_type)
    if not spell() then return false end
    local result = true
    if spell_type == library.spell_types.spell and not mq.TLO.Me.SpellReady(spell.Name())() then result = false end
    if not library.in_control() or (mq.TLO.Me.Class.ShortName() ~= 'BRD' and (mq.TLO.Me.Casting() or mq.TLO.Me.Moving())) then result = false end
    if spell.Mana() > mq.TLO.Me.CurrentMana() or spell.EnduranceCost() > mq.TLO.Me.CurrentEndurance() then result = false end
    for i=1,3 do
        local reagentid = spell.ReagentID(i)()
        if reagentid ~= -1 then
            local reagent_count = spell.ReagentCount(i)()
            if mq.TLO.FindItemCount(reagentid)() < reagent_count then
                result = false
            end
        else
            break
        end
    end
    return result
end

---Perform stacking and distance checks on the given spell to determine if it should be cast
---@param spell userdata @The spell userdata object.
---@param skipselfstack boolean @True if stacking check should be skipped on self, otherwise false.
---@return boolean @Returns true if the spell should be used, otherwise false.
library.should_use_spell = function(spell, skipselfstack)
    local result = false
    local dist = mq.TLO.Target.Distance3D()
    if spell.Beneficial() then
        -- duration is number of ticks, so its tostring'd
        if spell.Duration() ~= '0' then
            if spell.TargetType() == 'Self' then
                -- skipselfstack == true when its a disc, so that a defensive disc can still replace a always up sort of disc
                -- like war resolute stand should be able to replace primal defense
                result = ((skipselfstack or spell.Stacks()) and not mq.TLO.Me.Buff(spell.Name())() and not mq.TLO.Me.Song(spell.Name())()) == true
            elseif spell.TargetType() == 'Single' then
                result = (dist and dist <= spell.MyRange() and spell.StacksTarget() and not mq.TLO.Target.Buff(spell.Name())()) == true
            else
                -- no one to check stacking on
                result = true
            end
        else
            if spell.TargetType() == 'Single' then
                result = (dist and dist <= spell.MyRange()) == true
            else
                -- instant beneficial spell
                result = true
            end
        end
    else
        -- duration is number of ticks, so its tostring'd
        if spell.Duration() ~= '0' then
            if spell.TargetType() == 'Single' or spell.TargetType() == 'Targeted AE' then
                result = (dist and dist <= spell.MyRange() and mq.TLO.Target.LineOfSight() and spell.StacksTarget() and not mq.TLO.Target.MyBuff(spell.Name())()) == true
            else
                -- no one to check stacking on
                result = true
            end
        else
            if spell.TargetType() == 'Single' or spell.TargetType() == 'LifeTap' then
                result = (dist and dist <= spell.MyRange() and mq.TLO.Target.LineOfSight()) == true
            else
                -- instant detrimental spell that requires no target
                result = true
            end
        end
    end
    return result
end

---Cast the spell specified by spell_name.
---@param spell_name string @The name of the spell to be cast.
---@param requires_target boolean @Indicate whether the spell requires a target.
---@return boolean @Returns true if the spell was cast, otherwise false.
library.cast = function(spell_name, requires_target)
    local spell = mq.TLO.Spell(spell_name)
    if not spell_name or not library.can_use_spell(spell, library.spell_types.spell) or not library.should_use_spell(spell, false) then return false end
    mq.cmdf('/cast "%s"', spell_name)
    mq.delay(10)
    if not mq.TLO.Me.Casting() then mq.cmdf('/cast %s', spell_name) end
    mq.delay(10)
    if not mq.TLO.Me.Casting() then mq.cmdf('/cast %s', spell_name) end
    mq.delay(10)
    while mq.TLO.Me.Casting() do
        if requires_target and not mq.TLO.Target() then
            mq.cmd('/stopcast')
            break
        end
        mq.delay(10)
    end
    return true
end

---Use the ability specified by name. These are basic abilities like taunt or kick.
---@param name string @The name of the ability to use.
library.use_ability = function(name)
    if mq.TLO.Me.AbilityReady(name)() and mq.TLO.Target() then
        mq.cmdf('/doability %s', name)
        mq.delay(500, function() return not mq.TLO.Me.AbilityReady(name)() end)
    end
end

---Determine whether the item is ready, including checking whether the character is currently capable.
---@param item userdata @The item userdata object
---@return boolean @Returns true if the item is ready to be used, otherwise false.
library.item_ready = function(item)
    if item() and item.Clicky.Spell() and item.Timer() == '0' then
        local spell = item.Clicky.Spell
        return library.can_use_spell(spell, library.spell_types.item) and library.should_use_spell(spell, false)
    else
        return false
    end
end

---Use the item specified by item.
---@param item Item @The MQ Item userdata object.
---@return boolean @Returns true if the item was fired, otherwise false.
library.use_item = function(item)
    if library.item_ready(item) then
        mq.cmdf('/useitem "%s"', item)
        mq.delay(500+item.CastTime()) -- wait for cast time + some buffer so we don't skip over stuff
        return true
    end
    return false
end

---Determine whether an AA is ready, including checking whether the character is currently capable.
---@param name string @The name of the AA to be used.
---@return boolean @Returns true if the AA is ready to be used, otherwise false.
library.aa_ready = function(name)
    if mq.TLO.Me.AltAbilityReady(name)() then
        local spell = mq.TLO.Me.AltAbility(name).Spell
        return library.can_use_spell(spell, library.spell_types.aa) and library.should_use_spell(spell, false)
    else
        return false
    end
end

---Use the AA specified by name.
---@param name string @The name of the AA to use.
---@return boolean @Returns true if the ability was fired, otherwise false.
library.use_aa = function(name)
    if library.aa_ready(name) then
        mq.cmdf('/alt activate %d', mq.TLO.Me.AltAbility(name).ID())
        mq.delay(250+mq.TLO.Me.AltAbility(name).Spell.CastTime()) -- wait for cast time + some buffer so we don't skip over stuff
        mq.delay(250, function() return not mq.TLO.Me.AltAbilityReady(name)() end)
        return true
    end
    return false
end

---Determine whether the disc specified by name is an "active" disc that appears in ${Me.ActiveDisc}.
---@param name string @The name of the disc to check.
---@return boolean @Returns true if the disc is an active disc, otherwise false.
library.is_disc = function(name)
    local spell = mq.TLO.Spell(name)
    local duration = tonumber(spell.Duration())
    if spell.IsSkill() and (duration and duration > 0) and spell.TargetType() == 'Self' and not spell.StacksWithDiscs() then
        return true
    else
        return false
    end
end

---Determine whether an disc is ready, including checking whether the character is currently capable.
---@param name string @The name of the disc to be used.
---@return boolean @Returns true if the disc is ready to be used, otherwise false.
library.disc_ready = function(name)
    if mq.TLO.Me.CombatAbility(name)() and mq.TLO.Me.CombatAbilityTimer(name)() == '0' and mq.TLO.Me.CombatAbilityReady(name)() then
        local spell = mq.TLO.Spell(name)
        return library.can_use_spell(spell, library.spell_types.disc) and library.should_use_spell(spell, true)
    else
        return false
    end
end

---Use the disc specified by name.
---@param name string @The name of the disc to use.
---@param overwrite boolean @The name of a disc which should be stopped in order to run this disc.
library.use_disc = function(name, overwrite)
    if library.disc_ready(name) then
        if not library.is_disc(name) or not mq.TLO.Me.ActiveDisc.ID() then
            if name:find('Composite') then
                mq.cmdf('/disc %s', mq.TLO.Me.CombatAbility(name).ID())
            else
                mq.cmdf('/disc %s', name)
            end
            mq.delay(250+mq.TLO.Spell(name).CastTime())
            mq.delay(250, function() return not mq.TLO.Me.CombatAbilityReady(name)() end)
            return true
        elseif overwrite == mq.TLO.Me.ActiveDisc.Name() then
            mq.cmd('/stopdisc')
            mq.delay(50)
            mq.cmdf('/disc %s', name)
            mq.delay(250+mq.TLO.Spell(name).CastTime())
            mq.delay(250, function() return not mq.TLO.Me.CombatAbilityReady(name)() end)
            return true
        end
    end
    return false
end

return library