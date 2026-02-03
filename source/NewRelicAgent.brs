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
' @param appName Name of application
' @param appToken Mobile application token
' @param region (optional) New Relic API region, EU or US. Default US.
' @param activeLogs (optional) Activate logs or not. Default False.
' @param enableQoe (optional) Enable QOE tracking. Default True.
' @return New Relic Agent object.
function NewRelic(account as String, apikey as String,appName as String, appToken = "" as String , region = "US" as String, activeLogs = false as Boolean, enableQoe = true as Boolean) as Object
    nr = CreateObject("roSGNode", "com.newrelic.NRAgent")
    nr.callFunc("nrActivateLogging", activeLogs)
    nr.callFunc("nrActivateQoeTracking", enableQoe)
    nr.callFunc("NewRelicInit", account, apikey,appName, region, appToken)
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
function nrUpdateConfig(nr as Object, config as Object) as Void
    nr.callFunc("nrUpdateConfig", config)
end function

' Add a matching pattern for the domain attribute and substitute it by another string.
'
' @param nr New Relic Agent object
' @param pattern: Regex pattern.
' @param subs: Substitution string.
function nrAddDomainSubstitution(nr as object, pattern as String, subs as String) as Void
    nr.callFunc("nrAddDomainSubstitution", pattern, subs)
end function

' Delete a substitution pattern created with nrAddDomainSubstitution.
'
' @param nr New Relic Agent object
' @param pattern: Regex pattern.
function nrDelDomainSubstitution(nr as object, pattern as String) as Void
    nr.callFunc("nrDelDomainSubstitution", pattern)
end function

' Send an APP_STARTED event of type ConnectedDeviceSystem.
'
' @param nr New Relic Agent object.
' @param obj The object sent as argument of Main subroutine.
function nrAppStarted(nr as Object, obj as Object) as Void
    nr.callFunc("nrAppStarted", obj)
end function

' Send a SCENE_LOADED event of type ConnectedDeviceSystem.
'
' @param nr New Relic Agent object.
' @param sceneName The scene name.
function nrSceneLoaded(nr as Object, sceneName as String) as Void
    nr.callFunc("nrSceneLoaded", sceneName)
end function

' Send a system event, type ConnectedDeviceSystem.
'
' @param nr New Relic Agent object.
' @param eventType Event type.
' @param actionName Action name.
' @param attr (optional) Attributes associative array.
function nrSendSystemEvent(nr as Object, eventType as String, actionName as String, attr = invalid as Object) as Void
    nr.callFunc("nrSendSystemEvent", eventType, actionName, attr)
end function

' Send a custom event, type VideoCustomAction.
'
' @param nr New Relic Agent object.
' @param actionName Action name.
' @param attr (optional) Attributes associative array.
function nrSendCustomEvent(nr as Object, actionName as String, attr = invalid as Object) as Void
    nr.callFunc("nrSendCustomEvent", actionName, attr)
end function

' Send a video event, type VideoAction.
'
' @param nr New Relic Agent object.
' @param actionName Action name.
' @param attr (optional) Attributes associative array.
function nrSendVideoEvent(nr as Object, actionName as String, attr = invalid) as Void
    nr.callFunc("nrSendVideoEvent", actionName, attr)
end function

' Send an HTTP_REQUEST event of type ConnectedDeviceSystem.
'
' @param nr New Relic Agent object.
' @param urlReq URL request, roUrlTransfer object.
function nrSendHttpRequest(nr as Object, urlReq as Object) as Void
    if type(urlReq) = "roUrlTransfer"
        attr = {
            "origUrl": urlReq.GetUrl(),
            "transferIdentity": urlReq.GetIdentity(),
            "method": urlReq.GetRequest()
        }
        nr.callFunc("nrSendHttpRequest", attr)
    end if
end function

' Send an HTTP_RESPONSE event of type ConnectedDeviceSystem.
'
' @param nr New Relic Agent object.
' @param _url Request URL.
' @param msg A message of type roUrlEvent.
function nrSendHttpResponse(nr as Object, _url as String, msg as Object) as Void
    if type(msg) = "roUrlEvent"
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
        
        nr.callFunc("nrSendHttpResponse", attr)
    end if
end function

' Enable HTTP_CONNECT/HTTP_COMPLETE events.
'
' @param nr New Relic Agent object.
function nrEnableHttpEvents(nr as Object) as Void
    nr.callFunc("nrEnableHttpEvents")
end function

