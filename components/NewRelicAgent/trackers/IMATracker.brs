'**********************************************************
' IMATracker.brs
' New Relic Google IMA Tracker Component.
'
' Copyright 2021 New Relic Inc. All Rights Reserved. 
'**********************************************************

sub init()
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
    timeSinceAdBreakBegin = m.nrTimer.TotalMilliseconds() - m.adState.timeSinceAdBreakBegin
    m.top.nr.callFunc("nrAddToTotalAdPlaytime", timeSinceAdBreakBegin)
    attr.AddReplace("timeSinceAdBreakBegin", timeSinceAdBreakBegin)
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

function nrSendIMAAdFirstQuartile(ad as Object) as Void
    nrSendIMAAdQuartile(ad, 1)
end function

function nrSendIMAAdMidpoint(ad as Object) as Void
    nrSendIMAAdQuartile(ad, 2)
end function

function nrSendIMAAdThirdQuartile(ad as Object) as Void
    nrSendIMAAdQuartile(ad, 3)
end function

function nrSendIMAAdError(error as Object) as Void
    attr = nrIMAGenericAttributes({})
    if error.id <> invalid then attr.AddReplace("adErrorCode", error.id)
    if error.info <> invalid then attr.AddReplace("adErrorMsg", error.info)
    if error.type <> invalid then attr.AddReplace("adErrorType", error.type)
    m.top.nr.callFunc("nrSendVideoEvent", "AD_ERROR", attr)
end function

'==================='
' Private Functions '
'==================='

function nrSendIMAAdQuartile(ad as Object, quartile as Integer) as Void
    attr = nrIMAAttributes(ad.adBreakInfo, ad)
    attr.AddReplace("adQuartile", quartile)
    m.top.nr.callFunc("nrSendVideoEvent", "AD_QUARTILE", attr)
end function

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
    
    attr = nrIMAGenericAttributes(attr)
    
    return attr
end function

function nrIMAGenericAttributes(attr as Object) as Object
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
