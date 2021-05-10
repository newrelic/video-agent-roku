'NR Video Agent Example - Video'

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
    'setupSingleVideo()
    
    'Setup the video player with a playlist
    'setupVideoPlaylist()
    
    'Setup the video player with a single video and ads
    'setupVideoWithAds()
    
    'Setup the video player with a single video and Google IMA ads
    setupVideoWithIMA()
    
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
    
    singleVideo = "https://bitdash-a.akamaihd.net/content/MI201109210084_1/m3u8s/f08e80da-bf1d-4e3d-8899-f0f6155f6efa.m3u8"
    
    videoContent = createObject("RoSGNode", "ContentNode")
    videoContent.url = singleVideo
    videoContent.title = "Single Video"
    
    m.video = m.top.findNode("myVideo")
    m.video.content = videoContent
    m.video.control = "play"
end function

function setupVideoPlaylist() as void
    print "Prepare video player with Playlist"

    httprange = "http://mirrors.standaloneinstaller.com/video-sample/jellyfish-25-mbps-hd-hevc.m4v"
    hls = "https://bitdash-a.akamaihd.net/content/MI201109210084_1/m3u8s/f08e80da-bf1d-4e3d-8899-f0f6155f6efa.m3u8"
    dash = "http://yt-dash-mse-test.commondatastorage.googleapis.com/media/car-20120827-manifest.mpd"

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
end function

function setupVideoWithAds() as void
    print "Prepare video player with ads"
    
    singleVideo = "https://bitdash-a.akamaihd.net/content/MI201109210084_1/m3u8s/f08e80da-bf1d-4e3d-8899-f0f6155f6efa.m3u8"
    
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
  m.video.setFocus(true)
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
