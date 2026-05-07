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
'   streamUrl  – MediaTailor session-init URL (POST target)
'                  VOD HLS: /v1/session/<hash>/<config>/hls
'                Both the session-init POST body carries
'                {"adSignaling":{"enabled":true}} so MediaTailor emits
'                the HLS DATERANGE / DASH EventStream markers that the
'                rafxssai awsemt adapter needs.
'
' Optional node fields:
'   adsParams  – roAssociativeArray of ad-targeting key/value pairs
'   streamType – "VOD" (default). LIVE is reserved for future use.
'   streamFormat – "hls" (default).
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
    ' 2. Initialise RAFX_SSAI and enable New Relic MediaTailor tracking.
    '    One call registers NR listeners on every ad lifecycle event
    '    (POD_START, IMPRESSION, quartiles, COMPLETE, POD_END, ERROR)
    '    and stashes the tracker node as m.nrMTTracker for sidecar /
    '    error use.
    ' ---------------------------------------------------------------
    nrMTTaskLog("initialising RAFX_SSAI awsemt adapter")
    adIface = RAFX_SSAI({name: "awsemt"})
    adIface.init()
    nrEnableMediaTailorTracking(m.top.nr, adIface)

    ' ---------------------------------------------------------------
    ' 3. Session initialisation via RAFX_SSAI requestStream() for VOD.
    '    Returns { manifest_url, tracking_url } on success.
    ' ---------------------------------------------------------------
    playUrl = m.top.streamUrl
    nrMTTaskLog("initial playUrl = " + playUrl)

    if streamType = "VOD"
        nrMTTaskLog("requesting stream via RAFX_SSAI awsemt")

        ' adSignaling.enabled is required for MediaTailor to emit the
        ' HLS DATERANGE / DASH EventStream markers that rafxssai parses.
        ' Without it, ads stitch into the stream but no ad events fire.
        '
        ' BrightScript associative arrays are case-INSENSITIVE by default,
        ' and formatjson lowercases keys. MediaTailor's API is case-sensitive
        ' and expects "adSignaling" (camelCase). Use setModeCaseSensitive()
        ' so the key casing survives JSON serialisation.
        sessionBody = {}
        sessionBody.setModeCaseSensitive()
        adSignalingObj = {}
        adSignalingObj.setModeCaseSensitive()
        adSignalingObj.enabled = true
        sessionBody["adSignaling"] = adSignalingObj
        if type(m.top.adsParams) = "roAssociativeArray" and m.top.adsParams.Count() > 0
            sessionBody["adsParams"] = m.top.adsParams
        end if

        streamRequest = {
            type: adIface.StreamType.VOD,
            url:  m.top.streamUrl,
            body: formatjson(sessionBody)
        }

        ' requestStream returns {} on success, {error:...} on failure
        result = adIface.requestStream(streamRequest)

        if result <> invalid and result.error = invalid
            ' Retrieve manifest URL and tracking URL from the adapter
            streamInfo = adIface.getStreamInfo()
            if streamInfo <> invalid and streamInfo.manifest_url <> invalid and streamInfo.manifest_url <> ""
                playUrl = streamInfo.manifest_url
                nrMTTaskLog("RAFX_SSAI manifest_url = " + playUrl)

                ' Push tracking URL as sidecar metadata so it appears on every AD_* event
                sidecar = {}
                if streamInfo.tracking_url <> invalid and streamInfo.tracking_url <> ""
                    sidecar.AddReplace("adTrackingUrl", streamInfo.tracking_url)
                end if
                if sidecar.Count() > 0 and m.nrMTTracker <> invalid
                    nrMTTaskLog("setting sidecar metadata")
                    nrSetMediaTailorAdMetadata(m.nrMTTracker, sidecar)
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
            if m.nrMTTracker <> invalid
                errorCtx = {event: "Error", adErrorMsg: errMsg, adErrorType: "session_init"}
                m.nrMTTracker.callFunc("nrTrackMediaTailorEvent", "Error", errorCtx)
            end if
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
    m.top.videoNode.observeField("state", port)

    ' ---------------------------------------------------------------
    ' 5. Enable ads via RAFX_SSAI (must be called BEFORE play so the
    '    adapter is ready to intercept the very first ad break).
    ' ---------------------------------------------------------------
    adParams = {player: {sgnode: m.top.videoNode, port: port}}
    adIface.enableAds(adParams)

    m.top.videoNode.control = "play"
    m.top.videoNode.setFocus(true)

    nrMTTaskLog("playback started - " + playUrl)

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

function nrMTTaskLog(msg as String) as Void
    if m.top.nr <> invalid and m.top.nr.callFunc("nrCheckLoggingState", {}) = true
        print "MediaTailorTask: " + msg
    end if
end function
