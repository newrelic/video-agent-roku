'**********************************************************
' MediaTailorTracker.brs
' New Relic AWS Elemental MediaTailor SSAI Tracker Component.
'
' Integrates with the RAFX_SSAI "awsemt" adapter and maps all
' RAF ad events to the VideoAdAction data model via nrTrackRAF.
' Custom ad attributes extracted from the SSAI context (e.g.
' adTitle, creativeId, campaignId) are automatically appended
' to every AD_* event through the NRAgent custom-attribute store.
'
' Copyright 2024 New Relic Inc. All Rights Reserved.
'**********************************************************

sub init()
    ' Persistent bucket for MediaTailor-specific ad metadata.
    ' Populated from nrMTExtractAdMetadata() on every relevant event
    ' and also injectable via nrSetMediaTailorAdMetadata() for sidecar
    ' data that arrives before playback (e.g. ads_metadata response).
    m.customAdMetadata = {}
    ' The awsemt adapter only hands the ad pod to PodStart, ad events carry no ad: keep the pod
    ' and follow its ads in order (one per Impression)
    m.pod = invalid
    m.adIndex = -1
end sub

'==========================
' Public Callable Functions
'==========================

' Primary entry point – called from the MediaTailorTask tracking callback
' for every RAF event the SSAI adapter fires.
'
' Flow:
'   1. Extract any MediaTailor-specific metadata from ctx into m.customAdMetadata
'   2. Push that metadata into the NRAgent custom-attribute store so it is
'      included in the event that nrTrackRAF is about to record.
'   3. Delegate to nrTrackRAF on the NRAgent node, which handles all the
'      standard VideoAdAction event creation (AD_START, AD_QUARTILE, etc.)
'
' @param evtType  RAF event-type string ("PodStart", "Start", "Complete", …)
' @param ctx      RAF context AA for this event (may contain ctx.ad, ctx.rendersequence, …)
function nrTrackMediaTailorEvent(evtType as String, ctx as Object) as Void
    nrMTLog("nrTrackMediaTailorEvent, evtType = " + evtType)

    ' Ad-related RAF event types that warrant metadata enrichment
    adEvents = ["PodStart", "PodComplete", "Impression", "Start",
                "FirstQuartile", "Midpoint", "ThirdQuartile", "Complete", "Close", "Error",
                "Pause", "Resume"]
    isAdEvent = false
    for each e in adEvents
        if evtType = e then isAdEvent = true
    end for

    if isAdEvent
        ' 1. Extract MediaTailor-specific fields from the SSAI context
        nrMTExtractAdMetadata(evtType, ctx)

        ' 2. Flush accumulated metadata into the NRAgent so the imminent
        '    VideoAdAction event picks them up via nrAddCustomAttributes()
        nrMTFlushCustomAdAttributes()
    end if

    ' 3. Hand off to the standard RAF event handler in NRAgent
    m.top.nr.callFunc("nrTrackRAF", evtType, ctx)

    ' awsemt maps both MediaTailor "start" and "impression" to AdEvent.IMPRESSION,
    ' so "Start" is never fired separately. Synthesize AD_START after AD_REQUEST.
    if evtType = "Impression"
        m.top.nr.callFunc("nrTrackRAF", "Start", ctx)
    end if

    if evtType = "Complete" or evtType = "Close" or evtType = "PodComplete"
        nrMTLog("clearing ad-level metadata")
        nrMTClearAdLevelMetadata()
    end if
end function

' Inject metadata from the ads_metadata sidecar response *before* the first
' ad plays. Keys set here persist across the entire ad break and are appended
' to every AD_* event until explicitly cleared.
'
' Typical sidecar fields: avail_id, origin_id, custom targeting KVPs.
'
' @param metadata  roAssociativeArray of key→value pairs from the sidecar URL
function nrSetMediaTailorAdMetadata(metadata as Object) as Void
    nrMTLog("nrSetMediaTailorAdMetadata")
    if type(metadata) = "roAssociativeArray"
        m.customAdMetadata.Append(metadata)
    end if
end function

'===================
' Private Functions
'===================

