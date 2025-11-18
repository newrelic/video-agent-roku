Function TestSuite__IMATracker() as Object
    ' Test suite for IMA (Google Interactive Media Ads) video tracker
    this = BaseTestSuite()
    this.Name = "IMATrackerTestSuite"

    this.SetUp = IMATrackerTestSuite__SetUp
    this.TearDown = IMATrackerTestSuite__TearDown

    ' Add IMA tracker tests
    this.addTest("IMAAdBreakLifecycle", TestCase__IMA_AdBreakLifecycle)
    this.addTest("IMAAdQuartiles", TestCase__IMA_AdQuartiles)
    this.addTest("IMAAdAttributes", TestCase__IMA_AdAttributes)
    this.addTest("IMAAdPositioning", TestCase__IMA_AdPositioning)
    this.addTest("IMAMultipleAds", TestCase__IMA_MultipleAds)
    this.addTest("IMAAdError", TestCase__IMA_AdError)
    this.addTest("IMAAdTiming", TestCase__IMA_AdTiming)

    return this
End Function

Sub IMATrackerTestSuite__SetUp()
    print "IMA Tracker SetUp"
    ' Setup New Relic Agent
    if m.nr = invalid
        m.nr = NewRelic("ACCOUNT_ID", "API_KEY", "TestApp", "", "US", true)
    end if
    ' Disable harvest timers
    nrHarvestTimerEvents = m.nr.findNode("nrHarvestTimerEvents")
    nrHarvestTimerEvents.control = "stop"
    
    ' Create IMA Tracker
    m.imaTracker = CreateObject("roSGNode", "com.newrelic.IMATracker")
    m.imaTracker.nr = m.nr
    
    ' Create Dummy Video object
    ' Note: In production, use Google IMA SDK with stream data:
    ' VOD: contentSourceId="2528370", videoId="tears-of-steel"
    ' Live: assetKey="sN_IYUG8STe1ZzhIIE_ksA"
    m.videoObject = CreateObject("roSGNode", "com.newrelic.test.DummyVideo")
    videoContent = createObject("RoSGNode", "ContentNode")
    videoContent.url = "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8"
    videoContent.title = "Single Video"
    m.videoObject.content = videoContent
    
    NewRelicVideoStart(m.nr, m.videoObject)
    ' Clear initial events
    m.nr.callFunc("nrExtractAllSamples", "event")
End Sub

Sub IMATrackerTestSuite__TearDown()
    print "IMA Tracker TearDown"
    if m.nr <> invalid
        NewRelicVideoStop(m.nr)
    end if
End Sub

' Test 1: IMA Ad Break Lifecycle
Function TestCase__IMA_AdBreakLifecycle() as String
    print "Testing IMA ad break lifecycle..."
    
    ' Create ad break info
    adBreakInfo = {
        "podindex": 0,
        "timeoffset": 0
    }
    
    ' Send ad break start
    m.imaTracker.callFunc("nrSendIMAAdBreakStart", adBreakInfo)
    sleep(500)
    
    ' Send ad break end
    m.imaTracker.callFunc("nrSendIMAAdBreakEnd", adBreakInfo)
    
    events = m.nr.callFunc("nrExtractAllSamples", "event")
    
    return multiAssert([
        m.assertArrayCount(events, 2)
        m.assertEqual(events[0].actionName, "AD_BREAK_START")
        m.assertEqual(events[0].eventType, "VideoAction")
        m.assertEqual(events[0].adPosition, "pre")
        m.assertEqual(events[0].contentPosition, 0)
        m.assertEqual(events[1].actionName, "AD_BREAK_END")
        m.assertNotInvalid(events[1].timeSinceAdBreakBegin)
        m.assertTrue(events[1].timeSinceAdBreakBegin > 500 AND events[1].timeSinceAdBreakBegin < 600)
    ])
End Function

