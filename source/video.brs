'NR Video Agent Example - Video'

sub init()
    m.top.setFocus(true)
    setVideo()
end sub

function setVideo() as void
    print "Prepare video"

    videoContent = createObject("RoSGNode", "ContentNode")

    jelly = "http://mirrors.standaloneinstaller.com/video-sample/jellyfish-25-mbps-hd-hevc.m4v"
    pana = "http://mirrors.standaloneinstaller.com/video-sample/Panasonic_HDC_TM_700_P_50i.m4v"
    bunny = "https://www.quirksmode.org/html5/videos/big_buck_bunny.mp4"

    videoContent.url = jelly
    videoContent.title = "Video Test"
    
    m.video = m.top.findNode("myVideo")
    m.video.content = videoContent
    'm.video.control = "play"
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
