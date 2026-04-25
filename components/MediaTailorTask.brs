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
    print "MediaTailorTask: init"
    m.top.functionName = "mediaTailorTaskMain"
end sub

function mediaTailorTaskMain() as Void
    print "MediaTailorTask: main started"

    ' ---------------------------------------------------------------
    ' 1. Validate required fields
    ' ---------------------------------------------------------------
    if m.top.videoNode = invalid
        print "MediaTailorTask: ERROR – videoNode not set"
        return
    end if
    if m.top.nr = invalid
        print "MediaTailorTask: ERROR – nr (NRAgent) not set"
        return
    end if
    if m.top.tracker = invalid
        print "MediaTailorTask: ERROR – tracker (MediaTailorTracker) not set"
        return
    end if
    if m.top.streamUrl = invalid or m.top.streamUrl = ""
        print "MediaTailorTask: ERROR – streamUrl not set"
        return
    end if

    streamType = "VOD"
    if m.top.streamType <> invalid and m.top.streamType <> ""
        streamType = UCase(m.top.streamType)
    end if
    print "MediaTailorTask: streamType = "; streamType

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
    print "MediaTailorTask: initialising RAFX_SSAI awsemt adapter"
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
    print "MediaTailorTask: initial playUrl = "; playUrl

    if streamType = "VOD"
        print "MediaTailorTask: requesting stream via RAFX_SSAI awsemt"

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
                ' MediaTailor returns manifestUrl ending in /<config>/hls?aws.sessionId=...
                ' The Roku player needs /<config>/master.m3u8?aws.sessionId=... to get the HLS master playlist
                playUrl = playUrl.replace("/hls?", "/master.m3u8?")
                print "MediaTailorTask: RAFX_SSAI manifest_url = "; playUrl

                ' Push tracking URL as sidecar metadata so it appears on every AD_* event
                sidecar = {}
                if streamInfo.tracking_url <> invalid and streamInfo.tracking_url <> ""
                    sidecar.AddReplace("adTrackingUrl", streamInfo.tracking_url)
                end if
                if sidecar.Count() > 0
                    print "MediaTailorTask: setting sidecar metadata"
                    nrSetMediaTailorAdMetadata(m.top.tracker, sidecar)
                end if
            else
                print "MediaTailorTask: getStreamInfo returned no manifest_url – playing streamUrl directly"
            end if
        else
            print "MediaTailorTask: RAFX_SSAI requestStream failed – "; formatjson(result)
        end if
    end if

    ' ---------------------------------------------------------------
    ' 4. Load the stitched HLS stream into the Video node
    ' ---------------------------------------------------------------
    port = CreateObject("roMessagePort")

    vidContent = createObject("RoSGNode", "ContentNode")
    vidContent.url          = playUrl
    vidContent.title        = "MediaTailor Stream"
    vidContent.streamformat = "hls"

    m.top.videoNode.content = vidContent
    m.top.videoNode.visible = true
    m.top.videoNode.observeField("position", port)
    m.top.videoNode.observeField("state",    port)
    m.top.videoNode.control = "play"
    m.top.videoNode.setFocus(true)

    print "MediaTailorTask: playback started – "; playUrl

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
                    print "MediaTailorTask: video state changed to '"; state; "'"
                    if state = "finished" or state = "error"
                        print "MediaTailorTask: video ended – state="; state
                        exit while
                    end if
                end if
            end if

            adIface.onMessage(msg)
        end if
    end while

    print "MediaTailorTask: main finished"
end function

' Named callback for RAFX_SSAI addEventListener – called for every ad event.
' adInfo from RAFX_SSAI has the same structure as the ctx expected by
' nrTrackMediaTailorEvent: adInfo.event, adInfo.ad, adInfo.adPod, adInfo.position.
function nrMTAdListener(adInfo as Object) as Void
    if adInfo = invalid then return
    evtType = ""
    if adInfo.event <> invalid then evtType = adInfo.event
    print "MediaTailorTask: ad event – "; evtType
    m.nrTracker.callFunc("nrTrackMediaTailorEvent", evtType, adInfo)
end function
