'**********************************************************
' NRAgent.brs
' New Relic Agent for Roku.
' Minimum requirements: FW 8.1
'
' Copyright 2019 New Relic Inc. All Rights Reserved. 
'**********************************************************

'==========================
' General Agent functions '
'==========================

function NewRelicStart(account as String, apikey as String) as Void
    print "Init NewRelicAgent"
    
    m.nrAccountNumber = account
    m.nrInsightsApiKey = apikey
    m.nrSessionId = __nrGenerateId()
    
    m.global.addFields({"nrAccountNumber": account})
    m.global.addFields({"nrInsightsApiKey": apikey})
    m.global.addFields({"nrEventArray": []})
    m.global.addFields({"nrLastTimestamp": 0})
    m.global.addFields({"nrTicks": 0})
    m.global.addFields({"nrAgentVersion": "0.1.0"})
    
end function

'========================
' Video Agent functions '
'========================

function NewRelicVideoStart(videoObject as Object)
    print "Init NewRelicVideoAgent" 

    'Current state
    m.nrLastVideoState = "none"
    m.isAd = false
    'Setup event listeners 
    videoObject.observeField("state", "__nrStateObserver")
    videoObject.observeField("contentIndex", "__nrIndexObserver")
    'Store video object
    m.nrVideoObject = videoObject
    'Player Ready
    nrSendPlayerReady()
    'Init event processor
    m.bgTask = createObject("roSGNode", "NRTask")
    m.bgTask.functionName = "nrTaskMain"
    m.bgTask.control = "RUN"
    'Init heartbeat timer
    m.hbTimer = CreateObject("roSGNode", "Timer")
    m.hbTimer.repeat = true
    m.hbTimer.duration = 30
    m.hbTimer.observeField("fire", "__nrHeartbeatHandler")
    m.hbTimer.control = "start"
    
end function

function nrAction(action as String) as String
    if m.isAd = true
        return "AD_" + action
    else
        return "CONTENT_" + action
    end if
end function

function nrAttr(attribute as String) as String
    if m.isAd = true
        return "ad" + attribute
    else
        return "content" + attribute
    end if
end function

function nrSendPlayerReady() as Void
    ev = nrCreateEvent("PLAYER_READY")
    ev = __nrAddVideoAttributes(ev)
    nrRecordEvent(ev)
end function

function nrSendRequest() as Void
    __nrSendAction("REQUEST")
end function

function nrSendStart() as Void
    __nrSendAction("START")
end function

function nrSendEnd() as Void
    __nrSendAction("END")
end function

function nrSendPause() as Void
    __nrSendAction("PAUSE")
end function

function nrSendResume() as Void
    __nrSendAction("RESUME")
end function

function nrSendBufferStart() as Void
    __nrSendAction("BUFFER_START")
end function

function nrSendBufferEnd() as Void
    __nrSendAction("BUFFER_END")
end function

function nrCreateEvent(actionName as String) as Object
    ev = CreateObject("roAssociativeArray")
    ev["actionName"] = actionName
    timestamp& = CreateObject("roDateTime").asSeconds()
    timestampMS& = timestamp& * 1000
    
    if timestamp& = m.global.nrLastTimestamp
        m.global.nrTicks = m.global.nrTicks + 1
    else
        m.global.nrTicks = 0
    end if
    
    timestampMS& = timestampMS& + m.global.nrTicks
    
    ev["timestamp"] = timestampMS&
    m.global.nrLastTimestamp = timestamp&
    
    ev = __nrAddAttributes(ev)
    
    return ev
end function

'=====================
' Internal functions '
'=====================

function __nrSendAction(actionName as String) as Void
    ev = nrCreateEvent(nrAction(actionName))
    ev = __nrAddVideoAttributes(ev)
    nrRecordEvent(ev)
end function

function __nrStateObserver() as Void
    print "---------- State Observer ----------"
    printVideoInfo()

    if m.nrVideoObject.state = "playing"
        __nrStateTransitionPlaying()
    else if m.nrVideoObject.state = "paused"
        __nrStateTransitionPaused()
    else if m.nrVideoObject.state = "buffering"
        __nrStateTransitionBuffering()
    else if m.nrVideoObject.state = "finished"
        nrSendEnd()
    else if m.nrVideoObject.state = "stopped"
        nrSendEnd()
    else if m.nrVideoObject.state = "error"
        'TODO: send error action, get errorCode and errorMsg from video player object
    end if
    
    m.nrLastVideoState = m.nrVideoObject.state

end function

function __nrStateTransitionPlaying() as Void
    if m.nrLastVideoState = "paused"
        nrSendResume()
    else if m.nrLastVideoState = "buffering"
        nrSendBufferEnd()
        if m.nrVideoObject.position = 0
            nrSendStart()
        end if
    end if
end function

function __nrStateTransitionPaused() as Void
    if m.nrLastVideoState = "playing"
        nrSendPause()
    end if