' Test 2: IMA Ad Quartiles
Function TestCase__IMA_AdQuartiles() as String
    print "Testing IMA ad quartile events..."
    
    ' Create ad break info and ad
    adBreakInfo = {
        "podindex": 0,
        "timeoffset": 0
    }
    
    ad = {
        "adBreakInfo": adBreakInfo,
        "duration": 30,
        "adid": "test-ad-123",
        "adtitle": "Test Ad",
        "adsystem": "Test Ad System"
    }
    
    ' Send ad start
    m.imaTracker.callFunc("nrSendIMAAdStart", ad)
    
    ' Send quartile events
    sleep(100)
    m.imaTracker.callFunc("nrSendIMAAdFirstQuartile", ad)
    sleep(100)
    m.imaTracker.callFunc("nrSendIMAAdMidpoint", ad)
    sleep(100)
    m.imaTracker.callFunc("nrSendIMAAdThirdQuartile", ad)
    sleep(100)
    
    ' Send ad end
    m.imaTracker.callFunc("nrSendIMAAdEnd", ad)
    
    events = m.nr.callFunc("nrExtractAllSamples", "event")
    
    return multiAssert([
        m.assertArrayCount(events, 5)
        m.assertEqual(events[0].actionName, "AD_START")
        m.assertEqual(events[1].actionName, "AD_QUARTILE")
        m.assertEqual(events[1].adQuartile, 1)
        m.assertEqual(events[2].actionName, "AD_QUARTILE")
        m.assertEqual(events[2].adQuartile, 2)
        m.assertEqual(events[3].actionName, "AD_QUARTILE")
        m.assertEqual(events[3].adQuartile, 3)
        m.assertEqual(events[4].actionName, "AD_END")
    ])
End Function

' Test 3: IMA Ad Attributes
Function TestCase__IMA_AdAttributes() as String
    print "Testing IMA ad attributes..."
    
    adBreakInfo = {
        "podindex": 1,
        "timeoffset": 300
    }
    
    ad = {
        "adBreakInfo": adBreakInfo,
        "duration": 15,
        "adid": "ad-456",
        "adtitle": "Mid-roll Ad",
        "adsystem": "Google IMA"
    }
    
    m.imaTracker.callFunc("nrSendIMAAdStart", ad)
    
    events = m.nr.callFunc("nrExtractAllSamples", "event")
    
    return multiAssert([
        m.assertArrayCount(events, 1)
        m.assertEqual(events[0].actionName, "AD_START")
        m.assertEqual(events[0].adDuration, 15000)
        m.assertEqual(events[0].adId, "ad-456")
        m.assertEqual(events[0].adTitle, "Mid-roll Ad")
        m.assertEqual(events[0].adSystem, "Google IMA")
        m.assertEqual(events[0].adPosition, "mid")
        m.assertEqual(events[0].contentPosition, 300000)
        m.assertEqual(events[0].numberOfAds, 1)
    ])
End Function

' Test 4: IMA Ad Positioning
Function TestCase__IMA_AdPositioning() as String
    print "Testing IMA ad positioning (pre, mid, live)..."
    
    ' Pre-roll ad (podindex = 0)
    prerollBreak = {
        "podindex": 0,
        "timeoffset": 0
    }
    m.imaTracker.callFunc("nrSendIMAAdBreakStart", prerollBreak)
    
    ' Mid-roll ad (podindex > 0)
    midrollBreak = {
        "podindex": 1,
        "timeoffset": 600
    }
    m.imaTracker.callFunc("nrSendIMAAdBreakStart", midrollBreak)
    
    ' Live ad (podindex < 0)
    liveBreak = {
        "podindex": -1,
        "timeoffset": 0
    }
    m.imaTracker.callFunc("nrSendIMAAdBreakStart", liveBreak)
    
    events = m.nr.callFunc("nrExtractAllSamples", "event")
    
    return multiAssert([
        m.assertArrayCount(events, 3)
        m.assertEqual(events[0].adPosition, "pre")
        m.assertEqual(events[0].contentPosition, 0)
        m.assertEqual(events[1].adPosition, "mid")
        m.assertEqual(events[1].contentPosition, 600000)
        m.assertEqual(events[2].adPosition, "live")
    ])
