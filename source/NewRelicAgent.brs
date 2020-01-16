'**********************************************************
' NewRelicAgent.brs
' New Relic Agent for Roku.
'
' Copyright 2020 New Relic Inc. All Rights Reserved. 
'**********************************************************

function NewRelic(account as String, apikey as String, screen as Object) as Object
    nr = CreateObject("roSGNode", "NewRelicAgent")
    nr.callFunc("NewRelicInit", account, apikey, screen)
    return nr
end function
