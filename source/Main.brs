'NR Video Agent Example - Main'

sub Main()
    print "in showChannelSGScreen"

    'Indicate this is a Roku SceneGraph application'
    screen = CreateObject("roSGScreen")
    m.port = CreateObject("roMessagePort")
    screen.setMessagePort(m.port)
    
    'Init global scope, required by NRAgent
    m.global = screen.getGlobalNode()

    'Create a scene and load /components/nrvideoagent.xml'
    scene = screen.CreateScene("NRVideoAgentExample")
    screen.show()

    while(true)
        msg = wait(0, m.port)
        msgType = type(msg)
        if msgType = "roSGScreenEvent"
            print "msg roSGScreenEvent"
            if msg.isScreenClosed() then return
        end if
    end while
end sub

