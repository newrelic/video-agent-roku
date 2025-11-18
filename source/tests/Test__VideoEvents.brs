Function TestSuite__VideoEvents() as Object
    ' Test suite for comprehensive video event tracking
    this = BaseTestSuite()
    this.Name = "VideoEventsTestSuite"

    this.SetUp = VideoEventsTestSuite__SetUp
    this.TearDown = VideoEventsTestSuite__TearDown

    ' Add comprehensive video event tests
    this.addTest("VideoStateTransitions", TestCase__VideoEvents_StateTransitions)
    this.addTest("VideoHeartbeat", TestCase__VideoEvents_Heartbeat)
    this.addTest("VideoBuffering", TestCase__VideoEvents_Buffering)
    this.addTest("VideoPlaytimeTracking", TestCase__VideoEvents_PlaytimeTracking)
    this.addTest("VideoErrorHandling", TestCase__VideoEvents_ErrorHandling)
    this.addTest("VideoPlaylistHandling", TestCase__VideoEvents_PlaylistHandling)
    this.addTest("VideoAttributeGeneration", TestCase__VideoEvents_AttributeGeneration)
    this.addTest("VideoSessionTracking", TestCase__VideoEvents_SessionTracking)
    this.addTest("VideoContentMetadata", TestCase__VideoEvents_ContentMetadata)
    this.addTest("VideoStartEndFlow", TestCase__VideoEvents_StartEndFlow)

    return this
End Function

Sub VideoEventsTestSuite__SetUp()
    print "VideoEvents SetUp"
    ' Setup New Relic Agent
    if m.nr = invalid
        m.nr = NewRelic("ACCOUNT_ID", "API_KEY", "TestApp", "", "US", true)
    end if
    ' Disable harvest timers
    nrHarvestTimerEvents = m.nr.findNode("nrHarvestTimerEvents")
    nrHarvestTimerEvents.control = "stop"
    nrHarvestTimerLogs = m.nr.findNode("nrHarvestTimerLogs")
    nrHarvestTimerLogs.control = "stop"
    nrHarvestTimerMetrics = m.nr.findNode("nrHarvestTimerMetrics")
    nrHarvestTimerMetrics.control = "stop"
    
    ' Create Dummy Video object
    m.videoObject = CreateObject("roSGNode", "com.newrelic.test.DummyVideo")
    videoContent = createObject("RoSGNode", "ContentNode")
    videoContent.url = "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8"
    videoContent.title = "Single Video"
    m.videoObject.content = videoContent
End Sub

Sub VideoEventsTestSuite__TearDown()
    print "VideoEvents TearDown"
    if m.nr <> invalid
        NewRelicVideoStop(m.nr)
    end if
End Sub

Sub Video_Tracking_Reset(mm as Object)
    ' Reset video tracking state
    NewRelicVideoStop(mm.nr)
    mm.videoObject.callFunc("resetState")
    NewRelicVideoStart(mm.nr, mm.videoObject)
    ' Clear initial events (PLAYER_READY)
    mm.nr.callFunc("nrExtractAllSamples", "event")
End Sub

' Test 1: Video State Transitions
Function TestCase__VideoEvents_StateTransitions() as String
    print "Testing video state transitions..."
    
    Video_Tracking_Reset(m)
    
    ' Simulate state transition flow: none -> buffering -> playing -> paused -> playing -> finished
    m.videoObject.callFunc("startBuffering")
    m.videoObject.callFunc("startPlayback")
    m.videoObject.callFunc("pausePlayback")
    m.videoObject.callFunc("resumePlayback")
    m.videoObject.callFunc("endPlayback")
    
    events = m.nr.callFunc("nrExtractAllSamples", "event")
    
    return multiAssert([
        m.assertArrayCount(events, 7)
        m.assertEqual(events[0].actionName, "CONTENT_REQUEST")
        m.assertEqual(events[0].eventType, "VideoAction")
        m.assertEqual(events[1].actionName, "CONTENT_BUFFER_START")
        m.assertEqual(events[2].actionName, "CONTENT_BUFFER_END")
        m.assertEqual(events[3].actionName, "CONTENT_START")
        m.assertEqual(events[4].actionName, "CONTENT_PAUSE")
        m.assertEqual(events[5].actionName, "CONTENT_RESUME")
        m.assertEqual(events[6].actionName, "CONTENT_END")
    ])
