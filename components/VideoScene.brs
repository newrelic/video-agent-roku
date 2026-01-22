'NR Video Agent Ex    'NOTE: Uncomment ONE of the following setup calls

    'Setup the video player with a single video
    ' setupSingleVideo()

    'Setup the video player with a playlist
    'setupVideoPlaylist(true)

    'Setup the video player with a single video and ads
    ' setupVideoWithAds()

    'Setup the video player with a single video and Google IMA ads
    ' setupVideoWithIMA()

sub init()
    print "INIT VideoScene"
    m.top.setFocus(true)
end sub

function nrRefUpdated()
    print "Updated NR object reference"
    m.nr = m.top.nr

    'Init custom attributes
    m.pauseCounter = 0
   updateCustomAttr()

    'Send SCENE_LOADED action
    nrSceneLoaded(m.nr, "MyVideoScene")

    'NOTE: Uncomment ONE of the following setup calls

    'Setup the video player with a single video
    setupSingleVideo()

    'Setup the video player with a playlist
    ' setupVideoPlaylist(true)

    'Setup the video player with a single video and ads
    ' setupVideoWithAds()

    'Setup the video player with a single video and Google IMA ads
    ' setupVideoWithIMA()

    'Activate video tracking
    NewRelicVideoStart(m.nr, m.video)
end function

'Set custom attributes
function updateCustomAttr() as Void
    'Set custom attribute of type string to all action
    nrSetCustomAttribute(m.nr, "customGeneralString", "Value")
    'Set custom attribute of type integer to all action
    nrSetCustomAttribute(m.nr, "customGeneralNumber", 123)
    'Set custom attribute of type integer to CONTENT_PAUSE actions
    nrSetCustomAttribute(m.nr, "customNumPause", m.pauseCounter, "CONTENT_PAUSE")
    'Set a list of custom attributes to CONTENT_HEARTBEAT actions
    dict = {"key0":"val0", "key1":"val1"}
    nrSetCustomAttributeList(m.nr, dict, "CONTENT_HEARTBEAT")
end function

function setupSingleVideo() as void
    print "Prepare video player with single video"

    m.video = m.top.findNode("myVideo")

    ' Observe video state to detect when video finishes
    m.video.observeField("state", "onVideoStateChange")

    ' Load Video 3 directly for replay testing
    videoUrl = "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8"
    videoContent = createObject("RoSGNode", "ContentNode")
    videoContent.url = videoUrl
    videoContent.title = "Video 3 - Mux Test Stream"
    videoContent.description = "Test video for replay testing"
    m.video.content = videoContent
    m.video.control = "play"
    print "[DEBUG] Video 3 loaded: " + videoUrl

    ' ' Commented out: Multiple video testing code
    ' ' Initialize video player with null/empty content
    ' m.videoCounter = 1  ' Track which video we're loading
    ' videoContent = createObject("RoSGNode", "ContentNode")
    ' videoContent.url = ""
    ' m.video.content = videoContent
    ' m.video.control = "play"
    '
    ' ' After 20 seconds, load the first video
    ' timer20 = createObject("roSGNode", "Timer")
    ' timer20.duration = 20
    ' timer20.control = "start"
    ' timer20.observeField("fire", "onLoadVideo1")
    ' m.top.appendChild(timer20)
    '
    ' ' After 50 seconds, switch to second video (to test multiple viewIds)
    ' timer50 = createObject("roSGNode", "Timer")
    ' timer50.duration = 50
    ' timer50.control = "start"
    ' timer50.observeField("fire", "onLoadVideo2")
    ' m.top.appendChild(timer50)
    '
    ' ' After 80 seconds, switch to third video
    ' timer80 = createObject("roSGNode", "Timer")
    ' timer80.duration = 80
    ' timer80.control = "start"
    ' timer80.observeField("fire", " ")
    ' m.top.appendChild(timer80)
end function

