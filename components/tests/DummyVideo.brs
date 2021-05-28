sub init()
    print "Init DummyVideo"
end sub

function resetState() as Void
    m.top.state = "none"
    setPlayhead(0)
end function

function startPlayback() as Void
    m.top.state = "playing"
end function

function startBuffering() as Void
    m.top.state = "buffering"
end function

function endBuffering() as Void
    if m.top.state = "buffering" then m.top.state = "playing"
end function

function pausePlayback() as Void
    m.top.state = "paused"
end function

function resumePlayback() as Void
    if m.top.state = "paused" then m.top.state = "playing"
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

function setPlayhead(playhead as float) as Void
    m.top.position = playhead
end function