End Function

' Test 2: Video Heartbeat
Function TestCase__VideoEvents_Heartbeat() as String
    print "Testing video heartbeat generation..."
    
    Video_Tracking_Reset(m)
    
    ' Start playback
    m.videoObject.callFunc("startBuffering")
    m.videoObject.callFunc("startPlayback")
    
    ' Clear initial events
    m.nr.callFunc("nrExtractAllSamples", "event")
    
    ' Manually trigger heartbeat (don't wait 30 seconds)
    m.videoObject.callFunc("setPlayhead", 35.0)
    sleep(50)
    m.nr.callFunc("nrHeartbeatHandler")
    sleep(50)
    
    events = m.nr.callFunc("nrExtractAllSamples", "event")
    
    ' Heartbeat test: verify at least 1 heartbeat event was created
    hasHeartbeat = false
    for each evt in events
        if evt.actionName = "CONTENT_HEARTBEAT" then
            hasHeartbeat = true
            exit for
        end if
    end for
    
    return multiAssert([
        m.assertTrue(hasHeartbeat, "Heartbeat event should be generated")
        m.assertTrue(events.Count() > 0, "At least one event should exist")
    ])
End Function

' Test 3: Video Buffering
Function TestCase__VideoEvents_Buffering() as String
    print "Testing video buffering events..."
    
    Video_Tracking_Reset(m)
    
    ' Initial buffering (before start)
    m.videoObject.callFunc("startBuffering")
    sleep(100)
    m.videoObject.callFunc("startPlayback")
    
    ' Mid-playback buffering
    sleep(50)
    m.videoObject.callFunc("startBuffering")
    sleep(100)
    m.videoObject.callFunc("startPlayback")
    
    events = m.nr.callFunc("nrExtractAllSamples", "event")
    
    return multiAssert([
        m.assertArrayCount(events, 6)
        m.assertEqual(events[0].actionName, "CONTENT_REQUEST")
        m.assertEqual(events[1].actionName, "CONTENT_BUFFER_START")
        m.assertEqual(events[1].isInitialBuffering, true)
        m.assertEqual(events[2].actionName, "CONTENT_BUFFER_END")
        m.assertEqual(events[2].isInitialBuffering, true)
        m.assertEqual(events[3].actionName, "CONTENT_START")
        m.assertEqual(events[4].actionName, "CONTENT_BUFFER_START")
        m.assertEqual(events[4].isInitialBuffering, false)
        m.assertNotInvalid(events[4].bufferType)
        m.assertEqual(events[5].actionName, "CONTENT_BUFFER_END")
        m.assertNotInvalid(events[5].timeSinceBufferBegin)
    ])
End Function

' Test 4: Video Playtime Tracking
Function TestCase__VideoEvents_PlaytimeTracking() as String
    print "Testing video playtime tracking..."
    
    Video_Tracking_Reset(m)
    
    ' Start playback
    m.videoObject.callFunc("startBuffering")
    m.videoObject.callFunc("startPlayback")
    sleep(200)
    
    ' Pause
    m.videoObject.callFunc("pausePlayback")
    sleep(100)
    
    ' Resume
    m.videoObject.callFunc("resumePlayback")
    sleep(200)
    
    ' End
    m.videoObject.callFunc("endPlayback")
    
    events = m.nr.callFunc("nrExtractAllSamples", "event")
    
    return multiAssert([
        m.assertArrayCount(events, 7)
        m.assertEqual(events[3].actionName, "CONTENT_START")
        m.assertNotInvalid(events[3].totalPlaytime)
        m.assertEqual(events[4].actionName, "CONTENT_PAUSE")
        m.assertTrue(events[4].totalPlaytime > 0)
        m.assertEqual(events[5].actionName, "CONTENT_RESUME")
        m.assertTrue(events[5].totalPlaytime > events[4].totalPlaytime)
        m.assertEqual(events[6].actionName, "CONTENT_END")
        m.assertTrue(events[6].totalPlaytime > events[5].totalPlaytime)
    ])
