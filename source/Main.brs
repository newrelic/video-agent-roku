'NR Video Agent Example - Main'

sub Main()
    print "in showChannelSGScreen"

    'Indicate this is a Roku SceneGraph application'
    screen = CreateObject("roSGScreen")
    m.port = CreateObject("roMessagePort")
    screen.setMessagePort(m.port)
    
    'TODO: move this to agent
    'System Log
    'syslog = CreateObject("roSystemLog")
    'syslog.SetMessagePort(m.port)
    'syslog.EnableType("http.error")
    'syslog.EnableType("http.connect")
    'syslog.EnableType("bandwidth.minute")
    'syslog.EnableType("http.complete")
    
    'Get global scope
    m.global = screen.getGlobalNode()

    'Create a scene and load /components/nrvideoagent.xml'
    scene = screen.CreateScene("NRVideoAgentExample")
    screen.show()
    
    syslog = nrStartSysTracker(m.port)

    while(true)
        msg = wait(0, m.port)
        nrProcessMessage(msg)
    end while
end sub

