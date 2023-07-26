'**********************************************************
' HTTP Sender Plugin
' Record HTTP_REQUEST and HTTP_RESPONSE events,
' allowing to manually set time references.
'
' Copyright 2023 New Relic Inc. All Rights Reserved. 
'**********************************************************

' Initialize plugin state.
function nrPluginHttpSenderInit() as Void
    print "nrPluginHttpSenderInit"

    'Buffer of events
    m._nrPluginHttpSenderEventArray = []

    'HTTP Request/Response IDs
    m._nrRequestIdentifiers = CreateObject("roAssociativeArray")

    'Domain attribute matching patterns
    m._nrDomainPatterns = CreateObject("roAssociativeArray")
end function

' Add a matching pattern for the domain attribute and substitute it by another string.
function nrPluginHttpSenderAddDomainSubstitution(pattern as String, subs as String) as Void
    m._nrDomainPatterns.AddReplace(pattern, subs)
end function

' Delete a matching pattern created with nrAddDomainSubstitution
function nrPluginHttpSenderDelDomainSubstitution(pattern as String) as Void
    m._nrDomainPatterns.Delete(pattern)
end function

' Send list of events to NRAgent.
'
' @param nr New Relic Agent object.
function nrPluginHttpSenderSync(nr as Object) as Void
    print "Sync events, num events = ", m._nrPluginHttpSenderEventArray.Count()

    m.nr.callFunc("nrGetBackAllSamples", "event", m._nrPluginHttpSenderEventArray)
    
    m._nrPluginHttpSenderEventArray.Clear()
end function

' Send an HTTP_REQUEST event of type RokuSystem.
'
' @param urlReq URL request, roUrlTransfer object.
function nrPluginHttpSenderRequest(urlReq as Object) as Void
    print "nrPluginHttpSenderRequest", urlReq.GetUrl()

    if type(urlReq) = "roUrlTransfer"
        attr = {
            "origUrl": urlReq.GetUrl(),
            "transferIdentity": urlReq.GetIdentity(),
            "method": urlReq.GetRequest()
        }
        _nr_plugin_SendHttpRequest(attr)
    end if
end function

' Send an HTTP_RESPONSE event of type RokuSystem.
'
' @param _url Request URL.
' @param msg A message of type roUrlEvent.
function nrPluginHttpSenderResponse(_url as String, msg as Object) as Void
    print "nrPluginHttpSenderResponse", _url

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
        
        _nr_plugin_SendHttpResponse(attr)
    end if
end function

'----- Private Functions -----

function _nr_plugin_SendHttpRequest(attr as Object) as Void
    domain = _nr_plugin_ExtractDomainFromUrl(attr["origUrl"])
    attr["domain"] = domain
    transId = stri(attr["transferIdentity"])
    m._nrRequestIdentifiers[transId] = _nr_plugin_Timestamp()
    'Clean up old transfers
    toDeleteKeys = []
    for each item in m._nrRequestIdentifiers.Items()
        'More than 10 minutes without a response, delete the request ID
        if _nr_plugin_Timestamp() - item.value > 10*60*1000
            toDeleteKeys.Push(item.key)
        end if
    end for
    for each key in toDeleteKeys
        m._nrRequestIdentifiers.Delete(key)
    end for

    _nr_plugin_SendCustomEvent("RokuSystem", "HTTP_REQUEST", attr)
end function

function _nr_plugin_SendHttpResponse(attr as Object) as Void
    domain = _nr_plugin_ExtractDomainFromUrl(attr["origUrl"])
    attr["domain"] = domain
    transId = stri(attr["transferIdentity"])
    if m._nrRequestIdentifiers[transId] <> invalid
        deltaMs = _nr_plugin_Timestamp() - m._nrRequestIdentifiers[transId]
        attr["timeSinceHttpRequest"] = deltaMs
        m._nrRequestIdentifiers.Delete(transId)
    end if
    
    _nr_plugin_SendCustomEvent("RokuSystem", "HTTP_RESPONSE", attr)
end function