End Function

' Test 5: IMA Multiple Ads in Ad Break
Function TestCase__IMA_MultipleAds() as String
    print "Testing IMA multiple ads in ad break..."
    
    adBreakInfo = {
        "podindex": 0,
        "timeoffset": 0
    }
    
    ' Start ad break
    m.imaTracker.callFunc("nrSendIMAAdBreakStart", adBreakInfo)
    
    ' First ad
    ad1 = {
        "adBreakInfo": adBreakInfo,
        "duration": 15,
        "adid": "ad-1",
        "adtitle": "First Ad",
        "adsystem": "IMA"
    }
    m.imaTracker.callFunc("nrSendIMAAdStart", ad1)
    sleep(100)
    m.imaTracker.callFunc("nrSendIMAAdEnd", ad1)
    
    ' Second ad
    ad2 = {
        "adBreakInfo": adBreakInfo,
        "duration": 20,
        "adid": "ad-2",
        "adtitle": "Second Ad",
        "adsystem": "IMA"
    }
    m.imaTracker.callFunc("nrSendIMAAdStart", ad2)
    sleep(100)
    m.imaTracker.callFunc("nrSendIMAAdEnd", ad2)
    
    ' End ad break
    m.imaTracker.callFunc("nrSendIMAAdBreakEnd", adBreakInfo)
    
    events = m.nr.callFunc("nrExtractAllSamples", "event")
    
    return multiAssert([
        m.assertArrayCount(events, 6)
        m.assertEqual(events[0].actionName, "AD_BREAK_START")
        m.assertEqual(events[1].actionName, "AD_START")
        m.assertEqual(events[1].numberOfAds, 1)
        m.assertEqual(events[2].actionName, "AD_END")
        m.assertEqual(events[3].actionName, "AD_START")
        m.assertEqual(events[3].numberOfAds, 2)
        m.assertEqual(events[4].actionName, "AD_END")
        m.assertEqual(events[5].actionName, "AD_BREAK_END")
    ])
End Function

' Test 6: IMA Ad Error
Function TestCase__IMA_AdError() as String
    print "Testing IMA ad error handling..."
    
    error = {
        "id": 1001,
        "info": "Ad failed to load",
        "type": "network"
    }
    
    m.imaTracker.callFunc("nrSendIMAAdError", error)
    
    events = m.nr.callFunc("nrExtractAllSamples", "event")
    
    return multiAssert([
        m.assertArrayCount(events, 1)
        m.assertEqual(events[0].actionName, "AD_ERROR")
        m.assertEqual(events[0].eventType, "VideoAction")
        m.assertEqual(events[0].adErrorCode, 1001)
        m.assertEqual(events[0].adErrorMsg, "Ad failed to load")
        m.assertEqual(events[0].adErrorType, "network")
    ])
End Function

' Test 7: IMA Ad Timing Attributes
Function TestCase__IMA_AdTiming() as String
    print "Testing IMA ad timing attributes..."
    
    adBreakInfo = {
        "podindex": 0,
        "timeoffset": 0
    }
    
    ad = {
        "adBreakInfo": adBreakInfo,
        "duration": 30,
        "adid": "test-ad",
        "adtitle": "Test Ad",
        "adsystem": "IMA"
    }
    
    ' Start ad
    m.imaTracker.callFunc("nrSendIMAAdStart", ad)
    sleep(250)
    
    ' Send quartile with timing
    m.imaTracker.callFunc("nrSendIMAAdFirstQuartile", ad)
    
    events = m.nr.callFunc("nrExtractAllSamples", "event")
    
    return multiAssert([
        m.assertArrayCount(events, 2)
        m.assertEqual(events[0].actionName, "AD_START")
        m.assertEqual(events[1].actionName, "AD_QUARTILE")
        m.assertNotInvalid(events[1].timeSinceAdStarted)
        m.assertTrue(events[1].timeSinceAdStarted > 250 AND events[1].timeSinceAdStarted < 300)
    ])
End Function
