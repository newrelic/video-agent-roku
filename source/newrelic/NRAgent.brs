'**********************************************************
' NRAgent.brs
' New Relic Agent for Roku.
' Minimum requirements: FW 7.2
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
    
    m.global.addFields({"nrAccountNumber": account})
    m.global.addFields({"nrInsightsApiKey": apikey})
    m.global.addFields({"nrEventArray": []})
    
end function

'========================
' Video Agent functions '
'========================

function NewRelicVideoStart(videoObject as Object)
    print "Init NewRelicVideoAgent" 

    'Current state
    m.nrLastVideoState = "none"
    'Setup event listeners 
    videoObject.observeField("state", "__nrStateObserver")
    videoObject.observeField("contentIndex", "__nrIndexObserver")
    'videoObject.observeField("position", "__nrPositionObserver")
    'videoObject.notificationInterval = 1
    'Store video object
    m.nrVideoObject = videoObject
    'Player Ready
    nrSendPlayerReady()
    'Init event processor
    m.bgTask = createObject("roSGNode", "NRTask")
    m.bgTask.functionName = "nrTaskMain"
    m.bgTask.control = "RUN"

end function

'TODO: Consider Ad events

function nrSendPlayerReady() as Void
    ev = nrCreateEvent("PLAYER_READY")
    nrRecordEvent(ev)
end function

function nrSendRequest() as Void
    ev = nrCreateEvent("CONTENT_REQUEST")
    nrRecordEvent(ev)
end function

function nrSendStart() as Void
    ev = nrCreateEvent("CONTENT_START")
    nrRecordEvent(ev)
end function

function nrSendEnd() as Void
    ev = nrCreateEvent("CONTENT_END")
    nrRecordEvent(ev)
end function

function nrSendPause() as Void
    ev = nrCreateEvent("CONTENT_PAUSE")
    nrRecordEvent(ev)
end function

function nrSendResume() as Void
    ev = nrCreateEvent("CONTENT_RESUME")
    nrRecordEvent(ev)
end function

function nrSendBufferStart() as Void
    ev = nrCreateEvent("CONTENT_BUFFER_START")
    nrRecordEvent(ev)
end function

function nrSendBufferEnd() as Void
    ev = nrCreateEvent("CONTENT_BUFFER_END")
    nrRecordEvent(ev)
end function

'=====================
' Internal functions '
'=====================

function __nrStateObserver() as Void
    print "---------- State Observer ----------"
    printVideoInfo()

    if m.nrVideoObject.state = "playing"
        __nrStateTransitionPlaying()
    else if m.nrVideoObject.state = "paused"
        __nrStateTransitionPaused()
    end if
    
    m.nrLastVideoState = m.nrVideoObject.state

end function

function __nrStateTransitionPlaying() as Void
    if m.nrLastVideoState = "paused"
        nrSendResume()
    end if
end function

function __nrStateTransitionPaused() as Void
    if m.nrLastVideoState = "playing"
        nrSendPause()
    end if
end function

function __nrIndexObserver() as Void
    print "---------- Index Observer ----------"
    printVideoInfo()
end function

function __nrPositionObserver() as Void
    print "--------- Position Observer --------"
    printVideoInfo()
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
