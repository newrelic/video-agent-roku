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

    return this
End Function

Function multiAssert(arr as Object) as String
    for each assert in arr
        if assert <> "" return assert
    end for
    return ""
End Function

Sub MainTestSuite__SetUp()
    print "SetUp"

    ' Setup New Relic Agent
    m.nr = NewRelic("ACCOUNT_ID", "API_KEY", true)
    ' Disable harvest timer
    nrHarvestTimer = m.nr.findNode("nrHarvestTimer")
    nrHarvestTimer.control = "stop"
    ' Create Dummy Video object and start video tracking
    m.videoObject = CreateObject("roSGNode", "com.newrelic.test.DummyVideo")
    videoContent = createObject("RoSGNode", "ContentNode")
    videoContent.url = "http://fakedomain.com/fakevideo"
    videoContent.title = "Fake Video"
    m.videoObject.content = videoContent
    NewRelicVideoStart(m.nr, m.videoObject)
    'Remove initial video events (PLAYER_READY)
    m.nr.callFunc("nrExtractAllEvents")
End Sub

Sub MainTestSuite__TearDown()
    print "TearDown"
    ' Stop video tracking
    NewRelicVideoStop(m.nr)
End Sub

Function TestCase__Main_CustomEvents() as String
    print "Checking custom events..."
    
    nrSendSystemEvent(m.nr, "TEST_SYSTEM_EVENT")
    events = m.nr.callFunc("nrExtractAllEvents")

    x = m.assertArrayCount(events, 1)
    if x <> "" then return x

    ev = events[0]
    
    return multiAssert([
        m.assertEqual(ev.actionName, "TEST_SYSTEM_EVENT")
        m.assertNotInvalid(ev.timeSinceLoad)
        m.assertEqual(ev.timeSinceLoad, 0)
    ])
End Function


Function TestCase__Main_VideoEvents() as String
    print "Checking video events...", m.videoObject

    m.videoObject.callFunc("startBuffering")
    m.videoObject.callFunc("startPlayback")
    m.videoObject.callFunc("setPlayhead", 1.23)
    m.videoObject.callFunc("pausePlayback")
    m.videoObject.callFunc("resumePlayback")
    m.videoObject.callFunc("setPlayhead", 2.34)
    m.videoObject.callFunc("endPlayback")
    m.videoObject.callFunc("error")

    events = m.nr.callFunc("nrExtractAllEvents")

    x = m.assertArrayCount(events, 8)
    if x <> "" then return x

    x = multiAssert([
        m.assertEqual(events[0].actionName, "CONTENT_REQUEST")
        m.assertEqual(events[1].actionName, "CONTENT_BUFFER_START")
        m.assertEqual(events[2].actionName, "CONTENT_BUFFER_END")
        m.assertEqual(events[3].actionName, "CONTENT_START")
        m.assertEqual(events[4].actionName, "CONTENT_PAUSE")
        m.assertEqual(events[5].actionName, "CONTENT_RESUME")
        m.assertEqual(events[6].actionName, "CONTENT_END")
        m.assertEqual(events[7].actionName, "CONTENT_ERROR")
    ])
    if x <> "" then return x

    return ""
End Function