' Disable HTTP_CONNECT/HTTP_COMPLETE events.
'
' @param nr New Relic Agent object.
function nrDisableHttpEvents(nr as Object) as Void
    nr.callFunc("nrDisableHttpEvents")
end function

' Set harvest time, the time the events are buffered before being sent.
'
' @param nr New Relic Agent object.
' @param time Time in seconds (min 60).
function nrSetHarvestTime(nr as Object, time as Integer) as Void
    nr.callFunc("nrSetHarvestTime", time)
end function

' Set userId
'
' @param nr New Relic Agent object.
' @param userId UserId
function nrSetUserId(nr as Object, userId as String) as Void
    nr.callFunc("nrSetUserId", userId)
end function

' Set harvest time for events, the time the events are buffered before being sent.
'
' @param nr New Relic Agent object.
' @param time Time in seconds (min 60).
function nrSetHarvestTimeEvents(nr as Object, time as Integer) as Void
    nr.callFunc("nrSetHarvestTimeEvents", time)
end function

' Set harvest time for logs, the time the events are buffered before being sent.
'
' @param nr New Relic Agent object.
' @param time Time in seconds (min 60).
function nrSetHarvestTimeLogs(nr as Object, time as Integer) as Void
    nr.callFunc("nrSetHarvestTimeLogs", time)
end function

' Set harvest time for metrics, the time the events are buffered before being sent.
'
' @param nr New Relic Agent object.
' @param time Time in seconds (min 60).
function nrSetHarvestTimeMetrics(nr as Object, time as Integer) as Void
    nr.callFunc("nrSetHarvestTimeMetrics", time)
end function

' Do harvest immediately. It doesn't reset the harvest timer.
'
' @param nr New Relic Agent object.
function nrForceHarvest(nr as Object) as Void
    nr.callFunc("nrForceHarvest")
end function

' Do harvest events immediately. It doesn't reset the harvest timer.
'
' @param nr New Relic Agent object.
function nrForceHarvestEvents(nr as Object) as Void
    nr.callFunc("nrForceHarvestEvents")
end function

' Do harvest logs immediately. It doesn't reset the harvest timer.
'
' @param nr New Relic Agent object.
function nrForceHarvestLogs(nr as Object) as Void
    nr.callFunc("nrForceHarvestLogs")
end function

' Track an event from Roku Advertising Framework
'
' @param nr New Relic Agent object.
' @param evtType Event type.
' @param ctx Event context.
function nrTrackRAF(nr as Object, evtType = invalid as Dynamic, ctx = invalid as Dynamic) as Void
    nr.callFunc("nrTrackRAF", evtType, ctx)
end function

' Record a log.
'
' @param nr New Relic Agent object.
' @param message Log message.
' @param logtype Log type.
' @param fields Additonal fields to be included in the log.
function nrSendLog(nr as Object, message as String, logtype as String, fields = invalid as Object) as Void
    nr.callFunc("nrSendLog", message, logtype, fields)
end function

' Record a gauge metric. Represents a value that can increase or decrease with time.
'
' @param nr New Relic Agent object.
' @param name Metric name
' @param value Metric value. Number.
' @param attr (optional) Metric attributes.
function nrSendMetric(nr as Object, name as String, value as dynamic, attr = invalid as Object) as Void
    nr.callFunc("nrSendMetric", name, value, attr)
end function

' Record a count metric. Measures the number of occurences of an event during a time interval.
'
' @param nr New Relic Agent object.
' @param name Metric name
' @param value Metric value. Number.
' @param interval Metric time interval in milliseconds.
' @param attr (optional) Metric attributes.
function nrSendCountMetric(nr as Object, name as String, value as dynamic, interval as Integer, attr = invalid as Object) as Void
    nr.callFunc("nrSendCountMetric", name, value, interval, attr)
end function

' Record a summary metric. Used to report pre-aggregated data, or information on aggregated discrete events.
'
' @param nr New Relic Agent object.
' @param name Metric name
' @param interval Metric time interval in milliseconds.
' @param count Metric count.
' @param m_sum Metric value summation.
' @param m_min Metric minimum value.
' @param m_max Metric maximum value.
' @param attr (optional) Metric attributes.
function nrSendSummaryMetric(nr as Object, name as String, interval as Integer, counter as dynamic, m_sum as dynamic, m_min as dynamic, m_max as dynamic, attr = invalid as Object) as Void
    value = {
        "count": counter,
        "sum": m_sum,
        "max": m_max,
        "min": m_min
    }
    nr.callFunc("nrSendSummaryMetric", name, interval, value, attr)
end function