function _nr_plugin_ExtractDomainFromUrl(url as String) as String
    'Extract domain from the URL
    r = CreateObject("roRegex", "\/\/|\/", "")
    arr = r.Split(url)
    if arr.Count() < 2 then return ""
    if arr[0] <> "http:" and arr[0] <> "https:" then return ""
    if arr[1] = "" then return ""
    domain = arr[1]

    ' Check all patterns
    for each item in m._nrDomainPatterns.Items()
        r = CreateObject("roRegex", item.key, "")
        if r.isMatch(domain)
            return r.Replace(domain, item.value)
        end if
    end for

    ' If nothing matches, it just returns the whole domain
    return domain
end function

function _nr_plugin_Timestamp() as LongInteger
    timestampObj = CreateObject("roDateTime")
    timestamp = timestampObj.asSeconds()
    nowMilliseconds = timestampObj.GetMilliseconds()

    timestampLong& = timestamp
    timestampMS& = timestampLong& * 1000 + nowMilliseconds

    return timestampMS&
end function

function _nr_plugin_SendCustomEvent(eventType as String, actionName as String, attr = invalid as Object) as Void
    ev = _nr_plugin_CreateEvent(eventType, actionName)
    if attr <> invalid
        ev.Append(attr)
    end if
    m._nrPluginHttpSenderEventArray.Push(ev)

    print "PLUGIN EVENT "  + eventType + " , " + actionName +  " = ", ev
end function

function _nr_plugin_CreateEvent(eventType as String, actionName as String) as Object
    ev = CreateObject("roAssociativeArray")
    if actionName <> invalid and actionName <> "" then ev["actionName"] = actionName
    if eventType <> invalid and eventType <> "" then ev["eventType"] = eventType
    
    ev["timestamp"] = FormatJson(_nr_plugin_Timestamp())
    ev = _nr_plugin_AddAttributes(ev)
    
    return ev
end function

function _nr_plugin_AddAttributes(ev as Object) as Object
    'TODO: get actual agent version
    agentVersion = "0.0.0"
    'TODO: get actual session ID
    sessionId = "xxxxxx"

    'Add default custom attributes for instrumentation'
    ev.AddReplace("instrumentation.provider", "media")
    ev.AddReplace("instrumentation.name", "roku")
    ev.AddReplace("instrumentation.version", agentVersion)
    ev.AddReplace("newRelicAgent", "RokuAgent")
    ev.AddReplace("newRelicVersion", agentVersion)
    ev.AddReplace("sessionId", sessionId)
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
    ver = _nr_plugin_GetOSVersion(dev)
    ev.AddReplace("osVersion", ver["version"])
    ev.AddReplace("osBuild", ver["build"])
    ev.AddReplace("countryCode", dev.GetUserCountryCode())
    ev.AddReplace("timeZone", dev.GetTimeZone())
    ev.AddReplace("locale", dev.GetCurrentLocale())
    ev.AddReplace("memoryLevel", dev.GetGeneralMemoryLevel())
    ev.AddReplace("connectionType", dev.GetConnectionType())
    'ev.AddReplace("ipAddress", dev.GetExternalIp())
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
    ev.AddReplace("appBuild", appbuild)
    'Uptime
    ev.AddReplace("uptime", Uptime(0))
    
    'TODO: get custom atributes

    'Add custom attributes
    'genCustomAttr = m.nrCustomAttributes["GENERAL_ATTR"]
    'if genCustomAttr <> invalid then ev.Append(genCustomAttr)
    actionName = ev["actionName"]
    'actionCustomAttr = m.nrCustomAttributes[actionName]
    'if actionCustomAttr <> invalid then ev.Append(actionCustomAttr)
    
    'Time Since Load
    'date = CreateObject("roDateTime")
    'ev.AddReplace("timeSinceLoad", date.AsSeconds() - m.nrInitTimestamp)
    
    return ev
end function

function _nr_plugin_GetOSVersion(dev as Object) as Object
    if FindMemberFunction(dev, "GetOSVersion") <> Invalid
        verDict = dev.GetOsVersion()
        return {version: verDict.major + "." + verDict.minor + "." + verDict.revision, build: verDict.build}
    else
        'As roDeviceInfo.GetVersion() has been deprecated in version 9.2, return last supported version or lower as version
        return {version: "<=9.1", build: "0"}
    end if
end function