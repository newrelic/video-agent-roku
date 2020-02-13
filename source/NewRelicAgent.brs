'**********************************************************
' NewRelicAgent.brs
' New Relic Agent Interface.
' Minimum requirements: FW 8.1
'
' Copyright 2020 New Relic Inc. All Rights Reserved.
'**********************************************************

function NewRelic(account as String, apikey as String, activeLogs = false as Boolean) as Object
    nr = CreateObject("roSGNode", "com.newrelic.NRAgent")
    nr.callFunc("nrActivateLogging", activeLogs)
    nr.callFunc("NewRelicInit", account, apikey)
    return nr
end function

function NewRelicSystemStart(nr as Object, port as Object) as Object
    syslog = CreateObject("roSystemLog")
    syslog.SetMessagePort(port)
    syslog.EnableType("http.error")
    syslog.EnableType("http.connect")
    syslog.EnableType("bandwidth.minute")
    syslog.EnableType("http.complete")
    return syslog
end function

function NewRelicVideoStart(nr as Object, video as Object) as Void
    nr.callFunc("NewRelicVideoStart", video)
end function

function nrProcessMessage(nr as Object, msg as Object) as Boolean
    msgType = type(msg)
    if msgType = "roSystemLogEvent" then
        i = msg.GetInfo()
        if i.LogType = "http.error"
            nr.callFunc("nrSendHTTPError", i)
            return true
        else if i.LogType = "http.connect" 
            nr.callFunc("nrSendHTTPConnect", i)
            return true
        else if i.LogType = "http.complete"
            nr.callFunc("nrSendHTTPComplete", i)
            return true
        else if i.LogType = "bandwidth.minute"
            nr.callFunc("nrSendBandwidth", i)
            return true
        end If
    end if
    return false
end function

function nrSetCustomAttribute(nr as Object, key as String, value as Object, actionName = "" as String) as Void
    nr.callFunc("nrSetCustomAttribute", key, value, actionName)
end function

function nrSetCustomAttributeList(nr as Object, attr as Object, actionName = "" as String) as Void
    nr.callFunc("nrSetCustomAttributeList", attr, actionName)
end function

function nrAppStarted(nr as Object, obj as Object) as Void
    nr.callFunc("nrAppStarted", obj)
end function

function nrSceneLoaded(nr as Object, sceneName as String) as Void
    nr.callFunc("nrSceneLoaded", sceneName)
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

function nrSendHttpRequest(nr as Object, urlReq as Object) as Void
    if type(urlReq) <> "roUrlTransfer" return
    
    attr = {
        "origUrl": urlReq.GetUrl(),
        "transferIdentity": urlReq.GetIdentity(),
        "method": urlReq.GetRequest()
    }
    
    nrSendCustomEvent(nr, "RokuSystem", "HTTP_REQUEST", attr)
end function

function nrSendHttpResponse(nr as Object, _url as String, msg = invalid as Object) as Void
    
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

function nrSetHarvestTime(nr as Object, time as Integer) as Void
    nr.callFunc("nrSetHarvestTime", time)
end function
