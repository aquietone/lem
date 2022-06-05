local mq = require('mq')

local my_class = mq.TLO.Me.Class.ShortName()

local pause_cmds = ('/%s mode 0; /mqp on; /twist off; /timed 5 /afollow off; /nav stop; /target clear'):format(my_class)
local run_away_cmd = '/timed 10 /nav locxyz 1222.67 -48.97 236.41'
local resume_cmds = ('/timed 150 /%s mode 2; /timed 150 /mqp off; /timed 150 /twist on'):format(my_class)

local full_cmd = ('/multiline ; %s; %s; %s;'):format(pause_cmds, run_away_cmd, resume_cmds)

local function on_load()
    -- Initialize anything here when the event loads
end

local function event_handler(line, target)
    if not mq.TLO.Zone.ShortName() == 'vexthaltwo_mission' then return end

    local i_am_ma = mq.TLO.Group.Member(0).MainAssist()
    local my_name = mq.TLO.Me.CleanName()
    local ma_name = mq.TLO.Group.MainAssist.CleanName()

    if target == my_name and not i_am_ma then
        mq.cmd(full_cmd)
    elseif target == ma_name and not i_am_ma then
        mq.cmd(full_cmd)
    end
end

return {onload=on_load, eventfunc=event_handler}