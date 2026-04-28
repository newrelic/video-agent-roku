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
    m.adState = {}
    nrMTResetAdState()

    ' Master wall-clock timer – shared with the NRAgent timer epoch
    ' so relative times are comparable across events.
    m.nrTimer = CreateObject("roTimespan")
    m.nrTimer.Mark()

    ' Persistent bucket for MediaTailor-specific ad metadata.
    ' Populated from nrMTExtractAdMetadata() on every relevant event
    ' and also injectable via nrSetMediaTailorAdMetadata() for sidecar
    ' data that arrives before playback (e.g. ads_metadata response).
    m.customAdMetadata = {}
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
                "FirstQuartile", "Midpoint", "ThirdQuartile", "Complete", "Close", "Error"]
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
        m.adState.numberOfAds = m.adState.numberOfAds + 1
    end if

    ' 4. Clear ad-level metadata after AD_END / AD_SKIP so stale values
    '    from a previous ad are never carried into the next one.
    if evtType = "Complete" or evtType = "Close"
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

    ' --- Pod-level fields (available on PodStart / PodComplete) ---
    if evtType = "PodStart" or evtType = "PodComplete"
        if ctx.rendersequence <> invalid
            m.customAdMetadata.AddReplace("adRenderSequence", ctx.rendersequence)
        end if
        if ctx.duration <> invalid
            m.customAdMetadata.AddReplace("adBreakDurationMs", ctx.duration * 1000)
        end if
        ' awsemt adapter populates adPod info on the context
        if ctx.adPod <> invalid
            pod = ctx.adPod
            if pod.id <> invalid       then m.customAdMetadata.AddReplace("adPodId",       pod.id)
            if pod.origIndex <> invalid then m.customAdMetadata.AddReplace("adPodIndex",    pod.origIndex)
            if pod.type <> invalid     then m.customAdMetadata.AddReplace("adPodType",      pod.type)
        end if
    end if

    ' --- Ad-level fields (available on Impression / Start / Complete / quartiles) ---
    ad = invalid
    if ctx.ad <> invalid then ad = ctx.ad

    if ad <> invalid
        ' Standard RAF ad fields
        if ad.adid <> invalid      then m.customAdMetadata.AddReplace("adId",         ad.adid)
        if ad.adtitle <> invalid   then m.customAdMetadata.AddReplace("adTitle",      ad.adtitle)
        if ad.adsystem <> invalid  then m.customAdMetadata.AddReplace("adSystem",     ad.adsystem)
        if ad.duration <> invalid  then m.customAdMetadata.AddReplace("adDurationMs", ad.duration * 1000)
        if ad.creativeid <> invalid then m.customAdMetadata.AddReplace("creativeId",  ad.creativeid)

        ' MediaTailor / SSAI extension fields populated by the awsemt adapter
        if ad.advertiser <> invalid  then m.customAdMetadata.AddReplace("adAdvertiser",   ad.advertiser)
        if ad.campaignid <> invalid  then m.customAdMetadata.AddReplace("adCampaignId",   ad.campaignid)
        if ad.lineitemid <> invalid  then m.customAdMetadata.AddReplace("adLineItemId",   ad.lineitemid)
        if ad.vastadtaguri <> invalid then m.customAdMetadata.AddReplace("adVastTagUri",  ad.vastadtaguri)
        if ad.dealid <> invalid      then m.customAdMetadata.AddReplace("adDealId",       ad.dealid)

        ' Bitrate – awsemt may surface this directly on the ad object
        if ad.bitrate <> invalid then m.customAdMetadata.AddReplace("adBitrate", ad.bitrate)
    end if

    ' Tag the event as coming from the MediaTailor SSAI path
    m.customAdMetadata.AddReplace("adPartner", "mediatailor")
end function

' Push accumulated MediaTailor metadata into the NRAgent as a custom
' attribute list scoped to all action types (invalid = no filter).
' nrAddCustomAttributes() in NRAgent will merge these into the next event.
function nrMTFlushCustomAdAttributes() as Void
    if m.customAdMetadata.Count() = 0 then return
    m.top.nr.callFunc("nrSetCustomAttributeList", m.customAdMetadata, "")
end function

' Remove ad-level (not pod-level) keys after each individual ad ends,
' preventing stale creativeId / adTitle from leaking into the next ad.
function nrMTClearAdLevelMetadata() as Void
    adLevelKeys = ["adId", "adTitle", "adSystem", "adDurationMs", "creativeId",
                   "adAdvertiser", "adCampaignId", "adLineItemId", "adVastTagUri",
                   "adDealId", "adBitrate"]
    for each key in adLevelKeys
        m.customAdMetadata.Delete(key)
    end for
end function

function nrMTResetAdState() as Void
    m.adState.numberOfAds = 0
end function

' Gate all debug output behind the NRAgent logging state (nrActivateLogging / nrEnableLogging).
' Only prints when the app has explicitly enabled NR logging.
function nrMTLog(msg as String) as Void
    if m.top.nr <> invalid and m.top.nr.callFunc("nrCheckLoggingState", {}) = true
        print "MediaTailorTracker: " + msg
    end if
end function
