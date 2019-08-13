'NR Video Agent Example - Main'

sub x_Main()
    fs = createObject("roFileSystem")
    vols = fs.GetVolumeList()
    print "Volumes = " vols
    
    ba = CreateObject("roByteArray")
    
    dir = "cachefs:/"
    file = "salut.txt"
    path = dir + file
    
    if fs.Exists(path)
        ba.ReadFile(path)
        print "File '" + path + "' exists! Content = " ba
    else
        print "File do not exist, create it!"
        ba.FromAsciiString("hola")
        ba.WriteFile(path)
    end if
    
    var = fs.GetDirectoryListing(dir)
    print "Dir listing = " var
end sub

sub Main(aa as Object)
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
    
    waitFunction = Function(msg as Object)
        print "msg = " msg
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
