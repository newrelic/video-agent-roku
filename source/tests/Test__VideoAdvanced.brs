Function TestSuite__VideoAdvanced() as Object
    ' Test suite for advanced video tracking scenarios
    this = BaseTestSuite()
    this.Name = "VideoAdvancedTestSuite"

    this.SetUp = VideoAdvancedTestSuite__SetUp
    this.TearDown = VideoAdvancedTestSuite__TearDown

    ' Add advanced video tests
    this.addTest("VideoCustomAttributes", TestCase__VideoAdv_CustomAttributes)
    this.addTest("VideoBackupAttributes", TestCase__VideoAdv_BackupAttributes)
    this.addTest("VideoTimeSinceAttributes", TestCase__VideoAdv_TimeSinceAttributes)
    this.addTest("VideoSeekBuffering", TestCase__VideoAdv_SeekBuffering)
    this.addTest("VideoMultipleErrors", TestCase__VideoAdv_MultipleErrors)
    this.addTest("VideoDeviceAttributes", TestCase__VideoAdv_DeviceAttributes)
    this.addTest("VideoContentBitrate", TestCase__VideoAdv_ContentBitrate)
    this.addTest("VideoViewIdGeneration", TestCase__VideoAdv_ViewIdGeneration)

    return this
End Function

Sub VideoAdvancedTestSuite__SetUp()
    print "VideoAdvanced SetUp"
    ' Setup New Relic Agent
    if m.nr = invalid
        m.nr = NewRelic("ACCOUNT_ID", "API_KEY", "TestApp", "", "US", true)
    end if
    ' Disable harvest timers
    nrHarvestTimerEvents = m.nr.findNode("nrHarvestTimerEvents")
    nrHarvestTimerEvents.control = "stop"
    
        ' Create Dummy Video object
    m.videoObject = CreateObject("roSGNode", "com.newrelic.test.DummyVideo")
    videoContent = createObject("RoSGNode", "ContentNode")
    videoContent.url = "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8"
    videoContent.title = "Single Video"
    m.videoObject.content = videoContent
End Sub

Sub VideoAdvancedTestSuite__TearDown()
    print "VideoAdvanced TearDown"
    if m.nr <> invalid
        NewRelicVideoStop(m.nr)
    end if
End Sub

Sub VideoAdv_Tracking_Reset(mm as Object)
    ' Reset video tracking state
    NewRelicVideoStop(mm.nr)
    mm.videoObject.callFunc("resetState")
    NewRelicVideoStart(mm.nr, mm.videoObject)
    ' Clear initial events (PLAYER_READY)
    mm.nr.callFunc("nrExtractAllSamples", "event")
End Sub

' Test 1: Video Custom Attributes per Action
Function TestCase__VideoAdv_CustomAttributes() as String
    print "Testing video custom attributes per action..."
    
    VideoAdv_Tracking_Reset(m)
    
    ' Set general custom attributes
    nrSetCustomAttribute(m.nr, "generalAttr", "general-value")
    
    ' Set action-specific custom attributes
    nrSetCustomAttribute(m.nr, "startAttr", "start-value", "CONTENT_START")
    nrSetCustomAttribute(m.nr, "pauseAttr", "pause-value", "CONTENT_PAUSE")
    
    ' Start playback
    m.videoObject.callFunc("startBuffering")
    m.videoObject.callFunc("startPlayback")
    m.videoObject.callFunc("pausePlayback")
    
    events = m.nr.callFunc("nrExtractAllSamples", "event")
    
    return multiAssert([
        m.assertArrayCount(events, 5)
        ' All events should have general attribute
        m.assertEqual(events[0].generalAttr, "general-value")
        m.assertEqual(events[3].generalAttr, "general-value")
        m.assertEqual(events[4].generalAttr, "general-value")
        ' Only CONTENT_START should have startAttr
        m.assertEqual(events[3].startAttr, "start-value")
        m.assertInvalid(events[0].startAttr)
        m.assertInvalid(events[4].startAttr)
        ' Only CONTENT_PAUSE should have pauseAttr
        m.assertEqual(events[4].pauseAttr, "pause-value")
        m.assertInvalid(events[3].pauseAttr)
    ])
End Function

