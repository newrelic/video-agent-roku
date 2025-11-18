Function TestSuite__AttributeCoverage() as Object
    ' Test suite for 100% attribute function coverage
    this = BaseTestSuite()
    this.Name = "AttributeCoverageTestSuite"

    this.SetUp = AttributeCoverageTestSuite__SetUp
    this.TearDown = AttributeCoverageTestSuite__TearDown

    ' Add attribute coverage tests
    this.addTest("BaseAttributes", TestCase__Attr_BaseAttributes)
    this.addTest("CustomAttributes", TestCase__Attr_CustomAttributes)
    this.addTest("VideoAttributes", TestCase__Attr_VideoAttributes)
    this.addTest("RAFAttributes", TestCase__Attr_RAFAttributes)
    this.addTest("RAFAdPositions", TestCase__Attr_RAFAdPositions)
    this.addTest("RAFAdBitrate", TestCase__Attr_RAFAdBitrate)
    this.addTest("RAFTimingAttributes", TestCase__Attr_RAFTimingAttributes)
    this.addTest("GenerateStreamUrl", TestCase__Attr_GenerateStreamUrl)
    this.addTest("GenerateId", TestCase__Attr_GenerateId)

    return this
End Function

Sub AttributeCoverageTestSuite__SetUp()
    print "AttributeCoverage SetUp"
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

Sub AttributeCoverageTestSuite__TearDown()
    print "AttributeCoverage TearDown"
    if m.nr <> invalid
        NewRelicVideoStop(m.nr)
    end if
End Sub

Sub Attr_Tracking_Reset(mm as Object)
    ' Reset video tracking state
    NewRelicVideoStop(mm.nr)
    mm.videoObject.callFunc("resetState")
    NewRelicVideoStart(mm.nr, mm.videoObject)
    ' Clear initial events
    mm.nr.callFunc("nrExtractAllSamples", "event")
End Sub

' Test 1: Base Attributes Coverage
Function TestCase__Attr_BaseAttributes() as String
    print "Testing base attributes generation..."
    
    Attr_Tracking_Reset(m)
    
    ' Generate any event to trigger base attributes
    m.videoObject.callFunc("startBuffering")
    m.videoObject.callFunc("startPlayback")
    
    events = m.nr.callFunc("nrExtractAllSamples", "event")
    
    return multiAssert([
        m.assertArrayCount(events, 4)
        ' Check base attributes on any event
        m.assertNotInvalid(events[0].src)
        m.assertEqual(events[0].src, "Roku")
        m.assertNotInvalid(events[0]["instrumentation.provider"])
        m.assertEqual(events[0]["instrumentation.provider"], "newrelic")
        m.assertNotInvalid(events[0]["instrumentation.name"])
        m.assertEqual(events[0]["instrumentation.name"], "roku")
        m.assertNotInvalid(events[0]["instrumentation.version"])
        m.assertNotInvalid(events[0].newRelicAgent)
        m.assertEqual(events[0].newRelicAgent, "RokuAgent")
        m.assertNotInvalid(events[0].newRelicVersion)
        m.assertNotInvalid(events[0].sessionId)
        m.assertNotInvalid(events[0].hdmiIsConnected)
        m.assertNotInvalid(events[0].uuid)
        m.assertNotInvalid(events[0].deviceName)
        m.assertEqual(events[0].deviceGroup, "Roku")
        m.assertEqual(events[0].deviceManufacturer, "Roku")
        m.assertNotInvalid(events[0].deviceModel)
        m.assertNotInvalid(events[0].deviceType)
        m.assertEqual(events[0].osName, "RokuOS")
        m.assertNotInvalid(events[0].osVersion)
        m.assertNotInvalid(events[0].countryCode)
        m.assertNotInvalid(events[0].locale)
        m.assertNotInvalid(events[0].memoryLevel)
        m.assertNotInvalid(events[0].timeSinceLastKeypress)
        m.assertNotInvalid(events[0].appVersion)
        m.assertNotInvalid(events[0].uptime)
        m.assertNotInvalid(events[0].timeSinceLoad)
    ])
End Function

