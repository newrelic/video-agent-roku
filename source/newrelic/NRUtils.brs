'**********************************************************
' NRUtils.brs
' New Relic Agent Utility functions for Roku.
' Minimum requirements: FW 7.2
'
' Copyright 2019 New Relic Inc. All Rights Reserved. 
'**********************************************************

function nrInsertInsightsData(attributes as Object) as Object
    _url = box("https://insights-collector.newrelic.com/v1/accounts/" + m.global.nrAccountNumber + "/events")
    apikey = m.global.nrInsightsApiKey
    jsonString = FormatJson(attributes)

    urlReq = CreateObject("roUrlTransfer")

    urlReq.SetUrl(_url)
    urlReq.RetainBodyOnError(true)
    urlReq.EnablePeerVerification(false)
    urlReq.EnableHostVerification(false)
    urlReq.AddHeader("Content-Type", "application/json")
    urlReq.AddHeader("X-Insert-Key", apikey)

    resp = urlReq.PostFromString(jsonString)
    
    return resp
end function

'Used to send generic events
function nrSendCustomEvent(eventType as String, actionName as String, attr as Object) as Void
    ev = nrCreateEvent(eventType, actionName)
    ev.Append(attr)
    nrRecordEvent(ev)
end function

function nrSendHttpEvent(_url as String, msg = invalid as Object) as Void
    attr = {
        "origUrl": _url
    }
    
    if msg <> invalid
        attr.AddReplace("httpCode", msg.GetResponseCode())
        attr.AddReplace("httpResult", msg.GetFailureReason())
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
    end if
    
    nrSendCustomEvent("RokuSystem", "HTTP_REQUEST", attr)
end function

function nrCreateEvent(eventType as String, actionName as String) as Object
    ev = CreateObject("roAssociativeArray")
    if actionName <> invalid and actionName <> "" then ev["actionName"] = actionName
    if eventType <> invalid and eventType <> "" then ev["eventType"] = eventType
    
    ev["timestamp"] = nrTimestamp()
    ev = nrAddAttributes(ev)
    
    return ev
end function

function nrTimestamp() as LongInteger
    timestamp& = CreateObject("roDateTime").asSeconds()
    timestampMS& = timestamp& * 1000
    
    if timestamp& = m.global.nrLastTimestamp
        m.global.nrTicks = m.global.nrTicks + 1
    else
        m.global.nrTicks = 0
    end if
    
    timestampMS& = timestampMS& + m.global.nrTicks
    m.global.nrLastTimestamp = timestamp&
    
    return timestampMS&
end function

function nrAddAttributes(ev as Object) as Object
    ev.AddReplace("newRelicAgent", "RokuAgent")
    ev.AddReplace("newRelicVersion", m.global.nrAgentVersion)
    ev.AddReplace("sessionId", m.global.nrSessionId)
    hdmi = CreateObject("roHdmiStatus")
    ev.AddReplace("hdmiIsConnected", hdmi.IsConnected())
    ev.AddReplace("hdmiHdcpVersion", hdmi.GetHdcpVersion())
    dev = CreateObject("roDeviceInfo")
    ev.AddReplace("uuid", dev.GetChannelClientId()) 'GetDeviceUniqueId is deprecated, so we use GetChannelClientId
    ev.AddReplace("device", dev.GetModelDisplayName())
    ev.AddReplace("deviceGroup", "Roku")
    ev.AddReplace("deviceManufacturer", "Roku")
    ev.AddReplace("deviceModel", dev.GetModel())
    ev.AddReplace("deviceType", dev.GetModelType())
    ev.AddReplace("osName", "RokuOS")
    ev.AddReplace("osVersion", dev.GetVersion())
    ev.AddReplace("countryCode", dev.GetUserCountryCode())
    ev.AddReplace("timeZone", dev.GetTimeZone())
    ev.AddReplace("locale", dev.GetCurrentLocale())
    ev.AddReplace("memoryLevel", dev.GetGeneralMemoryLevel())
    ev.AddReplace("connectionType", dev.GetConnectionType())
    ev.AddReplace("ipAddress", dev.GetExternalIp())
    ev.AddReplace("displayType", dev.GetDisplayType())
    ev.AddReplace("displayMode", dev.GetDisplayMode())
    ev.AddReplace("displayAspectRatio", dev.GetDisplayAspectRatio())
    ev.AddReplace("videoMode", dev.GetVideoMode())
    ev.AddReplace("graphicsPlatform", dev.GetGraphicsPlatform())
    ev.AddReplace("timeSinceLastKeypress", dev.TimeSinceLastKeypress() * 1000)    
    app = CreateObject("roAppInfo")
    appid = app.GetID().ToInt()
    if appid = 0 then appid = 1
    ev.AddReplace("appId", appid)
    ev.AddReplace("appVersion", app.GetValue("major_version") + "." + app.GetValue("minor_version"))
    ev.AddReplace("appName", app.GetTitle())
    ev.AddReplace("appDevId", app.GetDevID())
    ev.AddReplace("appIsDev", app.IsDev())
    appbuild = app.GetValue("build_version").ToInt()
    if appbuild = 0 then appbuild = 1
    ev.AddReplace("appBuild", appbuild)
    
    'Add custom attributes
    genCustomAttr = m.global["GENERAL_ATTR"]
    if genCustomAttr <> invalid then ev.Append(genCustomAttr)
    actionName = ev["actionName"]
    actionCustomAttr = m.global[actionName]
    if actionCustomAttr <> invalid then ev.Append(actionCustomAttr)
    
    return ev