' Handler to load first video after 20 seconds
sub onLoadVideo1()
    print "[DEBUG] ===== LOADING VIDEO 1 after 20 seconds ====="
    print "[DEBUG] This will create viewId: sessionId-0"

    videoUrl = "https://dash.akamaized.net/akamai/bbb_30fps/bbb_30fps.mpd"

    m.video = m.top.findNode("myVideo")
    if m.video <> invalid
        videoContent = createObject("RoSGNode", "ContentNode")
        videoContent.url = videoUrl
        videoContent.title = "Video 1 - Big Buck Bunny"
        videoContent.description = "First video - viewId will be sessionId-0"
        m.video.content = videoContent
        m.video.control = "play"
        print "[DEBUG] Video 1 loaded: " + videoUrl
    else
        print "[ERROR] Video node is invalid"
    end if
end sub

' Handler to load second video after 50 seconds
sub onLoadVideo2()
    print "[DEBUG] ===== LOADING VIDEO 2 after 50 seconds ====="
    print "[DEBUG] This will create viewId: sessionId-1 (same viewSession)"

    m.video = m.top.findNode("myVideo")
    if m.video <> invalid
        ' CRITICAL: Stop the current video first to trigger CONTENT_END
        ' This ensures nrVideoCounter increments before loading new content
        m.video.control = "stop"
        print "[DEBUG] Stopped Video 1 - CONTENT_END will be sent"

        ' Small delay to ensure CONTENT_END is processed
        ' In production, you might observe video state instead
        sleep(100)  ' 100ms delay

        ' Now load the new video
        videoUrl = "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8"
        videoContent = createObject("RoSGNode", "ContentNode")
        videoContent.url = videoUrl
        videoContent.title = "Video 2 - Apple Test Stream"
        videoContent.description = "Second video - viewId will be sessionId-1"
        m.video.content = videoContent
        m.video.control = "play"
        print "[DEBUG] Video 2 loaded: " + videoUrl
    else
        print "[ERROR] Video node is invalid"
    end if
end sub

' Handler to load third video after 80 seconds
sub onLoadVideo3()
    print "[DEBUG] ===== LOADING VIDEO 3 after 80 seconds ====="
    print "[DEBUG] This will create viewId: sessionId-2 (same viewSession)"

    m.video = m.top.findNode("myVideo")
    if m.video <> invalid
        ' CRITICAL: Stop the current video first to trigger CONTENT_END
        m.video.control = "stop"
        print "[DEBUG] Stopped Video 2 - CONTENT_END will be sent"

        ' Small delay to ensure CONTENT_END is processed
        sleep(100)  ' 100ms delay

        ' Now load the new video
        videoUrl = "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8"
        videoContent = createObject("RoSGNode", "ContentNode")
        videoContent.url = videoUrl
        videoContent.title = "Video 3 - Mux Test Stream"
        videoContent.description = "Third video - viewId will be sessionId-2"
        m.video.content = videoContent
        m.video.control = "play"
        print "[DEBUG] Video 3 loaded: " + videoUrl
    else
        print "[ERROR] Video node is invalid"
    end if
end sub

' Handler to detect when video finishes and trigger replay
sub onVideoStateChange()
    videoState = m.video.state
    print "[DEBUG] Video state changed to: " + videoState

    if videoState = "finished"
        print "[DEBUG] ===== VIDEO FINISHED - Triggering REPLAY ====="
        ' Stop the video to trigger CONTENT_END
        m.video.control = "stop"
        print "[DEBUG] Stopped video - CONTENT_END will be sent"

        ' Small delay to allow CONTENT_END to be processed
        sleep(50)  ' 50ms minimal delay

        ' Reload the same content to trigger replay
        videoUrl = "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8"
        videoContent = createObject("RoSGNode", "ContentNode")
        videoContent.url = videoUrl
        videoContent.title = "Video 3 - Mux Test Stream (Replay)"
        videoContent.description = "Replayed video for T-8 testing"

        m.video.content = videoContent
        m.video.control = "play"

        print "[DEBUG] Video reloaded for replay"
    end if
end sub

function setupVideoPlaylist(loop as boolean) as void
    print "Prepare video player with Playlist"

    'Working test video URLs
    hls = "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8"
    dash = "https://dash.akamaized.net/akamai/bbb_30fps/bbb_30fps.mpd"

    playlistContent = createObject("RoSGNode", "ContentNode")

    hlsContent = createObject("RoSGNode", "ContentNode")
    hlsContent.url = hls
    hlsContent.title = "HLS"
    playlistContent.appendChild(hlsContent)

    dashContent = createObject("RoSGNode", "ContentNode")
    dashContent.url = dash
    dashContent.title = "DASH"
    playlistContent.appendChild(dashContent)

    m.video = m.top.findNode("myVideo")
    m.video.content = playlistContent
    m.video.contentIsPlaylist = True
    m.video.control = "play"
    m.video.loop = loop