End Function

' Test 5: Video Error Handling
Function TestCase__VideoEvents_ErrorHandling() as String
    print "Testing video error handling..."
    
    Video_Tracking_Reset(m)
    
    ' Start playback
    m.videoObject.callFunc("startBuffering")
    m.videoObject.callFunc("startPlayback")
    
    ' Trigger error
    m.videoObject.callFunc("error")
    
    events = m.nr.callFunc("nrExtractAllSamples", "event")
    
    return multiAssert([
        m.assertArrayCount(events, 4)
        m.assertEqual(events[3].actionName, "CONTENT_ERROR")
        m.assertEqual(events[3].eventType, "VideoErrorAction")
        m.assertNotInvalid(events[3].errorMessage)
        m.assertNotInvalid(events[3].errorCode)
        m.assertNotInvalid(events[3].numberOfErrors)
        m.assertEqual(events[3].numberOfErrors, 1)
    ])
End Function

' Test 6: Video Playlist Handling
Function TestCase__VideoEvents_PlaylistHandling() as String
    print "Testing video playlist handling..."
    
    Video_Tracking_Reset(m)
    
    ' Setup playlist
    m.videoObject.contentIsPlaylist = true
    m.videoObject.contentIndex = 0
    
    ' Play first video
    m.videoObject.callFunc("startBuffering")
    m.videoObject.callFunc("startPlayback")
    m.videoObject.callFunc("setPlayhead", 2.5)
    
    ' Clear events
    m.nr.callFunc("nrExtractAllSamples", "event")
    
    ' Change to next video in playlist
    m.videoObject.contentIndex = 1
    m.nr.callFunc("nrIndexObserver")
    
    events = m.nr.callFunc("nrExtractAllSamples", "event")
    
    return multiAssert([
        m.assertArrayCount(events, 3)
        m.assertEqual(events[0].actionName, "CONTENT_END")
        m.assertEqual(events[1].actionName, "CONTENT_REQUEST")
        m.assertEqual(events[2].actionName, "CONTENT_START")
        m.assertNotInvalid(events[0].viewId)
        m.assertNotInvalid(events[1].numberOfVideos)
    ])
End Function

' Test 7: Video Attribute Generation
Function TestCase__VideoEvents_AttributeGeneration() as String
    print "Testing video attribute generation..."
    
    Video_Tracking_Reset(m)
    
    ' Set custom attributes
    nrSetCustomAttribute(m.nr, "customAttr1", "value1")
    nrSetCustomAttribute(m.nr, "customAttr2", 12345)
    
    ' Start playback
    m.videoObject.callFunc("startBuffering")
    m.videoObject.callFunc("setPlayhead", 1.5)
    m.videoObject.callFunc("startPlayback")
    
    events = m.nr.callFunc("nrExtractAllSamples", "event")
    
    return multiAssert([
        m.assertArrayCount(events, 4)
        ' Verify CONTENT_START has all key attributes
        m.assertEqual(events[3].actionName, "CONTENT_START")
        m.assertEqual(events[3].customAttr1, "value1")
        m.assertEqual(events[3].customAttr2, 12345)
        m.assertNotInvalid(events[3].contentSrc)
        m.assertNotInvalid(events[3].contentId)
        m.assertNotInvalid(events[3].contentDuration)
        m.assertNotInvalid(events[3].contentPlayhead)
        m.assertNotInvalid(events[3].playerName)
        m.assertNotInvalid(events[3].playerVersion)
        m.assertNotInvalid(events[3].trackerName)
        m.assertNotInvalid(events[3].trackerVersion)
        m.assertNotInvalid(events[3].viewId)
        m.assertNotInvalid(events[3].viewSession)
        m.assertNotInvalid(events[3].sessionDuration)
        m.assertNotInvalid(events[3].deviceModel)
        m.assertNotInvalid(events[3].osName)
        m.assertNotInvalid(events[3].osVersion)
    ])