end function

function nrEventProcessor() as Void
    while true
        ev = nrExtractEvent()
        if ev = invalid then exit while
        res = nrInsertInsightsData(ev)
        if res <> 200
            nrLog("-- nrEventProcessor: FAILED, retry later --")
            nrRecordEvent(ev)
        else
            nrLog("-- nrEventProcessor: insert insights data --")
        end if
    end while
end function

function nrProcessGroupedEvents() as Void
    'Convert groups into custom events and flush the groups dictionaries
    
    nrLog("-- Process Grouped Events --")
    __logEvGroups()
    
    if m.global.nrEventGroupsConnect.Count() > 0
        nrConvertGroupsToEvents(m.global.nrEventGroupsConnect)
        m.global.nrEventGroupsConnect = {}
    end if
    
    if m.global.nrEventGroupsComplete.Count() > 0
        nrConvertGroupsToEvents(m.global.nrEventGroupsComplete)
        m.global.nrEventGroupsComplete = {}
    end if
end function

function nrConvertGroupsToEvents(group as Object) as Void
    for each item in group.Items()
        item.value["matchUrl"] = item.key

        'Calculate averages
        if item.value["actionName"] = "HTTP_COMPLETE"
            counter = Cdbl(item.value["counter"])
            item.value["transferTime"] = item.value["transferTime"] / counter
            item.value["connectTime"] = item.value["connectTime"] / counter
            item.value["dnsLookupTime"] = item.value["dnsLookupTime"] / counter
            item.value["downloadSpeed"] = item.value["downloadSpeed"] / counter
            item.value["uploadSpeed"] = item.value["uploadSpeed"] / counter
            item.value["firstByteTime"] = item.value["firstByteTime"] / counter
        end if
        
        nrSendCustomEvent("RokuSystem", item.value["actionName"], item.value)
    end for
end function

'Record an event to the list. Takes an roAssociativeArray as argument 
function nrRecordEvent(event as Object) as Void
    if m.global.nrEventArray.Count() < 500
        arr = m.global.nrEventArray
        arr.Push(event)
        m.global.nrEventArray = arr
        
        nrLog(["Record New Event = ", event])
    else
        nrLog("Events overflow, discard event")
    end if
end function

'Extracts the first event from the list. Returns an roAssociativeArray as argument
function nrExtractEvent() as Object
    arr = m.global.nrEventArray
    res = arr.Pop()
    m.global.nrEventArray = arr
    return res
end function

function nrLog(msg as Dynamic) as Void
    if m.global.nrLogsState = true
        if type(msg) = "roArray"         
            For i=0 To msg.Count() - 1 Step 1
                print msg[i];
            End For
            print ""
        else
            print msg
        end if
    end if
end function

function nrActivateLogging(state as Boolean) as Void
    if m.global.nrLogsState = invalid
        m.global.addFields({"nrLogsState": state})
    else 
        m.global.nrLogsState = state
    end if
end function

function __logEvGroups() as Void
    nrLog("============ Event Groups HTTP_CONNECT ===========")
    for each item in m.global.nrEventGroupsConnect.Items()
        nrLog([item.key, item.value])
    end for
    nrLog("=========== Event Groups HTTP_COMPLETE ===========")
    for each item in m.global.nrEventGroupsComplete.Items()
        nrLog([item.key, item.value])
    end for
    nrLog("==================================================")
end function
