'**********************************************************
' MediaTailorTask.brs
' Background Task – AWS Elemental MediaTailor SSAI playback
' with New Relic VideoAdAction tracking.
'
' Uses the RAFX_SSAI "awsemt" adapter which:
'   • Handles the MediaTailor VOD session init (POST /v1/session/…)
'   • Parses EXT-X-DATERANGE ad break markers from the stitched HLS stream
'   • Fires standard RAF callbacks (PodStart, Start, Complete, …) so
'     nrTrackRAF can record VideoAdAction events in New Relic
'
' Required node fields (set before control = "RUN"):
'   videoNode  – the Video SceneGraph node that will play the stream
'   nr         – the New Relic Agent node (from NewRelic())
'   tracker    – a MediaTailorTracker node (from MediaTailorTracker())
'   streamUrl  – MediaTailor session-init URL
'                  VOD: POST /v1/session/<hash>/<config>/hls
'                  LIVE: master playlist URL (no session call needed)
'
' Optional node fields:
'   adsParams  – roAssociativeArray of ad-targeting key/value pairs
'   streamType – "VOD" (default) or "LIVE"
'   trackingUrl – pre-resolved tracking URL (skips requestStream round-trip)
'
' Copyright 2024 New Relic Inc. All Rights Reserved.
'**********************************************************

Library "Roku_Ads.brs"

sub init()
    m.top.functionName = "mediaTailorTaskMain"
end sub

