
'Public Functions

function nrSendIMAAdBreakStart(adBreakInfo as Object) as Void
    m.top.nr.callFunc("nrSendVideoEvent", "AD_BREAK_START", nrIMAAttributes(adBreakInfo, invalid))
end function

function nrSendIMAAdBreakEnd(adBreakInfo as Object) as Void
    m.top.nr.callFunc("nrSendVideoEvent", "AD_BREAK_END", nrIMAAttributes(adBreakInfo, invalid))
end function

function nrSendIMAAdStart(ad as Object) as Void
    m.top.nr.callFunc("nrSendVideoEvent", "AD_START", nrIMAAttributes(ad.adBreakInfo, ad))
end function

function nrSendIMAAdEnd(ad as Object) as Void
    m.top.nr.callFunc("nrSendVideoEvent", "AD_END", nrIMAAttributes(ad.adBreakInfo, ad))
end function

function nrSendIMAAdQuartile(ad as Object, quartile as Integer) as Void
    attr = nrIMAAttributes(ad.adBreakInfo, ad)
    attr.AddReplace("adQuartile", quartile)
    m.top.nr.callFunc("nrSendVideoEvent", "AD_QUARTILE", nrIMAAttributes(ad.adBreakInfo, ad))
end function

'Private Functions

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
    return attr
end function