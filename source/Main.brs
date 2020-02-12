'NR Video Agent Example - Main'

sub Main(aa as Object)
    print "Main arg = ", aa
    
    screen = CreateObject("roSGScreen")
    m.port = CreateObject("roMessagePort")
    screen.setMessagePort(m.port)
    
    scene = screen.CreateScene("VideoScene")
    screen.show()
    
    'Init New Relic Agent
    m.nr = NewRelic("1567277", "4SxMEHFjPjZ-M7Do8Tt_M0YaTqwf4dTl", true)
    nrAppStarted(m.nr, aa)
    nrSendSystemEvent(m.nr, "TEST_ACTION")
    
    print "Main m = ", m
    
    'Pass NewRelicAgent object to scene
    scene.setField("nr", m.nr)
    'Observe scene field "moreButton" to capture "back" button and abort the execution
    scene.observeField("moteButton", m.port)
    
    while(true)
        msg = wait(0, m.port)
        print "Msg = ", msg
        if msg.getField() = "moteButton"
            print "moteButton, data = ", msg.getData()
            if msg.getData() = "back" 
                exit while
            end if
            if msg.getData() = "OK"
                'force crash
                print "Crash!"
                anyshit()
            end if
        end if
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