function mediaTailorTaskMain() as Void
    nrMTTaskLog("main started")

    ' ---------------------------------------------------------------
    ' 1. Validate required fields
    ' ---------------------------------------------------------------
    if m.top.videoNode = invalid
        nrMTTaskLog("ERROR - videoNode not set")
        return
    end if
    if m.top.nr = invalid
        nrMTTaskLog("ERROR - nr (NRAgent) not set")
        return
    end if
    if m.top.tracker = invalid
        nrMTTaskLog("ERROR - tracker (MediaTailorTracker) not set")
        return
    end if
    if m.top.streamUrl = invalid or m.top.streamUrl = ""
        nrMTTaskLog("ERROR - streamUrl not set")
        return
    end if

    streamType = "VOD"
    if m.top.streamType <> invalid and m.top.streamType <> ""
        streamType = UCase(m.top.streamType)
    end if
    nrMTTaskLog("streamType = " + streamType)

    streamFormat = "hls"
    if m.top.streamFormat <> invalid and m.top.streamFormat <> ""
        streamFormat = LCase(m.top.streamFormat)
    end if
    nrMTTaskLog("streamFormat = " + streamFormat)

    ' ---------------------------------------------------------------
    ' 2. Initialise RAFX_SSAI with the awsemt (AWS Elemental MediaTailor)
    '    adapter and wire up the New Relic tracking callback.
    '
    '    setTrackingCallback fires for every RAF ad event (PodStart,
    '    Start, FirstQuartile, …, Complete, Close) AND for content
    '    position ticks (ContentPosition).  All are routed through
    '    nrTrackMediaTailorEvent → nrTrackRAF → nrSendRAFEvent which
    '    records VideoAdAction events in New Relic.
    ' ---------------------------------------------------------------
    nrMTTaskLog("initialising RAFX_SSAI awsemt adapter")
    adIface = RAFX_SSAI({name: "awsemt"})
    adIface.init()

    ' Store tracker in m so the named listener function can access it
    m.nrTracker = m.top.tracker

    adIface.addEventListener(adIface.AdEvent.POD_START,      nrMTAdListener)
    adIface.addEventListener(adIface.AdEvent.START,          nrMTAdListener)
    adIface.addEventListener(adIface.AdEvent.IMPRESSION,     nrMTAdListener)
    adIface.addEventListener(adIface.AdEvent.FIRST_QUARTILE, nrMTAdListener)
    adIface.addEventListener(adIface.AdEvent.MIDPOINT,       nrMTAdListener)
    adIface.addEventListener(adIface.AdEvent.THIRD_QUARTILE, nrMTAdListener)
    adIface.addEventListener(adIface.AdEvent.COMPLETE,       nrMTAdListener)
    adIface.addEventListener(adIface.AdEvent.POD_END,        nrMTAdListener)
    adIface.addEventListener(adIface.AdEvent.PAUSE,          nrMTAdListener)
    adIface.addEventListener(adIface.AdEvent.RESUME,         nrMTAdListener)
    adIface.addEventListener(adIface.AdEvent.ERROR,          nrMTAdListener)

    ' ---------------------------------------------------------------
    ' 3. Session initialisation via RAFX_SSAI requestStream()
    '
    '    For VOD: requestStream() POSTs to the MediaTailor session URL
    '    and returns { playURL, trackingUrl }.  This replaces the manual
    '    nrMTInitSession() call from the previous implementation.
    '
    '    For LIVE: skip requestStream – use streamUrl as playUrl directly.
    ' ---------------------------------------------------------------
    playUrl = m.top.streamUrl
    nrMTTaskLog("initial playUrl = " + playUrl)

    if streamType = "VOD"
        nrMTTaskLog("requesting stream via RAFX_SSAI awsemt")

        streamRequest = {
            type: adIface.StreamType.VOD,
            url:  m.top.streamUrl,
            body: "{}"    ' empty body forces POST (MediaTailor session init requires POST)
        }

        ' Inject ad-targeting params if provided – overrides empty body
        if type(m.top.adsParams) = "roAssociativeArray" and m.top.adsParams.Count() > 0
            streamRequest.body = formatjson({adsParams: m.top.adsParams})
        end if

        ' requestStream returns {} on success, {error:...} on failure
        result = adIface.requestStream(streamRequest)

        if result <> invalid and result.error = invalid
            ' Retrieve manifest URL and tracking URL from the adapter
            streamInfo = adIface.getStreamInfo()
            if streamInfo <> invalid and streamInfo.manifest_url <> invalid and streamInfo.manifest_url <> ""
                playUrl = streamInfo.manifest_url
                ' MediaTailor session URLs need rewriting to the actual playlist path:
                '   HLS:  /<config>/hls?aws.sessionId=…  →  /<config>/master.m3u8?aws.sessionId=…
                '   DASH: /<config>/dash?aws.sessionId=… →  /<config>/manifest.mpd?aws.sessionId=…
                if streamFormat = "dash"
                    playUrl = playUrl.replace("/dash?", "/manifest.mpd?")
                else
                    playUrl = playUrl.replace("/hls?", "/master.m3u8?")
                end if
                nrMTTaskLog("RAFX_SSAI manifest_url = " + playUrl)

                ' Push tracking URL as sidecar metadata so it appears on every AD_* event
                sidecar = {}
                if streamInfo.tracking_url <> invalid and streamInfo.tracking_url <> ""
                    sidecar.AddReplace("adTrackingUrl", streamInfo.tracking_url)
                end if
                if sidecar.Count() > 0
                    nrMTTaskLog("setting sidecar metadata")
                    nrSetMediaTailorAdMetadata(m.top.tracker, sidecar)
                end if
            else
                nrMTTaskLog("getStreamInfo returned no manifest_url - playing streamUrl directly")
            end if
        else
            errMsg = "RAFX_SSAI requestStream failed"
            if result <> invalid and result.error <> invalid
                errMsg = errMsg + " - " + formatjson(result.error)
            end if
            nrMTTaskLog(errMsg)
            ' Surface the session-init failure as an AD_ERROR so New Relic captures it
            errorCtx = {event: "Error", adErrorMsg: errMsg, adErrorType: "session_init"}
            m.nrTracker.callFunc("nrTrackMediaTailorEvent", "Error", errorCtx)
        end if
    end if

    ' ---------------------------------------------------------------
    ' 4. Load the stitched stream into the Video node
    ' ---------------------------------------------------------------
    port = CreateObject("roMessagePort")

    vidContent = createObject("RoSGNode", "ContentNode")
    vidContent.url          = playUrl
    vidContent.title        = "MediaTailor Stream"
    vidContent.streamformat = streamFormat

    m.top.videoNode.content = vidContent
    m.top.videoNode.visible = true
    m.top.videoNode.observeField("position", port)
    m.top.videoNode.observeField("state",    port)
    m.top.videoNode.control = "play"
    m.top.videoNode.setFocus(true)

    nrMTTaskLog("playback started - " + playUrl)

    ' ---------------------------------------------------------------
    ' 5. Enable ads via RAFX_SSAI
    '
    '    enableAds() activates the awsemt adapter so it can:
    '      • Parse EXT-X-DATERANGE ad break markers from the HLS stream
    '      • Fire client-side tracking beacons (Roku cert requirement)
    '      • Invoke the tracking callback with PodStart/Start/Complete/…
    ' ---------------------------------------------------------------
    adParams = {player: {sgnode: m.top.videoNode, port: port}}
    adIface.enableAds(adParams)

    ' ---------------------------------------------------------------
    ' 6. Event loop – forward every message to the RAFX_SSAI adapter
    ' ---------------------------------------------------------------
    while true
        msg = wait(1000, port)

        if msg = invalid
            ' 1-second tick – let the adapter fire internal tracking timers
            adIface.onMessage(invalid)
        else
            if type(msg) = "roSGNodeEvent"
                if msg.getField() = "state"
                    state = msg.getData()
                    nrMTTaskLog("video state changed to '" + state + "'")
                    if state = "finished" or state = "error"
                        nrMTTaskLog("video ended - state=" + state)
                        exit while
                    end if
                end if
            end if

            adIface.onMessage(msg)
        end if
    end while

    nrMTTaskLog("main finished")
end function

' Named callback for RAFX_SSAI addEventListener – called for every ad event.
' adInfo from RAFX_SSAI has the same structure as the ctx expected by
' nrTrackMediaTailorEvent: adInfo.event, adInfo.ad, adInfo.adPod, adInfo.position.
function nrMTAdListener(adInfo as Object) as Void
    if adInfo = invalid then return
    evtType = ""
    if adInfo.event <> invalid then evtType = adInfo.event
    nrMTTaskLog("ad event - " + evtType)
    m.nrTracker.callFunc("nrTrackMediaTailorEvent", evtType, adInfo)
end function

' Gate all debug output behind the NRAgent logging state.
' Only prints when the app has explicitly enabled NR logging via nrActivateLogging().
function nrMTTaskLog(msg as String) as Void
    if m.top.nr <> invalid and m.top.nr.callFunc("nrCheckLoggingState", {}) = true
        print "MediaTailorTask: " + msg
    end if
end function
