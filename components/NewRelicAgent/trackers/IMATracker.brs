'**********************************************************
' IMATracker.brs
' New Relic Google IMA Tracker Component.
'
' Copyright 2021 New Relic Inc. All Rights Reserved. 
'**********************************************************

sub init()
    print "********************************************************"
    print "   New Relic Google IMA Agent for Roku"
    print "   Copyright 2021 New Relic Inc. All Rights Reserved."
    print "********************************************************"
    
    'Init state
    m.adState = {}
    nrResetAdTimers()
    
    'Init main timer
    m.nrTimer = CreateObject("roTimespan")
    m.nrTimer.Mark()
end sub

'TODO:
' - Check out the initial PAUSE-RESUME events when an AD_BREAK starts

'=========================='
' Public Wrapped Functions '
'=========================='

function nrSendIMAAdBreakStart(adBreakInfo as Object) as Void
    m.top.nr.callFunc("nrSendVideoEvent", "AD_BREAK_START", nrIMAAttributes(adBreakInfo, invalid))
    m.adState.timeSinceAdBreakBegin = m.nrTimer.TotalMilliseconds()
end function

function nrSendIMAAdBreakEnd(adBreakInfo as Object) as Void
    attr = nrIMAAttributes(adBreakInfo, invalid)
    attr.AddReplace("timeSinceAdBreakBegin", m.nrTimer.TotalMilliseconds() - m.adState.timeSinceAdBreakBegin)
    m.top.nr.callFunc("nrSendVideoEvent", "AD_BREAK_END", attr)
end function

function nrSendIMAAdStart(ad as Object) as Void
    m.adState.numberOfAds = m.adState.numberOfAds + 1
    m.top.nr.callFunc("nrSendVideoEvent", "AD_START", nrIMAAttributes(ad.adBreakInfo, ad))
    m.adState.timeSinceAdStarted = m.nrTimer.TotalMilliseconds()
end function

function nrSendIMAAdEnd(ad as Object) as Void
    m.top.nr.callFunc("nrSendVideoEvent", "AD_END", nrIMAAttributes(ad.adBreakInfo, ad))
    m.adState.timeSinceAdStarted = 0
end function

function nrSendIMAAdQuartile(ad as Object, quartile as Integer) as Void
    attr = nrIMAAttributes(ad.adBreakInfo, ad)
    attr.AddReplace("adQuartile", quartile)
    m.top.nr.callFunc("nrSendVideoEvent", "AD_QUARTILE", nrIMAAttributes(ad.adBreakInfo, ad))
end function

'==================='
' Private Functions '
'==================='

'TODO: totalAdPlaytime
function nrIMAAttributes(adBreakInfo as Object, ad as Object) as Object
    attr = {}
    if adBreakInfo.podindex = 0 then attr.AddReplace("adPosition", "pre")
    if adBreakInfo.podindex > 0 then attr.AddReplace("adPosition", "mid")
    if adBreakInfo.podindex < 0 then attr.AddReplace("adPosition", "live")
    attr.AddReplace("contentPosition", adBreakInfo.timeoffset * 1000)
    
    if ad <> invalid
        attr.AddReplace("adDuration", ad.duration * 1000)
        attr.AddReplace("adId", ad.adid)
        attr.AddReplace("adTitle", ad.adtitle)
        attr.AddReplace("adSystem", ad.adsystem)
    end if
    
    if m.adState.timeSinceAdStarted <> 0
        attr.AddReplace("timeSinceAdStarted", m.nrTimer.TotalMilliseconds() - m.adState.timeSinceAdStarted)
    end if
    
    attr.AddReplace("numberOfAds", m.adState.numberOfAds)
    
    return attr
end function

function nrResetAdTimers() as Void
    m.adState.timeSinceAdBreakBegin = 0
    m.adState.timeSinceAdStarted = 0
    m.adState.numberOfAds = 0
end function
