'NR Video Agent Example - Main'

sub RunUserInterface(args)
    if args.RunTests = "true" and type(TestRunner) = "Function" then
        print "Run tests"
        Runner = TestRunner()

        Runner.SetFunctions([
            TestSuite__Main
            TestSuite__Logs
            TestSuite__Metrics
        ])

        Runner.Logger.SetVerbosity(3)
        Runner.Logger.SetEcho(false)
        Runner.Logger.SetJUnit(false)
        Runner.SetFailFast(true)
        
        Runner.Run()
    else
        Main(args)
    end if
end sub

sub Main(aa as Object)
    screen = CreateObject("roSGScreen")
    m.port = CreateObject("roMessagePort")
    screen.setMessagePort(m.port)
    
    scene = screen.CreateScene("VideoScene")
    screen.show()
    
    'Init New Relic Agent (FILL YOUR CREDENTIALS, ACCOUNT_ID, API_KEY, APP_NAME and APP_TOKEN)
    ' m.nr = NewRelic("ACCOUNT_ID", "API_KEY","APP_NAME", "APP_TOKEN" , "US", true)
    'Set custom harvest time
    nrSetHarvestTime(m.nr, 60)
    'Version 3.0.0 (or above) disables HttpEvents by default
    nrEnableHttpEvents(m.nr)
    'Send APP_STARTED event
    nrAppStarted(m.nr, aa)
    'Send a custom system
    nrSendSystemEvent(m.nr, "ConnectedDeviceSystem","TEST_ACTION")
    
    'Define multiple domain substitutions
    nrAddDomainSubstitution(m.nr, "^www\.google\.com$", "Google COM")
    nrAddDomainSubstitution(m.nr, "^www\.google\.cat$", "Google CAT")
    nrAddDomainSubstitution(m.nr, "^www\.google\.us$", "Google US")
    nrAddDomainSubstitution(m.nr, "^google\.com$", "Google ERROR")
    nrAddDomainSubstitution(m.nr, "^.+\.googleapis\.com$", "Google APIs")
    nrAddDomainSubstitution(m.nr, "^.+\.akamaihd\.net$", "Akamai")
    
    'Pass NewRelicAgent object to scene
    scene.setField("nr", m.nr)
    'Observe scene field "moteButton" to capture "back" button and abort the execution
    scene.observeField("moteButton", m.port)
    
    'Activate system tracking
    m.syslog = NewRelicSystemStart(m.port)

    runSearchTask("hello")
    
    while(true)
        msg = wait(0, m.port)
        
        if nrProcessMessage(m.nr, msg) = false
            'Is not a system message captured by New Relic Agent
            print "Msg = ", msg
            
            if type(msg) = "roSGNodeEvent"
                if msg.getField() = "moteButton"
                    print "moteButton, data = ", msg.getData()
                    if msg.getData() = "back" 
                        exit while
                    end if
                    if msg.getData() = "OK"
                        'force crash
                        print "Crash!"
                        x = invalid
                        x.anyFoo()
                    end if
                end if
            end if
        end if
    end while
end sub

'Test task to show how to generate http events
function runSearchTask(search as String)
    task = createObject("roSGNode", "SearchTask")
    task.setField("nr", m.nr)
    task.setField("searchString", search)
    task.control = "RUN"
end function