end function

function __nrStateTransitionBuffering() as Void
    if m.nrLastVideoState = "none"
        nrSendRequest()
    end if
    nrSendBufferStart()
end function

function __nrIndexObserver() as Void
    print "---------- Index Observer ----------"
    printVideoInfo()
    
    __nrSendAction("NEXT")
    
end function

'TODO: implement "timeSince" attributes
'TODO: add videoId for each new video (using the sessionId?)

'TODO: some attributes are not going to change, we can create it only once and then add every time

function __nrAddVideoAttributes(ev as Object) as Object
    ev.AddReplace(nrAttr("Duration"), m.nrVideoObject.duration * 1000)
    ev.AddReplace(nrAttr("Playhead"), m.nrVideoObject.position * 1000)
    ev.AddReplace(nrAttr("IsMuted"), m.nrVideoObject.mute)
    if m.nrVideoObject.streamInfo <> invalid
        ev.AddReplace(nrAttr("Src"), m.nrVideoObject.streamInfo["streamUrl"])
        ev.AddReplace(nrAttr("Bitrate"), m.nrVideoObject.streamInfo["streamBitrate"])
        ev.AddReplace(nrAttr("MeasuredBitrate"), m.nrVideoObject.streamInfo["measuredBitrate"])
    end if
    if m.nrVideoObject.streamingSegment <> invalid
        ev.AddReplace(nrAttr("SegmentBitrate"), m.nrVideoObject.streamingSegment["segBitrateBps"])
    end if
    ev.AddReplace("playerName", "RokuVideoPlayer")
    ev.AddReplace("playerVersion", ev["osVersion"])
    return ev
end function

function __nrAddAttributes(ev as Object) as Object
    'TODO: add common attributes:
    '  appBuild, appId, appName, appVersion, device, newRelicVersion, osName, osVersion, sessionId
    'And other Roku related info.
    ev.AddReplace("newRelicAgent", "RokuAgent")
    ev.AddReplace("newRelicVersion", m.global.nrAgentVersion)
    ev.AddReplace("trackerName", "rokutracker")
    ev.AddReplace("trackerVersion", m.global.nrAgentVersion)
    ev.AddReplace("sessionId", m.nrSessionId)
    di = CreateObject("roDeviceInfo")
    ev.AddReplace("uuid", di.GetChannelClientId()) 'GetDeviceUniqueId is deprecated, so we use GetChannelClientId
    ev.AddReplace("device", di.GetModelDisplayName())
    ev.AddReplace("deviceGroup", "Roku")
    ev.AddReplace("deviceManufacturer", "Roku")
    ev.AddReplace("deviceModel", di.GetModel())
    ev.AddReplace("deviceType", di.GetModelType())
    ev.AddReplace("osName", "RokuOS")
    ev.AddReplace("osVersion", di.GetVersion())
    
    return ev
end function

function __nrHeartbeatHandler() as Void
    'Only send while it is playing (state is not "none" or "finished")
    if m.nrVideoObject.state <> "none" and m.nrVideoObject.state <> "finished"
        __nrSendAction("HEARTBEAT")
    end if
end function

function __nrGenerateId() as String
    timestamp = CreateObject("roDateTime").asSeconds()
    randStr = "ID" + Str(timestamp) + Str(Rnd(0) * 1000.0)
    ba = CreateObject("roByteArray")
    ba.FromAsciiString(randStr)
    digest = CreateObject("roEVPDigest")
    digest.Setup("md5")
    result = digest.Process(ba)
    return result
end function

function printVideoInfo() as Void
    print "===================================="
    print "Player state = " m.nrVideoObject.state
    print "Current position = " m.nrVideoObject.position
    print "Current duration = " m.nrVideoObject.duration
    print "Muted = " m.nrVideoObject.mute
    if m.nrVideoObject.streamInfo <> invalid
        print "Stream URL = " m.nrVideoObject.streamInfo["streamUrl"]
        print "Stream Bitrate = " m.nrVideoObject.streamInfo["streamBitrate"]
        print "Stream Measured Bitrate = " m.nrVideoObject.streamInfo["measuredBitrate"]
        print "Stream isResumed = " m.nrVideoObject.streamInfo["isResumed"]
        print "Stream isUnderrun = " m.nrVideoObject.streamInfo["isUnderrun"]
    end if
    if m.nrVideoObject.streamingSegment <> invalid
        print "Segment URL = " m.nrVideoObject.streamingSegment["segUrl"]
        print "Segment Bitrate = " m.nrVideoObject.streamingSegment["segBitrateBps"]
        print "Segment Sequence = " m.nrVideoObject.streamingSegment["segSequence"]
        print "Segment Start time = " m.nrVideoObject.streamingSegment["segStartTime"]
    end if
    print "Manifest data = " m.nrVideoObject.manifestData
    print "===================================="
end function
