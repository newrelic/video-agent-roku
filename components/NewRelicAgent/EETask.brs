'**********************************************************
' EETask.brs
' New Relic Agent background task for Express Events.
'
' Copyright 2023 New Relic Inc. All Rights Reserved. 
'**********************************************************

sub init()
    m.top.functionName = "nrTaskMain"
    m.loggingState = false
end sub

function nrTaskMain() as Void
    if m.nr = invalid
        'Assuming that parent node is com.newrelic.NRAgent
        m.nr = m.top.getParent()
        m.apiKey = m.top.apiKey
        m.loggingState = m.nr.callFunc("nrCheckLoggingState")
    end if

    attributes = m.top.attributes.getFields()
    'Remove garbage introduced by ContentNode
    attributes.Delete("id")
    attributes.Delete("focusedChild")
    attributes.Delete("focusable")
    attributes.Delete("change")
    
    print "Express Events Task Attributes", attributes
end function

function onConfigUpdate() as Void
    m.eventApiUrl = m.top.eventApiUrl
end function

function nrLog(msg as Dynamic) as Void
    if m.loggingState = true then m.nr.callFunc("nrLog", msg)
end function