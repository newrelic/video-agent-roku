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
'   videoNode    – the Video SceneGraph node that will play the stream
'   nr           – the New Relic Agent node (from NewRelic())
'   tracker      – a MediaTailorTracker node created in the scene thread
'   streamUrl    – either an explicit session-init URL (POST /v1/session/...)
'                  or an implicit-session "Playback URL" (GET /v1/master/...)
'
' Optional node fields:
'   streamType   – "VOD" (default) or "LIVE".
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
    ' 3. Session initialisation.
    '    Also required for LIVE: this is what creates adIface's
    '    internal loader (m.loader) - skipping it crashes enableAds()
    '    later with "Array operation attempted on variable not DIM'd".
    ' ---------------------------------------------------------------
    playUrl = m.top.streamUrl
    nrMTTaskLog("initial playUrl = " + playUrl)

    if Instr(1, m.top.streamUrl, "/v1/master/") > 0
        ' Implicit-session URL (the console "Playback URL"): AWS mints a
        ' brand-new MediaTailor session on every single GET to this URL.
        ' requestStream() below would resolve one session while the video
        ' player, fetching the same static URL itself, resolves a totally
        ' different one - so tracking would never match what's playing.
        ' Resolve the session ourselves exactly once, then hand the player
        ' that session-scoped manifest URL directly.
        session = nrMTResolveMediaTailorSession(m.top.streamUrl)
        if session <> invalid and session.manifestUrl <> ""
            playUrl = session.manifestUrl
            nrMTTaskLog("resolved MediaTailor session " + session.sessionId + " -> " + playUrl)
            adIface.setStreamInfo({tracking_url: session.trackingUrl, manifest_url: session.manifestUrl, type: adIface.StreamType.LIVE})
            nrMTTaskLog("tracking_url (best-effort, verify above) = " + session.trackingUrl)

            sidecar = {adTrackingUrl: session.trackingUrl}
            if m.nrMTTracker <> invalid
                nrSetMediaTailorAdMetadata(m.nrMTTracker, sidecar)
            end if
        else
            nrMTTaskLog("ERROR - could not resolve MediaTailor session from " + m.top.streamUrl + " - playing directly, no ad tracking")
            if m.nrMTTracker <> invalid
                errorCtx = {event: "Error", adErrorMsg: "could not resolve MediaTailor session", adErrorType: "session_init"}
                m.nrMTTracker.callFunc("nrTrackMediaTailorEvent", "Error", errorCtx)
            end if
        end if
    else if streamType = "VOD" or streamType = "LIVE"
        ' Explicit session-init URL (POST /v1/session/.../<manifestName>).
        nrMTTaskLog("requesting stream via RAFX_SSAI awsemt")

        ssaiStreamType = adIface.StreamType.VOD
        if streamType = "LIVE"
            ssaiStreamType = adIface.StreamType.LIVE
        end if

        streamRequest = {
            type: ssaiStreamType,
            url:  m.top.streamUrl,
            body: "{}"
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
    vidContent.live         = (streamType = "LIVE")

    m.top.videoNode.content = vidContent
    m.top.videoNode.visible = true
    m.top.videoNode.observeField("state", port)
    m.top.videoNode.observeField("position", port)

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
    if m.top.nr <> invalid and m.top.nr.callFunc("nrCheckLoggingState") = true
        print "MediaTailorTask: " + msg
    end if
end function

' Fetches a MediaTailor implicit-session URL (the console "Playback URL")
' exactly once, and extracts the session ID AWS mints for that specific
' request from the returned master playlist's variant paths, e.g.
'   ../../../manifest/<hash>/<config>/<sessionId>/0.m3u8
' Returns {sessionId, manifestUrl, trackingUrl} or invalid on failure.
' manifestUrl is the resolved, session-scoped media playlist - hand this
' to the player directly so it doesn't re-fetch the static URL itself
' (which would mint a different, untracked session).
' trackingUrl is a best-effort guess at AWS's convention (swap the
' "manifest" path segment for "tracking", same session ID) - verified
' with one extra GET, logged either way so this can be corrected later.
function nrMTResolveMediaTailorSession(masterUrl as String) as Object
    xfer = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    xfer.SetMessagePort(port)
    xfer.SetUrl(masterUrl)
    xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    xfer.InitClientCertificates()
    xfer.AddHeader("Accept", "application/vnd.apple.mpegurl, application/x-mpegURL, */*")
    xfer.AsyncGetToString()

    msg = wait(8000, port)
    if msg = invalid or type(msg) <> "roUrlEvent" or msg.GetResponseCode() <> 200
        return invalid
    end if

    variantPath = ""
    for each line in msg.GetString().Split(chr(10))
        trimmed = line.Trim()
        if trimmed <> "" and trimmed.Left(1) <> "#"
            variantPath = trimmed
            exit for
        end if
    end for
    if variantPath = "" then return invalid

    manifestUrl = nrMTResolveRelativeUrl(masterUrl, variantPath)
    pathSegments = manifestUrl.Split("/")
    if pathSegments.Count() < 2 then return invalid
    sessionId = pathSegments[pathSegments.Count() - 2]

    trackingSegments = []
    for i = 0 to pathSegments.Count() - 2
        seg = pathSegments[i]
        if seg = "manifest" then seg = "tracking"
        trackingSegments.push(seg)
    end for
    trackingUrl = trackingSegments.Join("/")

    nrMTTaskLog("[verify] GET " + trackingUrl)
    verifyXfer = CreateObject("roUrlTransfer")
    verifyPort = CreateObject("roMessagePort")
    verifyXfer.SetMessagePort(verifyPort)
    verifyXfer.SetUrl(trackingUrl)
    verifyXfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    verifyXfer.InitClientCertificates()
    verifyXfer.AddHeader("Accept", "application/json")
    verifyXfer.AsyncGetToString()
    verifyMsg = wait(8000, verifyPort)
    if verifyMsg = invalid or type(verifyMsg) <> "roUrlEvent"
        nrMTTaskLog("[verify] no response")
    else
        nrMTTaskLog("[verify] response code = " + verifyMsg.GetResponseCode().toStr() + " body head = " + Left(verifyMsg.GetString(), 300))
    end if

    return {sessionId: sessionId, manifestUrl: manifestUrl, trackingUrl: trackingUrl}
end function

' Resolves a relative HLS playlist path (e.g. "../../../manifest/a/b/0.m3u8")
' against the absolute URL it was found in, per standard "../" directory
' navigation. Query strings on baseUrl are dropped, not carried over.
function nrMTResolveRelativeUrl(baseUrl as String, relativePath as String) as String
    schemeSplit = baseUrl.Split("://")
    scheme = schemeSplit[0]
    rest = schemeSplit[1]

    qIdx = Instr(1, rest, "?")
    if qIdx > 0 then rest = rest.Left(qIdx - 1)

    restSegments = rest.Split("/")
    host = restSegments[0]

    dirSegments = []
    for i = 1 to restSegments.Count() - 2
        dirSegments.push(restSegments[i])
    end for

    for each seg in relativePath.Split("/")
        if seg = ".."
            if dirSegments.Count() > 0 then dirSegments.Delete(dirSegments.Count() - 1)
        else
            dirSegments.push(seg)
        end if
    end for

    return scheme + "://" + host + "/" + dirSegments.Join("/")
end function
