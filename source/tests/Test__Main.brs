Function TestSuite__Main() as Object

    ' Inherite your test suite from BaseTestSuite
    this = BaseTestSuite()

    ' Test suite name for log statistics
    this.Name = "MainTestSuite"

    this.SetUp = MainTestSuite__SetUp
    this.TearDown = MainTestSuite__TearDown

    ' Add tests to suite's tests collection
    this.addTest("CustomEvents", TestCase__Main_CustomEvents)
    this.addTest("VideoEvents", TestCase__Main_VideoEvents)
    this.addTest("TimeSinceAttributes", TestCase__Main_TimeSinceAttributes)
    this.addTest("RAFTracker", TestCase__Main_RAFTracker)

    return this
End Function

Function multiAssert(arr as Object) as String
    for each assert in arr
        if assert <> "" return assert
    end for
    return ""
End Function

Sub MainTestSuite__SetUp()
    print "Main SetUp"
    ' Setup New Relic Agent
    if m.nr = invalid
        m.nr = NewRelic("ACCOUNT_ID", "API_KEY", "US", true)
    end if
    ' Disable harvest timer
    nrHarvestTimerEvents = m.nr.findNode("nrHarvestTimerEvents")
    nrHarvestTimerEvents.control = "stop"
    ' Create Dummy Video object and start video tracking
    m.videoObject = CreateObject("roSGNode", "com.newrelic.test.DummyVideo")
    videoContent = createObject("RoSGNode", "ContentNode")
    videoContent.url = "http://fakedomain.com/fakevideo"
    videoContent.title = "Fake Video"
    m.videoObject.content = videoContent
End Sub

Sub MainTestSuite__TearDown()
    print "Main TearDown"
End Sub

Sub Video_Tracking_SetUp(mm as Object)
    print "Video SetUp"
    NewRelicVideoStop(mm.nr)
    mm.videoObject.callFunc("resetState")
    NewRelicVideoStart(mm.nr, mm.videoObject)
    'Remove initial video events (PLAYER_READY)
    mm.nr.callFunc("nrExtractAllSamples", "event")
End Sub

Function TestCase__Main_CustomEvents() as String
    print "Checking custom events..."
    
    Video_Tracking_SetUp(m)
    
    nrSendSystemEvent(m.nr, "TEST_SYSTEM_EVENT")
    events = m.nr.callFunc("nrExtractAllSamples", "event")
    
    return multiAssert([
        m.assertArrayCount(events, 1)
        m.assertEqual(events[0].actionName, "TEST_SYSTEM_EVENT")
        m.assertNotInvalid(events[0].timeSinceLoad)
    ])
End Function

Function TestCase__Main_VideoEvents() as String
    print "Checking video events..."

    Video_Tracking_SetUp(m)

    nrSetCustomAttribute(m.nr, "myAttrOne", 555)
    nrSetCustomAttribute(m.nr, "myAttrTwo", 111, "CONTENT_ERROR")
    m.videoObject.callFunc("startBuffering")
    m.videoObject.callFunc("startPlayback")
    m.videoObject.callFunc("setPlayhead", 1.23)
    m.videoObject.callFunc("pausePlayback")
    m.videoObject.callFunc("resumePlayback")
    m.videoObject.callFunc("setPlayhead", 2.34)
    m.videoObject.callFunc("endPlayback")
    m.videoObject.callFunc("error")

    events = m.nr.callFunc("nrExtractAllSamples", "event")

    return multiAssert([
        m.assertArrayCount(events, 8)
        m.assertEqual(events[0].actionName, "CONTENT_REQUEST")
        m.assertEqual(events[0].myAttrOne, 555)
        m.assertInvalid(events[0].myAttrTwo)
        m.assertEqual(events[1].actionName, "CONTENT_BUFFER_START")
        m.assertEqual(events[2].actionName, "CONTENT_BUFFER_END")
        m.assertEqual(events[3].actionName, "CONTENT_START")
        m.assertEqual(Int(events[3].contentPlayhead), 0)
        m.assertEqual(events[4].actionName, "CONTENT_PAUSE")
        m.assertEqual(Int(events[4].contentPlayhead), 1230)
        m.assertEqual(events[5].actionName, "CONTENT_RESUME")
        m.assertEqual(events[6].actionName, "CONTENT_END")
        m.assertEqual(Int(events[6].contentPlayhead), 2340)
        m.assertEqual(events[7].actionName, "CONTENT_ERROR")
        m.assertEqual(events[7].myAttrOne, 555)
        m.assertEqual(events[7].myAttrTwo, 111)
    ])
