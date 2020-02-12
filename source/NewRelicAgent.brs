'**********************************************************
' NewRelicAgent.brs
' New Relic Agent for Roku.
'
' Copyright 2020 New Relic Inc. All Rights Reserved. 
'**********************************************************

'------------------
' Wrapper Functions
'------------------

function NewRelic(account as String, apikey as String, activeLogs = false as Boolean) as Object
    nr = CreateObject("roSGNode", "com.newrelic.NewRelicAgent")
    nr.callFunc("nrActivateLogging", activeLogs)
    nr.callFunc("NewRelicInit", account, apikey)
    return nr
end function

function NewRelicVideoStart(nr as Object, video as Object) as Void
    nr.callFunc("NewRelicVideoStart", video)
end function

function nrSceneLoaded(nr as Object, sceneName as String) as Void
    nr.callFunc("nrSceneLoaded", sceneName)
end function

function nrAppStarted(nr as Object, obj as Object) as Void
    nr.callFunc("nrAppStarted", obj)
end function

function nrSendCustomEvent(nr as Object, eventType as String, actionName as String, attr = invalid as Object) as Void
    nr.callFunc("nrSendCustomEvent", eventType, actionName, attr)
end function

function nrSendSystemEvent(nr as Object, actionName as String, attr = invalid) as Void
    nr.callFunc("nrSendSystemEvent", actionName, attr)
end function

function nrSendVideoEvent(nr as Object, actionName as String, attr = invalid) as Void
    nr.callFunc("nrSendVideoEvent", actionName, attr)
end function

'TODO: wrap nrSetCustomAttribute
'TODO: wrap nrSetCustomAttributeList