' Extract MediaTailor / SSAI-specific fields from the RAF ctx object and
' accumulate them in m.customAdMetadata.  Called before every nrTrackRAF
' delegation so the NRAgent event always gets the freshest values.
function nrMTExtractAdMetadata(evtType as String, ctx as Object) as Void
    if ctx = invalid then return

    ' --- Pod-level fields (the pod arrives with PodStart) ---
    if evtType = "PodStart" and type(ctx.adPod) = "roAssociativeArray"
        m.pod = ctx.adPod
        m.adIndex = -1
    end if
    pod = m.pod
    if pod = invalid then pod = {}
    if evtType = "PodStart" or evtType = "PodComplete"
        renderSequence = pod.rendersequence
        if renderSequence = invalid then renderSequence = ctx.rendersequence
        if renderSequence <> invalid
            m.customAdMetadata.AddReplace("adRenderSequence", renderSequence)
            ' Ad-level contexts carry no position, keep the break position for the ads in it
            if renderSequence = "preroll" then m.customAdMetadata.AddReplace("adPosition", "pre")
            if renderSequence = "midroll" then m.customAdMetadata.AddReplace("adPosition", "mid")
            if renderSequence = "postroll" then m.customAdMetadata.AddReplace("adPosition", "post")
        end if
        if pod.duration <> invalid
            m.customAdMetadata.AddReplace("adBreakDurationMs", pod.duration * 1000)
        end if
        if pod.id <> invalid then m.customAdMetadata.AddReplace("adPodId", pod.id)
        if pod.origIndex <> invalid then m.customAdMetadata.AddReplace("adPodIndex", pod.origIndex)
        if pod.type <> invalid then m.customAdMetadata.AddReplace("adPodType", pod.type)
    end if

    ' --- Ad-level fields (available on Impression / Start / Complete / quartiles) ---
    if evtType = "Impression" then m.adIndex = m.adIndex + 1
    ad = ctx.ad
    if ad = invalid and type(pod.ads) = "roArray" and m.adIndex >= 0 and m.adIndex < pod.ads.Count()
        ad = pod.ads[m.adIndex]
    end if

    if ad <> invalid
        ' The awsemt adapter keeps the full MediaTailor tracking ad (adTitle, adSystem, ...) in ad.nativeAd
        native = ad.nativeAd
        if type(native) <> "roAssociativeArray" then native = {}

        adId = ad.adid
        if adId = invalid then adId = native.adId
        adTitle = ad.adtitle
        if adTitle = invalid then adTitle = native.adTitle
        adSystem = ad.adsystem
        if adSystem = invalid then adSystem = native.adSystem
        creativeId = ad.creativeid
        if creativeId = invalid then creativeId = native.creativeId
        duration = ad.duration
        if duration = invalid or duration = 0 then duration = native.durationInSeconds
        if adId <> invalid         then m.customAdMetadata.AddReplace("adId",         adId)
        if adTitle <> invalid      then m.customAdMetadata.AddReplace("adTitle",      adTitle)
        if adSystem <> invalid     then m.customAdMetadata.AddReplace("adSystem",     adSystem)
        if creativeId <> invalid   then m.customAdMetadata.AddReplace("creativeId",   creativeId)
        if duration <> invalid
            m.customAdMetadata.AddReplace("adDuration",   duration * 1000)
            m.customAdMetadata.AddReplace("adDurationMs", duration * 1000)
        end if

        ' MediaTailor / SSAI extension fields populated by the awsemt adapter
        if ad.advertiser <> invalid  then m.customAdMetadata.AddReplace("adAdvertiser",   ad.advertiser)
        if ad.campaignid <> invalid  then m.customAdMetadata.AddReplace("adCampaignId",   ad.campaignid)
        if ad.lineitemid <> invalid  then m.customAdMetadata.AddReplace("adLineItemId",   ad.lineitemid)
        if ad.vastadtaguri <> invalid then m.customAdMetadata.AddReplace("adVastTagUri",  ad.vastadtaguri)
        if ad.dealid <> invalid      then m.customAdMetadata.AddReplace("adDealId",       ad.dealid)

        ' Bitrate – awsemt may surface this directly on the ad object
        if ad.bitrate <> invalid then m.customAdMetadata.AddReplace("adBitrate", ad.bitrate)
    end if

    ' Error ctx from the task uses adError*; nrTrackRAF reads errMsg / errType
    if evtType = "Error"
        if ctx.errMsg = invalid then ctx.errMsg = ctx.adErrorMsg
        if ctx.errType = invalid then ctx.errType = ctx.adErrorType
    end if

    ' SSAI ads are stitched into the content stream, so the stream URL is the ad source
    if ctx.server = invalid
        streamUrl = m.top.nr.callFunc("nrGenerateStreamUrl")
        if streamUrl <> invalid and streamUrl <> "" then m.customAdMetadata.AddReplace("adSrc", streamUrl)
    end if

    ' Tag the event as coming from the MediaTailor SSAI path
    m.customAdMetadata.AddReplace("adPartner", "mediatailor")
end function

' Push accumulated MediaTailor metadata into the NRAgent as a custom
' attribute list scoped to VideoAdAction events only.
' nrAddCustomAttributes() in NRAgent will merge these into the next ad event.
function nrMTFlushCustomAdAttributes() as Void
    if m.customAdMetadata.Count() = 0 then return
    m.top.nr.callFunc("nrSetCustomAttributeList", m.customAdMetadata, "VIDEO_AD_ATTR")
end function

' Remove ad-level (not pod-level) keys after each individual ad ends,
' preventing stale creativeId / adTitle from leaking into the next ad.
function nrMTClearAdLevelMetadata() as Void
    adLevelKeys = ["adId", "adTitle", "adSystem", "adDuration", "adDurationMs", "creativeId",
                   "adAdvertiser", "adCampaignId", "adLineItemId", "adVastTagUri",
                   "adDealId", "adBitrate"]
    for each key in adLevelKeys
        m.customAdMetadata.Delete(key)
    end for
    m.top.nr.callFunc("nrDeleteCustomAttributes", adLevelKeys, "VIDEO_AD_ATTR")
end function

' Gate all debug output behind the NRAgent logging state (nrActivateLogging / nrEnableLogging).
' Only prints when the app has explicitly enabled NR logging.
function nrMTLog(msg as String) as Void
    if m.top.nr <> invalid and m.top.nr.callFunc("nrCheckLoggingState") = true
        print "MediaTailorTracker: " + msg
    end if
end function
