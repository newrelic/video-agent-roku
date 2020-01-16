'**********************************************************
' NewRelicAgent.brs
' New Relic Agent for Roku.
'
' Copyright 2020 New Relic Inc. All Rights Reserved. 
'**********************************************************

function NewRelic(account as String, apikey as String, activeLogs = false as Boolean) as Object
    nr = CreateObject("roSGNode", "NewRelicAgent")
    nr.callFunc("nrActivateLogging", activeLogs)
    nr.callFunc("NewRelicInit", account, apikey)
    return nr
end function

function NewRelicStart(nr as Object) as Void
    nr.callFunc("NewRelicStart")
end function