End Function

Function TestCase__Main_TimeSinceAttributes() as String
    print "Checking time since attributes..."

    Video_Tracking_SetUp(m)

    sleep(100)
    m.videoObject.callFunc("startBuffering")
    sleep(200)
    m.videoObject.callFunc("startPlayback")
    sleep(400)
    m.videoObject.callFunc("pausePlayback")
    sleep(200)
    m.videoObject.callFunc("resumePlayback")
    sleep(400)
    m.videoObject.callFunc("endPlayback")

    events = m.nr.callFunc("nrExtractAllSamples", "event")

    return multiAssert([
        m.assertArrayCount(events, 7)
        m.assertEqual(events[0].actionName, "CONTENT_REQUEST")
        m.assertTrue(events[0].timeSinceTrackerReady > 100 OR events[0].timeSinceTrackerReady < 130)
        m.assertEqual(events[1].actionName, "CONTENT_BUFFER_START")
        m.assertEqual(events[2].actionName, "CONTENT_BUFFER_END")
        m.assertTrue(events[2].timeSinceBufferBegin > 200 OR events[2].timeSinceBufferBegin < 230)
        m.assertEqual(events[3].actionName, "CONTENT_START")
        m.assertTrue(events[3].timeSinceRequested > 200 OR events[3].timeSinceRequested < 250)
        m.assertEqual(events[4].actionName, "CONTENT_PAUSE")
        m.assertTrue(events[4].timeSinceStarted > 400 OR events[4].timeSinceStarted < 430)
        m.assertEqual(events[5].actionName, "CONTENT_RESUME")
        m.assertTrue(events[5].timeSincePaused > 200 OR events[5].timeSincePaused < 230)
        m.assertEqual(events[6].actionName, "CONTENT_END")
        m.assertTrue(events[6].timeSinceRequested > 1200 OR events[6].timeSinceRequested < 1300)
    ])
End Function

Function TestCase__Main_RAFTracker() as String
    print "Checking RAF tracker..."
    
    Video_Tracking_SetUp(m)

    ctx = {
        "rendersequence": "preroll",
        "duration": 30,
        "server": "http://whatever.com/my_ad"
    }

    nrTrackRAF(m.nr, "PodStart", ctx)
    nrTrackRAF(m.nr, "Impression", ctx)
    sleep(100)
    nrTrackRAF(m.nr, "Start", ctx)
    sleep(500)
    nrTrackRAF(m.nr, "Complete", ctx)
    nrTrackRAF(m.nr, "Impression", ctx)
    sleep(200)
    nrTrackRAF(m.nr, "Start", ctx)
    sleep(600)
    nrTrackRAF(m.nr, "Complete", ctx)
    nrTrackRAF(m.nr, "PodComplete", ctx)

    events = m.nr.callFunc("nrExtractAllSamples", "event")

    return multiAssert([
        m.assertArrayCount(events, 8)
        m.assertEqual(events[0].actionName, "AD_BREAK_START")
        m.assertEqual(events[0].adDuration, 30000)
        m.assertEqual(events[0].adPosition, "pre")
        m.assertEqual(events[0].numberOfAds, 0)
        m.assertEqual(events[1].actionName, "AD_REQUEST")
        m.assertEqual(events[2].actionName, "AD_START")
        m.assertEqual(events[2].numberOfAds, 1)
        m.assertTrue(events[2].timeSinceAdRequested > 100 AND events[2].timeSinceAdRequested < 130)
        m.assertEqual(events[3].actionName, "AD_END")
        m.assertTrue(events[3].timeSinceAdStarted > 500 AND events[3].timeSinceAdStarted < 530)
        m.assertEqual(events[4].actionName, "AD_REQUEST")
        m.assertEqual(events[5].actionName, "AD_START")
        m.assertTrue(events[5].timeSinceAdRequested > 200 AND events[5].timeSinceAdRequested < 230)
        m.assertEqual(events[5].numberOfAds, 2)
        m.assertEqual(events[6].actionName, "AD_END")
        m.assertTrue(events[6].timeSinceAdStarted > 600 AND events[6].timeSinceAdStarted < 630)
        m.assertEqual(events[7].actionName, "AD_BREAK_END")
        m.assertTrue(events[7].timeSinceAdBreakBegin > 1400 AND events[7].timeSinceAdBreakBegin < 1500)
    ])
End Function