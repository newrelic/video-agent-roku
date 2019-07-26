'NR Video Agent Example - Main'

sub Main(aa as Object)
    print "Main" aa

    'The screen and port must be initialized before starting the NewRelic agent
    screen = CreateObject("roSGScreen")
    m.port = CreateObject("roMessagePort")
    screen.setMessagePort(m.port)
    
    NewRelicInit("1567277", "4SxMEHFjPjZ-M7Do8Tt_M0YaTqwf4dTl", screen)
    nrActivateLogging(true)

    'Create a scene and load /components/nrvideoagent.xml'
    scene = screen.CreateScene("NRVideoAgentExample")
    screen.show()
    
    waitFunction = Function(msg as Object)
        print "msg = " msg
    end function
    
    nrAppStarted(aa)
    
    'Create tasks to make HTTP requests
    createTask(1)
    createTask(2)
    createTask(3)
    
    'Wait loop
    NewRelicWait(m.port, waitFunction)
    
end sub

function createTask(num as Integer)
    task = createObject("roSGNode", "TestTask")
    task.setField("taskNum", num)
    task.control = "RUN"
end function
