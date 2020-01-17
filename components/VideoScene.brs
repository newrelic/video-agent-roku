'NR Video Agent Example - Video'

sub init()
    print "INIT VideoScene"
    m.top.setFocus(true)
end sub

function nrRefUpdated()
    print "Updated NR object reference"
    m.nr = m.top.getField("nr")
    NewRelicStart(m.nr)
end function

sub x_init()
    m.top.setFocus(true)
    
    'Setup video player with a playlist
    setupVideoPlaylist()
    'setupVideoPlaylistShort()
    'Setup video player with a single video
    'setupVideo()
    
    'Start New Relic agents
    NewRelicStart()
    NewRelicVideoStart(m.video)
    
    m.pauseCounter = 0
    updateCustomAttr()
    
    nrSceneLoaded("MyVideoScene")
end sub

function updateCustomAttr() as Void
    nrSetCustomAttribute("customGeneralString", "Value")
    nrSetCustomAttribute("customGeneralNumber", 123)
    nrSetCustomAttribute("customNumPause", m.pauseCounter, "CONTENT_PAUSE")
    dict = {"key0":"val0", "key1":"val1"}
    nrSetCustomAttributeList(dict, "CONTENT_HEARTBEAT")
end function

function setupVideo() as void
    print "Prepare video player with single video"
    
    'singleVideo = "https://ext.inisoft.tv/demo/BBB_clear/dash_ondemand/demo.mpd"
    singleVideo = "http://yt-dash-mse-test.commondatastorage.googleapis.com/media/car-20120827-manifest.mpd"
    
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
    'hls0 = "https://bitmovin-a.akamaihd.net/content/playhouse-vr/m3u8s/105560.m3u8"
    hls1 = "https://bitdash-a.akamaihd.net/content/MI201109210084_1/m3u8s/f08e80da-bf1d-4e3d-8899-f0f6155f6efa.m3u8"
    dash = "http://yt-dash-mse-test.commondatastorage.googleapis.com/media/car-20120827-manifest.mpd"

    playlistContent = createObject("RoSGNode", "ContentNode")
    
    httprangeContent = createObject("RoSGNode", "ContentNode")
    httprangeContent.url = httprange
    httprangeContent.title = "HTTP Range"
    playlistContent.appendChild(httprangeContent)
    
    'hls0Content = createObject("RoSGNode", "ContentNode")
    'hls0Content.url = hls0
    'hls0Content.title = "HLS 0"
    'playlistContent.appendChild(hls0Content)
    
    hls1Content = createObject("RoSGNode", "ContentNode")
    hls1Content.url = hls1
    hls1Content.title = "HLS 1"
    playlistContent.appendChild(hls1Content)
    
    dashContent = createObject("RoSGNode", "ContentNode")
    dashContent.url = dash
    dashContent.title = "DASH"
    playlistContent.appendChild(dashContent)
    
    m.video = m.top.findNode("myVideo")
    m.video.content = playlistContent
    m.video.contentIsPlaylist = True
    m.video.control = "play"
end function

function setupVideoPlaylistShort() as void
    print "Prepare video player with Playlist Short"

    httprange1 = "http://mirrors.standaloneinstaller.com/video-sample/jellyfish-25-mbps-hd-hevc.m4v"
    httprange2 = "http://mirrors.standaloneinstaller.com/video-sample/jellyfish-25-mbps-hd-hevc.m4v"
    httprange3 = "http://mirrors.standaloneinstaller.com/video-sample/jellyfish-25-mbps-hd-hevc.m4v"

    playlistContent = createObject("RoSGNode", "ContentNode")
    
    httprangeContent1 = createObject("RoSGNode", "ContentNode")
    httprangeContent1.url = httprange1
    httprangeContent1.title = "HTTP Range 1"
    playlistContent.appendChild(httprangeContent1)
    
    httprangeContent2 = createObject("RoSGNode", "ContentNode")
    httprangeContent2.url = httprange2
    httprangeContent2.title = "HTTP Range 2"
    playlistContent.appendChild(httprangeContent2)
    
    httprangeContent3 = createObject("RoSGNode", "ContentNode")
    httprangeContent3.url = httprange3
    httprangeContent3.title = "HTTP Range"
    playlistContent.appendChild(httprangeContent3)
    
    m.video = m.top.findNode("myVideo")
    m.video.content = playlistContent
    m.video.contentIsPlaylist = True
    m.video.control = "play"
end function

function videoAction(key as String) as Boolean
    if key = "replay"
        m.video.control = "replay"
        return true
    else if key = "play"
        if m.video.state = "playing"
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
        'Cusom event, Skip Content
        nrSendVideoEvent("SKIP_CONTENT")
        return true
    else if key = "left"
        if m.video.contentIndex > 0
            m.video.nextContentIndex = m.video.contentIndex - 1
            m.video.control = "skipcontent"
            'Cusom event, Previous Content
            nrSendVideoEvent("PREV_CONTENT")
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
