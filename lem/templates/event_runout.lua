---@type Mq
local mq = require('mq')

if not package.loaded['lem.events'] then print('This script is intended to be imported to Lua Event Manager (LEM). Try "\a-t/lua run lem\a-t"') end

-- compare zone name to skip event if not in the correct zone
local required_zone = 'vexthaltwo_mission'

-- location to run to
local run_away_loc = {
    x=1222.67,
    y=-48.97,
    z=236.41,
}
-- delay before returning to the group (150 is ~15 seconds)
local return_delay = 150

local function run_away()
    local my_class = mq.TLO.Me.Class.ShortName()
    -- pause all the things
    mq.cmdf('/%s mode 0', my_class)
    mq.cmd('/mqp on')
    mq.cmd('/twist off')
    mq.cmd('/timed 5 /afollow off')
    mq.cmd('/nav stop')
    mq.cmd('/target clear')
    -- run away
    mq.cmdf('/timed 10 /nav locxyz %d %d %d', run_away_loc.x, run_away_loc.y, run_away_loc.z)
    -- resume all the things
    mq.cmdf('/timed %d /%s mode 2', return_delay, my_class)
    mq.cmd('/timed 150 /mqp off')
    mq.cmd('/timed 150 /twist on')
end

local function event_handler(line, target)
    if mq.TLO.Zone.ShortName() ~= required_zone then return end

    local i_am_ma = mq.TLO.Group.Member(0).MainAssist()
    local my_name = mq.TLO.Me.CleanName()
    local ma_name = mq.TLO.Group.MainAssist.CleanName()

    -- run away if i am targeted and i am not the MA, or if the MA is targeted and i am not the MA
    if (target == my_name and not i_am_ma) or (target == ma_name and not i_am_ma) then
        run_away()
    end
end

return {eventfunc=event_handler}