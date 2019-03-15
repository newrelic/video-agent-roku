'NR Video Agent Example - Main'

sub Main()
    print "Main"

    'The screen and port must be initialized before starting the NewRelic agent
    screen = CreateObject("roSGScreen")
    m.port = CreateObject("roMessagePort")
    screen.setMessagePort(m.port)
    
    NewRelic("1567277", "4SxMEHFjPjZ-M7Do8Tt_M0YaTqwf4dTl", screen)
    nrSetLogsState(true)

    'Create a scene and load /components/nrvideoagent.xml'
    scene = screen.CreateScene("NRVideoAgentExample")
    screen.show()
    
    waitFunction = Function(msg as Object)
        print "msg = " msg
    end function
    
    NewRelicWait(m.port, waitFunction)
    
end sub
