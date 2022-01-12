'**********************************************************
' NewRelicAgent.brs
' New Relic Agent Interface.
' Minimum requirements: FW 8.1
'
' Copyright 2020 New Relic Inc. All Rights Reserved.
'**********************************************************

' Build a New Relic Agent object.
'
' @param account New Relic account number.
' @param apikey Insights API key.
' @param region (optional) New Relic API region, EU or US. Default US.
' @param activeLogs (optional) Activate logs or not. Default False.
' @return New Relic Agent object.
function NewRelic(account as String, apikey as String, region = "US" as String, activeLogs = false as Boolean) as Object
    nr = CreateObject("roSGNode", "com.newrelic.NRAgent")
    nr.callFunc("nrActivateLogging", activeLogs)
    nr.callFunc("NewRelicInit", account, apikey, region)
    return nr
end function

' Start system logging.
'
' @param port A message port.
' @return The roSystemLog object created.
function NewRelicSystemStart(port as Object) as Object
    syslog = CreateObject("roSystemLog")
    syslog.SetMessagePort(port)
    syslog.EnableType("http.error")
    syslog.EnableType("http.connect")
    syslog.EnableType("bandwidth.minute")
    syslog.EnableType("http.complete")
    return syslog
end function

' Start video logging.
'
' @param nr New Relic Agent object.
' @param video A video object.
function NewRelicVideoStart(nr as Object, video as Object) as Void
    nr.callFunc("NewRelicVideoStart", video)
end function

' Stop video logging.
'
' @param nr New Relic Agent object.
function NewRelicVideoStop(nr as Object) as Void
    nr.callFunc("NewRelicVideoStop")
end function

' Check for a system log message, process it and sends the appropriate event. 
'
' @param nr New Relic Agent object.
' @param msg A message of type roSystemLogEvent.
' @return True if msg is a system log message, False otherwise.
function nrProcessMessage(nr as Object, msg as Object) as Boolean
    msgType = type(msg)
    if msgType = "roSystemLogEvent" then
        i = msg.GetInfo()
        return nr.callFunc("nrProcessSystemEvent", i)
    end if
    return false
end function

' Set a custom attribute to be included in the events.
'
' @param nr New Relic Agent object.
' @param key Attribute name.
' @param value Attribute value.
' @param actionName (optional) Action where the attribute will be included. Default all actions.
function nrSetCustomAttribute(nr as Object, key as String, value as Object, actionName = "" as String) as Void
    nr.callFunc("nrSetCustomAttribute", key, value, actionName)
end function

' Set a custom attribute list to be included in the events.
'
' @param nr New Relic Agent object.
' @param attr Attribute list, as an associative array.
' @param actionName (optional) Action where the attribute will be included. Default all actions.
function nrSetCustomAttributeList(nr as Object, attr as Object, actionName = "" as String) as Void
    nr.callFunc("nrSetCustomAttributeList", attr, actionName)
end function

' modifies current configuration
'
' @param nr New Relic Agent object
' @param obj { proxyUrl: string, delimited network proxy URL }
function nrUpdateConfig(nr as object, config as object) as void
    nr.callFunc("nrUpdateConfig", config)
end function

' Send an APP_STARTED event of type RokuSystem.
'
' @param nr New Relic Agent object.
' @param obj The object sent as argument of Main subroutine.
function nrAppStarted(nr as Object, obj as Object) as Void
    nr.callFunc("nrAppStarted", obj)
end function

' Send a SCENE_LOADED event of type RokuSystem.
'
' @param nr New Relic Agent object.
' @param sceneName The scene name.
function nrSceneLoaded(nr as Object, sceneName as String) as Void
    nr.callFunc("nrSceneLoaded", sceneName)
end function

' Send a custom event.
'
' @param nr New Relic Agent object.
' @param eventType Event type.
' @param actionName Action name.
' @param attr (optional) Attributes associative array.
function nrSendCustomEvent(nr as Object, eventType as String, actionName as String, attr = invalid as Object) as Void
    nr.callFunc("nrSendCustomEvent", eventType, actionName, attr)
end function

' Send a system event, type RokuSystem.
'
' @param nr New Relic Agent object.
' @param actionName Action name.
' @param attr (optional) Attributes associative array.
function nrSendSystemEvent(nr as Object, actionName as String, attr = invalid) as Void
    nr.callFunc("nrSendSystemEvent", actionName, attr)
end function

' Send a video event, type RokuVideo.
'
' @param nr New Relic Agent object.
' @param actionName Action name.
' @param attr (optional) Attributes associative array.
function nrSendVideoEvent(nr as Object, actionName as String, attr = invalid) as Void
    nr.callFunc("nrSendVideoEvent", actionName, attr)
end function

' Send an HTTP_REQUEST event of type RokuSystem.
'
' @param nr New Relic Agent object.
' @param urlReq URL request, roUrlTransfer object.
function nrSendHttpRequest(nr as Object, urlReq as Object) as Void
    if type(urlReq) <> "roUrlTransfer" return
    
    attr = {
        "origUrl": urlReq.GetUrl(),
        "transferIdentity": urlReq.GetIdentity(),
        "method": urlReq.GetRequest()
    }
    
    nrSendCustomEvent(nr, "RokuSystem", "HTTP_REQUEST", attr)
end function

' Send an HTTP_RESPONSE event of type RokuSystem.
'
' @param nr New Relic Agent object.
' @param _url Request URL.
' @param msg A message of type roUrlEvent.
function nrSendHttpResponse(nr as Object, _url as String, msg as Object) as Void
    
    if type(msg) <> "roUrlEvent" return
    
    attr = {
        "origUrl": _url
    }
    
    attr.AddReplace("httpCode", msg.GetResponseCode())
    attr.AddReplace("httpResult", msg.GetFailureReason())
    attr.AddReplace("transferIdentity", msg.GetSourceIdentity())
    
    header = msg.GetResponseHeaders()
    
    for each key in header
        parts = key.Tokenize("-")
        finalKey = "http"
        finalValue = header[key]
        for each part in parts
            firstChar = Left(part, 1)
            firstChar = UCase(firstChar)
            restStr = Right(part, Len(part) - 1)
            restStr = LCase(restStr)
            finalKey = finalKey + firstChar + restStr
        end for
        attr.AddReplace(finalKey, finalValue)
    end for
    
    nrSendCustomEvent(nr, "RokuSystem", "HTTP_RESPONSE", attr)
end function

' Set harvest time, the time the events are buffered before being sent to Insights.
'
' @param nr New Relic Agent object.
' @param time Time in seconds.
function nrSetHarvestTime(nr as Object, time as Integer) as Void
    nr.callFunc("nrSetHarvestTime", time)
end function

' Do harvest immediately. It doesn't reset the harvest timer.
'
' @param nr New Relic Agent object.
function nrForceHarvest(nr as Object) as Void
    nr.callFunc("nrForceHarvest")
end function

' Track an event from Roku Advertising Framework
'
' @param nr New Relic Agent object.
' @param evtType Event type.
' @param ctx Event context.
function nrTrackRAF(nr as Object, evtType = invalid as Dynamic, ctx = invalid as Dynamic)
    nr.callFunc("nrTrackRAF", evtType, ctx)
end function
