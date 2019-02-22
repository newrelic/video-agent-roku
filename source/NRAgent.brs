'**********************************************************
' NRAgent.brs
' New Relic Video Agent for Roku.
' Minimum requirements: FW 7.2
'
' Copyright 2019 New Relic Inc. All Rights Reserved. 
'**********************************************************

function NewRelicVideoStart(videoObject as Object)
    print "Init NewRelicVideoAgent" 
    
    'Init list of events
    m.nrVideoEventList = CreateObject("roList")
    'Current state
    m.nrLastVideoState = "none"
    'Setup event listeners 
    videoObject.observeField("state", "__nrStateObserver__")
    videoObject.observeField("contentIndex", "__nrIndexObserver__")
    'videoObject.observeField("position", "__nrPositionObserver__")
    'videoObject.notificationInterval = 1
    'Store video object
    m.nrVideoObject = videoObject
    'Player Ready
    nrSendPlayerReady()
end function

'Record an event to the list. Takes an roAssociativeArray as argument 
function nrRecordVideoEvent(event as Object) as Void
    if m.nrVideoEventList.Count() < 500 
        m.nrVideoEventList.AddTail(event)
    end if
    
    print "List of Event = " m.nrVideoEventList
     
end function

'Extracts the first event from the list. Returns an roAssociativeArray as argument
function nrExtractEvent() as Object
    return m.nrVideoEventList.RemoveHead()
end function

function nrCreateVideoEvent(actionName as String) as Object
    ev = CreateObject("roAssociativeArray")
    ev["actionName"] = actionName
    'TODO: add timestamp and other very basic attributes
    
    print "Create Event = " ev
    
    return ev
end function

'TODO: Consider Ad events

function nrSendPlayerReady() as Void
    ev = nrCreateVideoEvent("PLAYER_READY")
    nrRecordVideoEvent(ev)
end function

function nrSendRequest() as Void
    ev = nrCreateVideoEvent("CONTENT_REQUEST")
    nrRecordVideoEvent(ev)
end function

function nrSendStart() as Void
    ev = nrCreateVideoEvent("CONTENT_START")
    nrRecordVideoEvent(ev)
end function

function nrSendEnd() as Void
    ev = nrCreateVideoEvent("CONTENT_END")
    nrRecordVideoEvent(ev)
end function

function nrSendPause() as Void
    ev = nrCreateVideoEvent("CONTENT_PAUSE")
    nrRecordVideoEvent(ev)
end function

function nrSendResume() as Void
    ev = nrCreateVideoEvent("CONTENT_RESUME")
    nrRecordVideoEvent(ev)
end function

function nrSendBufferStart() as Void
    ev = nrCreateVideoEvent("CONTENT_BUFFER_START")
    nrRecordVideoEvent(ev)
end function

function nrSendBufferEnd() as Void
    ev = nrCreateVideoEvent("CONTENT_BUFFER_END")
    nrRecordVideoEvent(ev)
end function

function __nrStateObserver__() as Void
    print "---------- State Observer ----------"
    printVideoInfo()
    
    if m.nrVideoObject.state = "playing" and m.nrLastVideoState = "paused"
        nrSendResume()
    else if m.nrVideoObject.state = "paused" and m.nrLastVideoState = "playing"
        nrSendPause()
    end if
    
     m.nrLastVideoState = m.nrVideoObject.state

end function

function __nrIndexObserver__() as Void
    print "---------- Index Observer ----------"
    printVideoInfo()
end function

function __nrPositionObserver__() as Void
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