end function

function setupVideoWithAds() as void
    print "Prepare video player with ads"

    singleVideo = "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8"

    videoContent = createObject("RoSGNode", "ContentNode")
    videoContent.url = singleVideo
    videoContent.title = "Single Video"

    m.video = m.top.findNode("myVideo")
    m.video.content = videoContent

    m.adstask = createObject("roSGNode", "AdsTask")
    m.adstask.setField("videoNode", m.video)
    m.adstask.setField("nr", m.nr)
    m.adstask.control = "RUN"
end function

function setupVideoWithIMA() as Void
    m.video = m.top.findNode("myVideo")
    m.video.notificationinterval = 1

    testLiveStream = {
        title: "Live Stream",
        assetKey: "sN_IYUG8STe1ZzhIIE_ksA",
        apiKey: "",
        type: "live"
    }
    testVodStream = {
        title: "VOD stream"
        contentSourceId: "2528370",
        videoId: "tears-of-steel",
        apiKey: "",
        type: "vod"
    }



    loadImaSdk(testVodStream)
end function

function videoAction(key as String) as Boolean
    if key = "replay"
        m.video.control = "replay"
        return true
    else if key = "play"
        if m.video.state = "playing"
            'Increment the value of the custom attribute pauseCounter
            m.pauseCounter = m.pauseCounter + 1
            updateCustomAttr()
            m.video.control = "pause"
            return true
        else if m.video.state = "paused"
            m.video.control = "resume"
            return true
        else
            m.video.control = "play"
            return true
        end if
    else if key = "fastforward"
        m.video.seek = m.video.position + 10
        return true
    else if key = "rewind"
        m.video.seek = m.video.position - 10
        return true
    else if key = "right"
        m.video.control = "skipcontent"
        'Send custom video event, Skip Content
        nrSendVideoEvent(m.nr, "SKIP_CONTENT")
        return true
    else if key = "left"
        if m.video.contentIndex > 0
            m.video.nextContentIndex = m.video.contentIndex - 1
            m.video.control = "skipcontent"
            'Send custom video event, Previous Content
            nrSendVideoEvent(m.nr, "PREV_CONTENT")
        end if
        return true
    else if key = "back"
        print "BACK BUTTON PRESSED, QUIT"
        return true
    else if key = "OK"
        print "OK BUTTON PRESSED, QUIT"
        return true
    end if
    return false
end function

function onKeyEvent(key as String, press as Boolean) as Boolean
    if press = True
        print "Key Press --> " key
        ret = videoAction(key)
        'Send button to message port
        m.top.setField("moteButton", key)
        return ret
    else
        print "Key Release --> " key
        return false
    end if
end function

'Google IMA functions

function loadImaSdk(testStream as Object) as void
  m.sdkTask = createObject("roSGNode", "imasdk")
  'Pass IMA Tracker object
  m.sdkTask.setField("tracker", IMATracker(m.nr))
  m.sdkTask.observeField("sdkLoaded", "onSdkLoaded")
  m.sdkTask.observeField("errors", "onSdkLoadedError")

  selectedStream = testStream
  m.videoTitle = selectedStream.title
  m.sdkTask.streamData = selectedStream

  m.sdkTask.observeField("urlData", "urlLoadRequested")
  m.sdkTask.video = m.video
  m.sdkTask.control = "RUN"
end function

Sub urlLoadRequested(message as Object)
  print "Url Load Requested ";message
  data = message.getData()

  playStream(data.manifest)
End Sub

Sub playStream(url as Object)
  vidContent = createObject("RoSGNode", "ContentNode")
  vidContent.url = url
  vidContent.title = m.videoTitle
  vidContent.streamformat = "hls"
  m.video.content = vidContent
  m.video.visible = true
  m.video.control = "play"
  m.video.EnableCookies()
End Sub

Sub onSdkLoaded(message as Object)
  print "----- onSdkLoaded --- control ";message
End Sub

Sub onSdkLoadedError(message as Object)
  print "----- errors in the sdk loading process --- ";message
End Sub