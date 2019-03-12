'NR Video Agent Example - Main'

sub Main()
    print "in showChannelSGScreen"

    'Indicate this is a Roku SceneGraph application'
    screen = CreateObject("roSGScreen")
    m.port = CreateObject("roMessagePort")
    screen.setMessagePort(m.port)
    
    'TODO: move this to agent
    'System Log
    syslog = CreateObject("roSystemLog")
    syslog.SetMessagePort(m.port)
    syslog.EnableType("http.error")
    syslog.EnableType("http.connect")
    syslog.EnableType("bandwidth.minute")
    syslog.EnableType("http.complete")
    
    'Get global scope
    m.global = screen.getGlobalNode()

    'Create a scene and load /components/nrvideoagent.xml'
    scene = screen.CreateScene("NRVideoAgentExample")
    screen.show()

    while(true)
        msg = wait(0, m.port)
        msgType = type(msg)
        'TODO: call an agent method to check this
        if msgType = "roSystemLogEvent" Then
        i = msg.GetInfo()
            if i.LogType = "http.error"
                nrSendHTTPError(i)
            else if i.LogType = "http.connect"
                nrSendHTTPConnect(i)
            else if i.LogType = "http.complete"
                nrSendHTTPComplete(i)
            else if i.LogType = "bandwidth.minute"
                nrSendBandwidth(i)
            end If
        end if
    end while
end sub

