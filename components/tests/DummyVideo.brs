sub init()
    print "Init DummyVideo"
end sub

function startPlayback() as Void
    m.top.state = "playing"
end function

function startBuffering() as Void
    m.top.state = "buffering"
end function

function endBuffering() as Void
    m.top.state = "playing"
end function

function pausePlayback() as Void
    m.top.state = "paused"
end function

function resumePlayback() as Void
    m.top.state = "playing"
end function

function stopPlayback() as Void
    m.top.state = "stopped"
end function

function endPlayback() as Void
    m.top.state = "finished"
end function

function error() as Void
    m.top.state = "error"
end function