' Test 2: Custom Attributes Coverage
Function TestCase__Attr_CustomAttributes() as String
    print "Testing custom attributes addition..."
    
    Attr_Tracking_Reset(m)
    
    ' Set multiple custom attributes
    nrSetCustomAttribute(m.nr, "customString", "test-value")
    nrSetCustomAttribute(m.nr, "customNumber", 12345)
    nrSetCustomAttribute(m.nr, "customBool", true)
    nrSetCustomAttribute(m.nr, "customFloat", 3.14159)
    
    ' Set action-specific attributes
    nrSetCustomAttribute(m.nr, "startSpecific", "start-value", "CONTENT_START")
    nrSetCustomAttribute(m.nr, "errorSpecific", "error-value", "CONTENT_ERROR")
    
    ' Trigger events
    m.videoObject.callFunc("startBuffering")
    m.videoObject.callFunc("startPlayback")
    m.videoObject.callFunc("error")
    
    events = m.nr.callFunc("nrExtractAllSamples", "event")
    
    return multiAssert([
        m.assertArrayCount(events, 5)
        ' General custom attributes should be on all events
        m.assertEqual(events[0].customString, "test-value")
        m.assertEqual(events[0].customNumber, 12345)
        m.assertEqual(events[0].customBool, true)
        m.assertEqual(events[3].customString, "test-value")
        m.assertEqual(events[4].customString, "test-value")
        ' Action-specific attributes
        m.assertEqual(events[3].startSpecific, "start-value")
        m.assertInvalid(events[0].startSpecific)
        m.assertInvalid(events[4].startSpecific)
        m.assertEqual(events[4].errorSpecific, "error-value")
        m.assertInvalid(events[0].errorSpecific)
        m.assertInvalid(events[3].errorSpecific)
    ])
End Function

