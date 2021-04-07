'NR Video Agent Example - Video'

sub init()
    print "INIT VideoScene"
    m.top.setFocus(true)
    
    'Setup the video player with a single video
    'setupSingleVideo()
    
    'Setup the video player with a playlist
    'setupVideoPlaylist()
    
    'Setup the video player with a single video and ads
    setupVideoWithAds()
end sub

function nrRefUpdated()
    print "Updated NR object reference"
    m.nr = m.top.nr
    
    'Init custom attributes
    m.pauseCounter = 0
    updateCustomAttr()
    
    'Send SCENE_LOADED action
    nrSceneLoaded(m.nr, "MyVideoScene")
    
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
    m.adstask.control = "RUN"
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