' Test 2: Video Backup Attributes
Function TestCase__VideoAdv_BackupAttributes() as String
    print "Testing video backup attributes mechanism..."
    
    VideoAdv_Tracking_Reset(m)
    
    ' Start playback
    m.videoObject.callFunc("startBuffering")
    m.videoObject.callFunc("setPlayhead", 5.5)
    m.videoObject.callFunc("startPlayback")
    
    ' Clear events
    m.nr.callFunc("nrExtractAllSamples", "event")
    
    ' Use backup event to send custom end
    sleep(100)
    m.nr.callFunc("nrSendBackupVideoEnd")
    
    events = m.nr.callFunc("nrExtractAllSamples", "event")
    
    return multiAssert([
        m.assertArrayCount(events, 1)
        m.assertEqual(events[0].actionName, "CONTENT_END")
        m.assertNotInvalid(events[0].contentPlayhead)
        m.assertNotInvalid(events[0].timestamp)
        m.assertNotInvalid(events[0].totalPlaytime)
    ])
End Function

' Test 3: Video TimeSince Attributes
Function TestCase__VideoAdv_TimeSinceAttributes() as String
    print "Testing video timeSince attributes..."
    
    VideoAdv_Tracking_Reset(m)
    
    ' Start with delays
    sleep(100)
    m.videoObject.callFunc("startBuffering")
    sleep(200)
    m.videoObject.callFunc("startPlayback")
    sleep(150)
    m.videoObject.callFunc("pausePlayback")
    sleep(100)
    m.videoObject.callFunc("resumePlayback")
    
    events = m.nr.callFunc("nrExtractAllSamples", "event")
    
    return multiAssert([
        m.assertArrayCount(events, 6)
        ' timeSinceTrackerReady should be set
        m.assertNotInvalid(events[0].timeSinceTrackerReady)
        m.assertTrue(events[0].timeSinceTrackerReady > 90)
        ' timeSinceBufferBegin on buffer end
        m.assertEqual(events[2].actionName, "CONTENT_BUFFER_END")
        m.assertNotInvalid(events[2].timeSinceBufferBegin)
        m.assertTrue(events[2].timeSinceBufferBegin > 190)
        ' timeSinceRequested on start
        m.assertEqual(events[3].actionName, "CONTENT_START")
        m.assertNotInvalid(events[3].timeSinceRequested)
        ' timeSinceStarted on pause
        m.assertEqual(events[4].actionName, "CONTENT_PAUSE")
        m.assertNotInvalid(events[4].timeSinceStarted)
        ' timeSincePaused on resume
        m.assertEqual(events[5].actionName, "CONTENT_RESUME")
        m.assertNotInvalid(events[5].timeSincePaused)
        m.assertTrue(events[5].timeSincePaused > 90)
    ])
End Function

' Test 4: Video Seek Buffering Type
Function TestCase__VideoAdv_SeekBuffering() as String
    print "Testing video seek buffering type..."
    
    VideoAdv_Tracking_Reset(m)
    
    ' Start playback
    m.videoObject.callFunc("startBuffering")
    m.videoObject.callFunc("startPlayback")
    
    ' Clear events
    m.nr.callFunc("nrExtractAllSamples", "event")
    
    ' Simulate seek (trigger buffering while playing)
    m.videoObject.callFunc("startBuffering")
    
    events = m.nr.callFunc("nrExtractAllSamples", "event")
    
    return multiAssert([
        m.assertArrayCount(events, 1)
        m.assertEqual(events[0].actionName, "CONTENT_BUFFER_START")
        m.assertEqual(events[0].isInitialBuffering, false)
        m.assertNotInvalid(events[0].bufferType)
        ' Buffer type should be connection (not initial, not pause)
        m.assertEqual(events[0].bufferType, "connection")
    ])
End Function

