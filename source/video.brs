'NR Video Agent Example - Video'

sub init()
    m.top.setFocus(true)
    'Setup video player
    setupVideoPlaylist()
    'Start New Relic agents
    NewRelicStart("1567277","4SxMEHFjPjZ-M7Do8Tt_M0YaTqwf4dTl")
    NewRelicVideoStart(m.video)
end sub

function setupVideo() as void
    print "Prepare video player with single video"

    jelly = "http://mirrors.standaloneinstaller.com/video-sample/jellyfish-25-mbps-hd-hevc.m4v"
    bunny = "https://www.quirksmode.org/html5/videos/big_buck_bunny.mp4"
    hls = "https://bitdash-a.akamaihd.net/content/MI201109210084_1/m3u8s/f08e80da-bf1d-4e3d-8899-f0f6155f6efa.m3u8"
    dash = "http://yt-dash-mse-test.commondatastorage.googleapis.com/media/car-20120827-manifest.mpd"
    
    jellyContent = createObject("RoSGNode", "ContentNode")
    jellyContent.url = jelly
    jellyContent.title = "Jelly"
    
    bunnyContent = createObject("RoSGNode", "ContentNode")
    bunnyContent.url = bunny
    bunnyContent.title = "Bunny"
    
    hlsContent = createObject("RoSGNode", "ContentNode")
    hlsContent.url = hls
    hlsContent.title = "HLS"
    
    dashContent = createObject("RoSGNode", "ContentNode")
    dashContent.url = dash
    dashContent.title = "DASH"
    
    m.video = m.top.findNode("myVideo")
    m.video.content = dashContent
    m.video.control = "play"
end function

function setupVideoPlaylist() as void
    print "Prepare video player with Playlist"

    jelly = "http://mirrors.standaloneinstaller.com/video-sample/jellyfish-25-mbps-hd-hevc.m4v"
    bunny = "https://www.quirksmode.org/html5/videos/big_buck_bunny.mp4"
    hls = "https://bitdash-a.akamaihd.net/content/MI201109210084_1/m3u8s/f08e80da-bf1d-4e3d-8899-f0f6155f6efa.m3u8"
    dash = "http://yt-dash-mse-test.commondatastorage.googleapis.com/media/car-20120827-manifest.mpd"

    playlistContent = createObject("RoSGNode", "ContentNode")
    
    jellyContent = createObject("RoSGNode", "ContentNode")
    jellyContent.url = jelly
    jellyContent.title = "Jelly"
    playlistContent.appendChild(jellyContent)
    
    bunnyContent = createObject("RoSGNode", "ContentNode")
    bunnyContent.url = bunny
    bunnyContent.title = "Bunny"
    playlistContent.appendChild(bunnyContent)
    
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

function videoAction(key as String) as Boolean
    if key = "replay"
        m.video.control = "replay"
        return true
    else if key = "play"
        if m.video.state = "playing"
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
        return true
    else if key = "left"
        if m.video.contentIndex > 0
            m.video.nextContentIndex = m.video.contentIndex - 1
            m.video.control = "skipcontent"
        end if
        return true
    end if
    return false
end function

function onKeyEvent(key as String, press as Boolean) as Boolean
    if press = True
        print "Key Press --> " key
        return videoAction(key)
    else
        'print "Key Release --> " key
        return false
    end if
end function