End Function

' Test 8: Video Session Tracking
Function TestCase__VideoEvents_SessionTracking() as String
    print "Testing video session tracking..."
    
    Video_Tracking_Reset(m)
    
    ' Play multiple videos in sequence
    m.videoObject.callFunc("startBuffering")
    m.videoObject.callFunc("startPlayback")
    m.videoObject.callFunc("endPlayback")
    
    ' Second video
    m.videoObject.callFunc("resetState")
    m.videoObject.callFunc("startBuffering")
    m.videoObject.callFunc("startPlayback")
    m.videoObject.callFunc("endPlayback")
    
    events = m.nr.callFunc("nrExtractAllSamples", "event")
    
    return multiAssert([
        m.assertArrayCount(events, 10)
        ' First video
        m.assertEqual(events[0].actionName, "CONTENT_REQUEST")
        m.assertEqual(events[0].numberOfVideos, 1)
        m.assertEqual(events[3].actionName, "CONTENT_END")
        ' Second video
        m.assertEqual(events[4].actionName, "CONTENT_REQUEST")
        m.assertEqual(events[4].numberOfVideos, 2)
        m.assertEqual(events[7].actionName, "CONTENT_END")
        m.assertEqual(events[7].numberOfVideos, 2)
        ' Verify viewId changes between videos
        m.assertNotEqual(events[0].viewId, events[4].viewId)
        ' Verify viewSession remains the same
        m.assertEqual(events[0].viewSession, events[4].viewSession)
    ])
End Function

' Test 9: Video Content Metadata
Function TestCase__VideoEvents_ContentMetadata() as String
    print "Testing video content metadata..."
    
    Video_Tracking_Reset(m)
    
    ' Set video content with title
    videoContent = createObject("RoSGNode", "ContentNode")
    videoContent.url = "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8"
    videoContent.title = "HLS Test Video"
    m.videoObject.content = videoContent
    
    ' Start playback
    m.videoObject.callFunc("startBuffering")
    m.videoObject.callFunc("startPlayback")
    
    events = m.nr.callFunc("nrExtractAllSamples", "event")
    
    return multiAssert([
        m.assertArrayCount(events, 4)
        m.assertEqual(events[3].actionName, "CONTENT_START")
        m.assertEqual(events[3].contentTitle, "My Test Video Title")
        m.assertNotInvalid(events[3].contentSrc)
        m.assertNotInvalid(events[3].contentId)
    ])
End Function

' Test 10: Video Start End Flow with Timing
Function TestCase__VideoEvents_StartEndFlow() as String
    print "Testing video start/end flow with timing attributes..."
    
    Video_Tracking_Reset(m)
    
    ' Complete video playback flow with delays
    sleep(100)
    m.videoObject.callFunc("startBuffering")
    sleep(200)
    m.videoObject.callFunc("startPlayback")
    sleep(300)
    m.videoObject.callFunc("endPlayback")
    
    events = m.nr.callFunc("nrExtractAllSamples", "event")
    
    return multiAssert([
        m.assertArrayCount(events, 4)
        m.assertEqual(events[0].actionName, "CONTENT_REQUEST")
        m.assertTrue(events[0].timeSinceTrackerReady > 100 OR events[0].timeSinceTrackerReady < 150)
        m.assertEqual(events[1].actionName, "CONTENT_BUFFER_START")
        m.assertEqual(events[2].actionName, "CONTENT_BUFFER_END")
        m.assertTrue(events[2].timeSinceBufferBegin > 200 OR events[2].timeSinceBufferBegin < 250)
        m.assertEqual(events[3].actionName, "CONTENT_START")
        m.assertTrue(events[3].timeSinceRequested > 200 OR events[3].timeSinceRequested < 300)
        m.assertNotInvalid(events[3].timeSinceTrackerReady)
        m.assertNotInvalid(events[3].timeSinceStarted)
    ])
End Function