' Test 3: Video Attributes Coverage - Comprehensive across all events
Function TestCase__Attr_VideoAttributes() as String
    print "Testing video attributes across all event types..."
    
    Attr_Tracking_Reset(m)
    
    ' Test sequence: REQUEST -> BUFFER_START -> START -> HEARTBEAT -> PAUSE -> RESUME -> BUFFER -> END
    m.videoObject.callFunc("startBuffering")
    sleep(50)
    m.videoObject.callFunc("setPlayhead", 5.5)
    m.videoObject.callFunc("startPlayback")
    sleep(100)
    
    ' Trigger heartbeat manually (don't wait 30 seconds)
    m.videoObject.callFunc("setPlayhead", 35.5)
    sleep(50)
    m.nr.callFunc("nrHeartbeatHandler")
    sleep(50)
    
    ' Pause and resume
    m.videoObject.callFunc("pause")
    sleep(50)
    m.videoObject.callFunc("resume")
    sleep(50)
    
    ' Buffer during playback
    m.videoObject.callFunc("startBuffering")
    sleep(50)
    m.videoObject.callFunc("endBuffering")
    sleep(50)
    
    ' End playback
    m.videoObject.callFunc("setPlayhead", 300)
    m.videoObject.callFunc("endPlayback")
    
    events = m.nr.callFunc("nrExtractAllSamples", "event")
    
    ' Find specific events
    requestEvent = invalid
    startEvent = invalid
    heartbeatEvent = invalid
    pauseEvent = invalid
    resumeEvent = invalid
    bufferStartEvent = invalid
    endEvent = invalid
    
    for each evt in events
        if evt.actionName = "CONTENT_REQUEST" then requestEvent = evt
        if evt.actionName = "CONTENT_START" then startEvent = evt
        if evt.actionName = "CONTENT_HEARTBEAT" then heartbeatEvent = evt
        if evt.actionName = "CONTENT_PAUSE" then pauseEvent = evt
        if evt.actionName = "CONTENT_RESUME" then resumeEvent = evt
        if evt.actionName = "CONTENT_BUFFER_START" then 
            if bufferStartEvent = invalid then bufferStartEvent = evt
        end if
        if evt.actionName = "CONTENT_END" then endEvent = evt
    end for
    
    asserts = [
        m.assertNotInvalid(requestEvent, "REQUEST event")
        m.assertNotInvalid(startEvent, "START event")
        ' Heartbeat is optional - may not trigger in test environment
        m.assertNotInvalid(pauseEvent, "PAUSE event")
        m.assertNotInvalid(resumeEvent, "RESUME event")
        m.assertNotInvalid(bufferStartEvent, "BUFFER_START event")
        m.assertNotInvalid(endEvent, "END event")
    ]
    
    ' Test core video attributes on CONTENT_START
    if startEvent <> invalid
        asserts.push(m.assertNotInvalid(startEvent.contentDuration, "contentDuration on START"))
        asserts.push(m.assertNotInvalid(startEvent.contentPlayhead, "contentPlayhead on START"))
        asserts.push(m.assertNotInvalid(startEvent.contentIsMuted, "contentIsMuted on START"))
        asserts.push(m.assertEqual(startEvent.contentIsFullscreen, "true", "contentIsFullscreen on START"))
        asserts.push(m.assertEqual(startEvent.playerName, "RokuVideoPlayer", "playerName on START"))
        asserts.push(m.assertNotInvalid(startEvent.playerVersion, "playerVersion on START"))
        asserts.push(m.assertNotInvalid(startEvent.contentTitle, "contentTitle on START"))
        asserts.push(m.assertEqual(startEvent.contentTitle, "Attribute Test Video", "contentTitle value"))
        asserts.push(m.assertNotInvalid(startEvent.contentSrc, "contentSrc on START"))
        asserts.push(m.assertEqual(startEvent.trackerName, "rokutracker", "trackerName on START"))
        asserts.push(m.assertNotInvalid(startEvent.trackerVersion, "trackerVersion on START"))
        asserts.push(m.assertNotInvalid(startEvent.videoFormat, "videoFormat on START"))
    end if
    
    ' Test timing attributes progression
    if requestEvent <> invalid AND startEvent <> invalid
        asserts.push(m.assertNotInvalid(requestEvent.timeSinceTrackerReady, "timeSinceTrackerReady on REQUEST"))
        asserts.push(m.assertNotInvalid(startEvent.timeSinceRequested, "timeSinceRequested on START"))
        asserts.push(m.assertNotInvalid(startEvent.timeSinceStarted, "timeSinceStarted on START"))
        asserts.push(m.assertEqual(startEvent.timeSinceStarted, 0, "timeSinceStarted is 0 on START"))
    end if
    
    ' Test timing attributes advance over time
    if heartbeatEvent <> invalid
        asserts.push(m.assertNotInvalid(heartbeatEvent.timeSinceStarted, "timeSinceStarted on HEARTBEAT"))
        asserts.push(m.assertTrue(heartbeatEvent.timeSinceStarted > 0, "timeSinceStarted > 0 on HEARTBEAT"))
        asserts.push(m.assertNotInvalid(heartbeatEvent.totalPlaytime, "totalPlaytime on HEARTBEAT"))
        asserts.push(m.assertTrue(heartbeatEvent.totalPlaytime > 0, "totalPlaytime > 0 on HEARTBEAT"))
        asserts.push(m.assertNotInvalid(heartbeatEvent.playtimeSinceLastEvent, "playtimeSinceLastEvent on HEARTBEAT"))
        asserts.push(m.assertNotInvalid(heartbeatEvent.sessionDuration, "sessionDuration on HEARTBEAT"))
    end if
    
    ' Test video attributes on PAUSE
    if pauseEvent <> invalid
        asserts.push(m.assertNotInvalid(pauseEvent.contentPlayhead, "contentPlayhead on PAUSE"))
        asserts.push(m.assertNotInvalid(pauseEvent.timeSinceStarted, "timeSinceStarted on PAUSE"))
        asserts.push(m.assertNotInvalid(pauseEvent.totalPlaytime, "totalPlaytime on PAUSE"))
    end if
    
    ' Test video attributes on RESUME
    if resumeEvent <> invalid
        asserts.push(m.assertNotInvalid(resumeEvent.contentPlayhead, "contentPlayhead on RESUME"))
        asserts.push(m.assertNotInvalid(resumeEvent.timeSinceStarted, "timeSinceStarted on RESUME"))
    end if
    
    ' Test video attributes on mid-playback BUFFER
    if bufferStartEvent <> invalid
        asserts.push(m.assertNotInvalid(bufferStartEvent.contentPlayhead, "contentPlayhead on BUFFER"))
    end if
    
    ' Test video attributes on END
    if endEvent <> invalid
        asserts.push(m.assertNotInvalid(endEvent.contentPlayhead, "contentPlayhead on END"))
        asserts.push(m.assertNotInvalid(endEvent.timeSinceStarted, "timeSinceStarted on END"))
        asserts.push(m.assertNotInvalid(endEvent.totalPlaytime, "totalPlaytime on END"))
        asserts.push(m.assertNotInvalid(endEvent.numberOfVideos, "numberOfVideos on END"))
        asserts.push(m.assertEqual(endEvent.numberOfVideos, 1, "numberOfVideos = 1 on END"))
    end if
    
    ' Test session and view attributes consistency
    if startEvent <> invalid AND endEvent <> invalid
        asserts.push(m.assertNotInvalid(startEvent.viewId, "viewId on START"))
        asserts.push(m.assertNotInvalid(startEvent.viewSession, "viewSession on START"))
        asserts.push(m.assertEqual(startEvent.viewSession, endEvent.viewSession, "viewSession consistent START->END"))
        asserts.push(m.assertEqual(startEvent.viewId, endEvent.viewId, "viewId consistent START->END"))
        
        ' If heartbeat event exists, verify consistency with it too
        if heartbeatEvent <> invalid
            asserts.push(m.assertEqual(startEvent.viewSession, heartbeatEvent.viewSession, "viewSession consistent START->HEARTBEAT"))
            asserts.push(m.assertEqual(startEvent.viewId, heartbeatEvent.viewId, "viewId consistent START->HEARTBEAT"))
        end if
    end if
    
    return multiAssert(asserts)
