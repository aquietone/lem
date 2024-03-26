local mq = require('mq')

local function event_handler(line, target)
    if not mq.TLO.Zone.ShortName() == 'vexthaltwo_mission' then return end

    local my_class = mq.TLO.Me.Class.ShortName()
    local i_am_ma = mq.TLO.Group.Member(0).MainAssist()
    local my_name = mq.TLO.Me.CleanName()
    local ma_name = mq.TLO.Group.MainAssist.CleanName()

    if not i_am_ma and (target == my_name or target == ma_name) then
        if my_class == 'BER' and mq.TLO.Me.ActiveDisc.Name() == mq.TLO.Spell('Frenzied Resolve Discipline').RankName() then
            mq.cmd('/stopdisc')
        end
        mq.cmdf('/%s mode 0', my_class)
        mq.cmd('/mqp on')
        mq.cmd('/twist off')
        mq.cmd('/timed 5 /afollow off')
        mq.cmd('/nav stop')
        mq.cmd('/target clear')
        mq.delay(100)
        mq.cmd('/nav locxyz 1222.67 -48.97 236.41')
        mq.delay(15000)
        mq.cmdf('/%s mode 2', my_class)
        mq.cmd('/mqp off')
        mq.cmd('/twist on')
    end
end

return {eventfunc=event_handler}