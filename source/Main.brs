'NR Video Agent Example - Main'

sub Main()
    screen = CreateObject("roSGScreen")
    m.port = CreateObject("roMessagePort")
    screen.setMessagePort(m.port)
    
    scene = screen.CreateScene("NRVideoAgentExample")
    screen.show()
    
    'Init New Relic Agent
    m.nr = NewRelic("1567277", "4SxMEHFjPjZ-M7Do8Tt_M0YaTqwf4dTl", screen, true)
    print "m.nr component = ", m.nr
    print "m = ", m
    
    scene.ObserveField("moteButton", m.port)
    
    while(true)
        msg = wait(0, m.port)
        print "Msg = ", msg
        if msg.getField() = "moteButton" AND msg.getData() = "back" then exit while
    end while
end sub

'--------------------------------------------------------------------------------------------------------
'--------------------------------------------------------------------------------------------------------
'--------------------------------------------------------------------------------------------------------
'--------------------------------------------------------------------------------------------------------

sub xx_Main(aa as Object)
    print "Main" aa

    'The screen and port must be initialized before starting the NewRelic agent
    screen = CreateObject("roSGScreen")
    m.port = CreateObject("roMessagePort")
    screen.setMessagePort(m.port)
    
    NewRelicInit("1567277", "4SxMEHFjPjZ-M7Do8Tt_M0YaTqwf4dTl", screen)
    nrActivateLogging(true)
    nrAppStarted(aa)

    'Create a scene and load /components/nrvideoagent.xml'
    scene = screen.CreateScene("NRVideoAgentExample")
    screen.show()
    scene.ObserveField("moteButton", m.port)
    
    waitFunction = Function(msg as Object)
        print "Custom msg received = " msg
        if msg.getField() = "moteButton" AND msg.getData() = "back" then return false
        return true
    end function
    
    'Create test tasks to make HTTP requests
    searchTask("hello")
    
    'Wait loop
    NewRelicWait(m.port, waitFunction)
    
end sub

function searchTask(search as String)
    task = createObject("roSGNode", "SearchTask")
    task.setField("searchString", search)
    task.control = "RUN"
end function