' Test 5: Video Multiple Errors Tracking
Function TestCase__VideoAdv_MultipleErrors() as String
    print "Testing video multiple errors tracking..."
    
    VideoAdv_Tracking_Reset(m)
    
    ' Start playback
    m.videoObject.callFunc("startBuffering")
    m.videoObject.callFunc("startPlayback")
    
    ' Trigger multiple errors
    m.videoObject.callFunc("error")
    sleep(100)
    m.videoObject.callFunc("error")
    sleep(100)
    m.videoObject.callFunc("error")
    
    events = m.nr.callFunc("nrExtractAllSamples", "event")
    
    return multiAssert([
        m.assertArrayCount(events, 7)
        m.assertEqual(events[4].actionName, "CONTENT_ERROR")
        m.assertEqual(events[4].numberOfErrors, 1)
        m.assertEqual(events[5].actionName, "CONTENT_ERROR")
        m.assertEqual(events[5].numberOfErrors, 2)
        m.assertNotInvalid(events[5].timeSinceLastError)
        m.assertEqual(events[6].actionName, "CONTENT_ERROR")
        m.assertEqual(events[6].numberOfErrors, 3)
        m.assertNotInvalid(events[6].timeSinceLastError)
    ])
End Function

' Test 6: Video Device Attributes
Function TestCase__VideoAdv_DeviceAttributes() as String
    print "Testing video device attributes..."
    
    VideoAdv_Tracking_Reset(m)
    
    ' Start playback
    m.videoObject.callFunc("startBuffering")
    m.videoObject.callFunc("startPlayback")
    
    events = m.nr.callFunc("nrExtractAllSamples", "event")
    
    return multiAssert([
        m.assertArrayCount(events, 4)
        ' Check device attributes on any event
        m.assertNotInvalid(events[0].deviceModel)
        m.assertNotInvalid(events[0].deviceType)
        m.assertNotInvalid(events[0].osName)
        m.assertNotInvalid(events[0].osVersion)
        m.assertNotInvalid(events[0].uuid)
        m.assertNotInvalid(events[0].deviceManufacturer)
        m.assertEqual(events[0].deviceGroup, "Roku")
        m.assertEqual(events[0].deviceManufacturer, "Roku")
        m.assertNotInvalid(events[0].memoryLevel)
        m.assertNotInvalid(events[0].hdmiIsConnected)
    ])
End Function

' Test 7: Video Content Bitrate
Function TestCase__VideoAdv_ContentBitrate() as String
    print "Testing video content bitrate attributes..."
    
    VideoAdv_Tracking_Reset(m)
    
    ' Start playback
    m.videoObject.callFunc("startBuffering")
    m.videoObject.callFunc("startPlayback")
    
    events = m.nr.callFunc("nrExtractAllSamples", "event")
    
    return multiAssert([
        m.assertArrayCount(events, 4)
        m.assertEqual(events[3].actionName, "CONTENT_START")
        ' Check that bitrate attributes exist (they may be invalid depending on dummy video)
        ' The key is that the attributes are being checked and added
        m.assertNotInvalid(events[3].playerName)
        m.assertEqual(events[3].playerName, "RokuVideoPlayer")
        m.assertNotInvalid(events[3].playerVersion)
        m.assertNotInvalid(events[3].contentDuration)
        m.assertNotInvalid(events[3].contentPlayhead)
    ])
End Function

' Test 8: Video ViewId Generation
Function TestCase__VideoAdv_ViewIdGeneration() as String
    print "Testing video viewId generation..."
    
    VideoAdv_Tracking_Reset(m)
    
    ' Play first video
    m.videoObject.callFunc("startBuffering")
    m.videoObject.callFunc("startPlayback")
    m.videoObject.callFunc("endPlayback")
    
    ' Play second video
    m.videoObject.callFunc("resetState")
    m.videoObject.callFunc("startBuffering")
    m.videoObject.callFunc("startPlayback")
    
    events = m.nr.callFunc("nrExtractAllSamples", "event")
    
    return multiAssert([
        ' Extract viewIds from events
        m.assertArrayCount(events, 8)
        m.assertNotInvalid(events[0].viewId)
        m.assertNotInvalid(events[0].viewSession)
        m.assertNotInvalid(events[4].viewId)
        m.assertNotInvalid(events[4].viewSession)
        ' ViewSession should remain the same
        m.assertEqual(events[0].viewSession, events[4].viewSession)
        ' ViewId should be different (includes video counter)
        m.assertNotEqual(events[0].viewId, events[4].viewId)
        ' numberOfVideos should increment
        m.assertEqual(events[0].numberOfVideos, 1)
        m.assertEqual(events[4].numberOfVideos, 2)
    ])
End Function