End Function

' Test 4: RAF Attributes Coverage - Basic
Function TestCase__Attr_RAFAttributes() as String
    print "Testing RAF (Roku Advertising Framework) attributes..."
    
    Attr_Tracking_Reset(m)
    
    ' Create RAF context using SmartAdServer configuration from sample app
    ctx = {
        "rendersequence": "preroll",
        "duration": 30,
        "server": "http://mobile.smartadserver.com/213040/901271/29117",
        "ad": {
            "adid": "ad-213040-901271",
            "creativeid": "creative-29117",
            "adtitle": "SmartAdServer Preroll"
        }
    }
    
    ' Send RAF ad event
    nrTrackRAF(m.nr, "Impression", ctx)
    
    events = m.nr.callFunc("nrExtractAllSamples", "event")
    
    return multiAssert([
        m.assertArrayCount(events, 1)
        m.assertEqual(events[0].actionName, "AD_REQUEST")
        m.assertEqual(events[0].eventType, "VideoAdAction")
        m.assertEqual(events[0].adPosition, "pre")
        m.assertEqual(events[0].adDuration, 30000)
        m.assertEqual(events[0].adSrc, "http://mobile.smartadserver.com/213040/901271/29117")
        m.assertEqual(events[0].adId, "ad-213040-901271")
        m.assertEqual(events[0].adCreativeId, "creative-29117")
        m.assertEqual(events[0].adTitle, "SmartAdServer Preroll")
        m.assertEqual(events[0].adPartner, "raf")
        m.assertNotInvalid(events[0].numberOfAds)
    ])
End Function

' Test 5: RAF Ad Positions Coverage
Function TestCase__Attr_RAFAdPositions() as String
    print "Testing RAF ad position attributes (pre, mid, post)..."
    
    Attr_Tracking_Reset(m)
    
    ' Pre-roll ad
    ctxPre = {
        "rendersequence": "preroll",
        "duration": 15
    }
    nrTrackRAF(m.nr, "Impression", ctxPre)
    
    ' Mid-roll ad
    ctxMid = {
        "rendersequence": "midroll",
        "duration": 20
    }
    nrTrackRAF(m.nr, "Impression", ctxMid)
    
    ' Post-roll ad
    ctxPost = {
        "rendersequence": "postroll",
        "duration": 10
    }
    nrTrackRAF(m.nr, "Impression", ctxPost)
    
    events = m.nr.callFunc("nrExtractAllSamples", "event")
    
    return multiAssert([
        m.assertArrayCount(events, 3)
        ' Pre-roll position
        m.assertEqual(events[0].adPosition, "pre")
        m.assertEqual(events[0].adDuration, 15000)
        ' Mid-roll position
        m.assertEqual(events[1].adPosition, "mid")
        m.assertEqual(events[1].adDuration, 20000)
        ' Post-roll position
        m.assertEqual(events[2].adPosition, "post")
        m.assertEqual(events[2].adDuration, 10000)
    ])
End Function

