'NR Video Agent Example - Main'

sub Main()
    print "Main"

    'The screen and port must be initialized before starting the NewRelic agent
    screen = CreateObject("roSGScreen")
    m.port = CreateObject("roMessagePort")
    screen.setMessagePort(m.port)
    
    NewRelic("1567277", "4SxMEHFjPjZ-M7Do8Tt_M0YaTqwf4dTl", screen)

    'Create a scene and load /components/nrvideoagent.xml'
    scene = screen.CreateScene("NRVideoAgentExample")
    screen.show()

    while(true)
        msg = wait(0, m.port)
        if nrProcessMessage(msg) = false
            'handle message manually...
        end if
    end while
end sub

