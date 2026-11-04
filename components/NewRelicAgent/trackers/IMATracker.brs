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
    'A previous break that never ended (stalled ads) must not leak into this one
    nrCloseStaleBreak()
    m.adState.timeSinceAdStarted = 0
    m.top.nr.callFunc("nrSendVideoAdEvent", "AD_BREAK_START", nrIMAAttributes(adBreakInfo, invalid))
    m.adState.timeSinceAdBreakBegin = m.nrTimer.TotalMilliseconds()
    m.adState.openBreak = adBreakInfo
end function

function nrSendIMAAdBreakEnd(adBreakInfo as Object) as Void
    'The break was already closed as stale, this is its late end
    if m.adState.openBreak = invalid then return
    attr = nrIMAAttributes(adBreakInfo, invalid)
    timeSinceAdBreakBegin = m.nrTimer.TotalMilliseconds() - m.adState.timeSinceAdBreakBegin
    m.top.nr.callFunc("nrAddToTotalAdPlaytime", timeSinceAdBreakBegin)
    attr.AddReplace("timeSinceAdBreakBegin", timeSinceAdBreakBegin)
    m.top.nr.callFunc("nrSendVideoAdEvent", "AD_BREAK_END", attr)
    m.adState.timeSinceAdBreakBegin = 0
    m.adState.openBreak = invalid
    m.adState.openAd = invalid
end function

function nrSendIMAAdStart(ad as Object) as Void
    m.adState.numberOfAds = m.adState.numberOfAds + 1
    m.top.nr.callFunc("nrSendVideoAdEvent", "AD_START", nrIMAAttributes(ad.adBreakInfo, ad))
    m.adState.timeSinceAdStarted = m.nrTimer.TotalMilliseconds()
    m.adState.openAd = ad
end function

function nrSendIMAAdEnd(ad as Object) as Void
    m.top.nr.callFunc("nrSendVideoAdEvent", "AD_END", nrIMAAttributes(ad.adBreakInfo, ad))
    m.adState.timeSinceAdStarted = 0
    m.adState.openAd = invalid
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
    m.top.nr.callFunc("nrSendVideoAdEvent", "AD_ERROR", attr)
end function

'==================='
' Private Functions '
'==================='

'Close the ad and break left open by a stalled ad. Its stalled time is not ad playtime.
function nrCloseStaleBreak() as Void
    if m.adState.openBreak = invalid then return
    if m.adState.openAd <> invalid
        nrSendIMAAdEnd(m.adState.openAd)
    end if
    attr = nrIMAAttributes(m.adState.openBreak, invalid)
    attr.AddReplace("timeSinceAdBreakBegin", m.nrTimer.TotalMilliseconds() - m.adState.timeSinceAdBreakBegin)
    m.top.nr.callFunc("nrSendVideoAdEvent", "AD_BREAK_END", attr)
    m.adState.timeSinceAdBreakBegin = 0
    m.adState.openBreak = invalid
end function

function nrSendIMAAdQuartile(ad as Object, quartile as Integer) as Void
    attr = nrIMAAttributes(ad.adBreakInfo, ad)
    attr.AddReplace("adQuartile", quartile)
    m.top.nr.callFunc("nrSendVideoAdEvent", "AD_QUARTILE", attr)
end function

'TODO: totalAdPlaytime
function nrIMAAttributes(adBreakInfo as Object, ad as Object) as Object
    attr = {}
    'Live breaks have no fixed place in the content. The VOD post-roll is reported with pod index -1
    if m.top.nr.callFunc("nrIsLiveContent")
        attr.AddReplace("adPosition", "live")
    else if adBreakInfo.podindex = 0
        attr.AddReplace("adPosition", "pre")
    else if adBreakInfo.podindex > 0
        attr.AddReplace("adPosition", "mid")
    else
        attr.AddReplace("adPosition", "post")
    end if
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
    
    if m.adState.timeSinceAdBreakBegin <> 0
        timeInBreak = m.nrTimer.TotalMilliseconds() - m.adState.timeSinceAdBreakBegin
        attr.AddReplace("timeSinceAdBreakBegin", timeInBreak)
        'Ads are stitched into the stream, there is no separate request: the break start is the request
        attr.AddReplace("timeSinceAdRequested", timeInBreak)
    end if
    attr.AddReplace("numberOfAds", m.adState.numberOfAds)
    attr.AddReplace("adPartner", "ima")
    'DAI ads are stitched into the content stream, so the stream URL is the ad source
    streamUrl = m.top.nr.callFunc("nrGenerateStreamUrl")
    if streamUrl <> invalid and streamUrl <> "" then attr.AddReplace("adSrc", streamUrl)
    return attr
end function

function nrResetAdTimers() as Void
    m.adState.timeSinceAdBreakBegin = 0
    m.adState.timeSinceAdStarted = 0
    m.adState.numberOfAds = 0
    m.adState.openBreak = invalid
    m.adState.openAd = invalid
end function