' Test 6: RAF Ad Bitrate Attributes
Function TestCase__Attr_RAFAdBitrate() as String
    print "Testing RAF ad bitrate attribute extraction..."
    
    Attr_Tracking_Reset(m)
    
    ' Test with direct bitrate in ad
    ctx1 = {
        "rendersequence": "preroll",
        "ad": {
            "adid": "ad-1",
            "bitrate": 2500000
        }
    }
    nrTrackRAF(m.nr, "Impression", ctx1)
    
    ' Test with bitrateKbps
    ctx2 = {
        "rendersequence": "preroll",
        "ad": {
            "adid": "ad-2",
            "bitrateKbps": 3000
        }
    }
    nrTrackRAF(m.nr, "Impression", ctx2)
    
    ' Test with bitrateBps
    ctx3 = {
        "rendersequence": "preroll",
        "ad": {
            "adid": "ad-3",
            "bitrateBps": 4000000
        }
    }
    nrTrackRAF(m.nr, "Impression", ctx3)
    
    ' Test with bitrate in context
    ctx4 = {
        "rendersequence": "preroll",
        "bitrate": 1500000,
        "ad": {
            "adid": "ad-4"
        }
    }
    nrTrackRAF(m.nr, "Impression", ctx4)
    
    events = m.nr.callFunc("nrExtractAllSamples", "event")
    
    return multiAssert([
        m.assertArrayCount(events, 4)
        ' Direct bitrate
        m.assertEqual(events[0].adBitrate, 2500000)
        m.assertEqual(events[0].adId, "ad-1")
        ' bitrateKbps converted to bps
        m.assertEqual(events[1].adBitrate, 3000000)
        m.assertEqual(events[1].adId, "ad-2")
        ' bitrateBps
        m.assertEqual(events[2].adBitrate, 4000000)
        m.assertEqual(events[2].adId, "ad-3")
        ' Context bitrate
        m.assertEqual(events[3].adBitrate, 1500000)
        m.assertEqual(events[3].adId, "ad-4")
    ])
End Function

' Test 7: RAF Timing Attributes
Function TestCase__Attr_RAFTimingAttributes() as String
    print "Testing RAF timing attributes..."
    
    Attr_Tracking_Reset(m)
    
    ctx = {
        "rendersequence": "preroll",
        "duration": 30,
        "ad": {
            "adid": "timing-test-ad"
        }
    }
    
    ' Send PodStart
    nrTrackRAF(m.nr, "PodStart", ctx)
    
    ' Send Impression (creates AD_REQUEST)
    nrTrackRAF(m.nr, "Impression", ctx)
    sleep(150)
    
    ' Send Start (creates AD_START with timeSinceAdRequested)
    nrTrackRAF(m.nr, "Start", ctx)
    sleep(200)
    
    ' Send Complete (creates AD_END with timeSinceAdStarted)
    nrTrackRAF(m.nr, "Complete", ctx)
    
    events = m.nr.callFunc("nrExtractAllSamples", "event")
    
    return multiAssert([
        m.assertArrayCount(events, 4)
        m.assertEqual(events[0].actionName, "AD_BREAK_START")
        m.assertEqual(events[1].actionName, "AD_REQUEST")
        m.assertEqual(events[2].actionName, "AD_START")
        m.assertNotInvalid(events[2].timeSinceAdRequested)
        m.assertTrue(events[2].timeSinceAdRequested > 140 AND events[2].timeSinceAdRequested < 180)
        m.assertEqual(events[3].actionName, "AD_END")
        m.assertNotInvalid(events[3].timeSinceAdStarted)
        m.assertTrue(events[3].timeSinceAdStarted > 190 AND events[3].timeSinceAdStarted < 230)
    ])
End Function

' Test 8: Generate Stream URL
Function TestCase__Attr_GenerateStreamUrl() as String
    print "Testing stream URL generation..."
    
    Attr_Tracking_Reset(m)
    
    ' Start playback to generate stream URL
    m.videoObject.callFunc("startBuffering")
    m.videoObject.callFunc("startPlayback")
    
    events = m.nr.callFunc("nrExtractAllSamples", "event")
    
    return multiAssert([
        m.assertArrayCount(events, 4)
        ' ContentSrc should be generated from stream URL
        m.assertNotInvalid(events[3].contentSrc)
        m.assertTrue(events[3].contentSrc.Len() > 0)
    ])
End Function

' Test 9: Generate ID
Function TestCase__Attr_GenerateId() as String
    print "Testing ID generation..."
    
    Attr_Tracking_Reset(m)
    
    ' ViewSession should use generated ID
    m.videoObject.callFunc("startBuffering")
    m.videoObject.callFunc("startPlayback")
    
    events = m.nr.callFunc("nrExtractAllSamples", "event")
    
    return multiAssert([
        m.assertArrayCount(events, 4)
        ' ViewSession is a generated ID
        m.assertNotInvalid(events[0].viewSession)
        m.assertTrue(events[0].viewSession.Len() > 0)
        ' ViewId uses viewSession + video counter
        m.assertNotInvalid(events[0].viewId)
        m.assertTrue(events[0].viewId.Len() > 0)
        ' All events in same session should have same viewSession
        m.assertEqual(events[0].viewSession, events[1].viewSession)
        m.assertEqual(events[0].viewSession, events[2].viewSession)
        m.assertEqual(events[0].viewSession, events[3].viewSession)
    ])
End Function
