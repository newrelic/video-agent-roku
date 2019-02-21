'**********************************************************
' NRAgent.brs
' New Relic Video Agent for Roku.
' Minimum requirements: FW 7.2
'
' Copyright 2019 New Relic Inc. All Rights Reserved. 
'**********************************************************

sub NewRelicVideoStart(videoObject as Object)
    print "Init NewRelicVideoAgent" 
    videoObject.observeField("state", "stateObserver")
    videoObject.observeField("contentIndex", "indexObserver")
    videoObject.observeField("position", "positionObserver")
    videoObject.notificationInterval = 1
    m.nrVideoObject = videoObject
end sub

function stateObserver() as Void
    print "---------- State Observer ----------"
    printVideoInfo()
end function

function indexObserver() as Void
    print "---------- Index Observer ----------"
    printVideoInfo()
end function

function positionObserver() as Void
    print "---------- Position Observer ----------"
    printVideoInfo()
end function

function printVideoInfo() as Void
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
    print "------------------------------------------"
end function
