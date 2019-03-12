'NR Video Agent Example - Main'

sub Main()
    print "in showChannelSGScreen"

    'Indicate this is a Roku SceneGraph application'
    screen = CreateObject("roSGScreen")
    m.port = CreateObject("roMessagePort")
    screen.setMessagePort(m.port)
    
    'System Log
    syslog = CreateObject("roSystemLog")
    syslog.SetMessagePort(m.port)
    syslog.EnableType("http.error")
    syslog.EnableType("http.connect")
    syslog.EnableType("bandwidth.minute")
    syslog.EnableType("http.complete")
    
    'Get global scope
    'm.global = screen.getGlobalNode()

    'Create a scene and load /components/nrvideoagent.xml'
    scene = screen.CreateScene("NRVideoAgentExample")
    screen.show()

    while(true)
        msg = wait(0, m.port)
        msgType = type(msg)
        if msgType = "roSystemLogEvent" Then
        i = msg.GetInfo()
            if i.LogType = "http.error"
                print ">>>>>>>>> HTTP ERROR: " i
            else if i.LogType = "http.connect"
                print ">>>>>>>>> HTTP CONNECT: " i
            else if i.LogType = "http.complete"
                print ">>>>>>>>> HTTP COMPLETE: " i            
            End If
        end if
    end while
end sub

