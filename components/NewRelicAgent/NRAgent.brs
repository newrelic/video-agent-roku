'**********************************************************
' NRAgent.brs
' New Relic Agent for Roku.
'
' Copyright 2019 New Relic Inc. All Rights Reserved. 
'**********************************************************

sub init()
    m.nrLogsState = false
    m.nrAgentVersion = m.top.version
    print "********************************************************"
    print "   New Relic Agent for Roku v" + m.nrAgentVersion
    print "   Copyright 2020 New Relic Inc. All Rights Reserved."
    print "********************************************************"
end sub

'========================='
' General Agent functions '
'========================='

'Must be called from Main after scene creation
function NewRelicInit(account as String, apikey as String) as Void
    
    m.nrAccountNumber = account
    m.nrInsightsApiKey = apikey
    m.nrSessionId = __nrGenerateId()
    m.nrEventArray = []
    m.nrEventGroupsConnect = CreateObject("roAssociativeArray")
    m.nrEventGroupsComplete = CreateObject("roAssociativeArray")
    m.nrBackupAttributes = CreateObject("roAssociativeArray")
    m.nrLastTimestamp = 0
    m.nrTicks = 0
    
    date = CreateObject("roDateTime")
    m.nrInitTimestamp = date.AsSeconds()
    
    'Init main timer
    m.nrTimer = CreateObject("roTimespan")
    m.nrTimer.Mark()

    'Create and configure NRTask
    m.bgTask = m.top.findNode("NRTask")
    m.bgTask.setField("accountNumber", m.nrAccountNumber)
    m.bgTask.setField("apiKey", m.nrInsightsApiKey)
    
    'Init harvest timer
    m.nrHarvestTimer = m.top.findNode("nrHarvestTimer")
    m.nrHarvestTimer.ObserveField("fire", "nrHarvestTimerHandler")
    m.nrHarvestTimer.control = "start"
    
    nrLog(["NewRelicInit, m = ", m])
    
end function

'TODO: deprecated, instead provide a function to process events to be called inside app event loop
function NewRelicWait(port as Object, foo as Function) as Void
    syslog = nrStartSysTracker(port)

    while(true)
        msg = wait(0, port)
        if nrProcessMessage(msg) = false
            'handle message manually
            res = foo(msg)
            if res = false then return
        end if
    end while
end function

function nrSendHTTPError(info as Object) as Void
    attr = nrAddCommonHTTPAttr(info)   
    nrSendCustomEvent("RokuSystem", "HTTP_ERROR", attr)
end function

function nrSendHTTPConnect(info as Object) as Void
    attr = nrAddCommonHTTPAttr(info)
    nrGroupNewEvent(attr, "HTTP_CONNECT")
end function

function nrSendHTTPComplete(info as Object) as Void
    attr = {
        "bytesDownloaded": info["BytesDownloaded"],
        "bytesUploaded": info["BytesUploaded"],
        "connectTime": info["ConnectTime"],
        "contentType": info["ContentType"],
        "dnsLookupTime": info["DNSLookupTime"],
        "downloadSpeed": info["DownloadSpeed"],
        "firstByteTime": info["FirstByteTime"],
        "transferTime": info["TransferTime"],
        "uploadSpeed": info["UploadSpeed"],
    }
    commonAttr = nrAddCommonHTTPAttr(info)
    attr.Append(commonAttr)
    nrGroupNewEvent(attr, "HTTP_COMPLETE")
end function

function nrSendBandwidth(info as Object) as Void
    attr = {
        "bandwidth": info["bandwidth"]
    }
    nrSendCustomEvent("RokuSystem", "BANDWIDTH_MINUTE", attr)
end function

function nrAppStarted(aa as Object) as Void
    attr = {
        "lastExitOrTerminationReason": aa["lastExitOrTerminationReason"],
        "splashTime": aa["splashTime"],
        "instantOnRunMode": aa["instant_on_run_mode"],
        "launchSource": aa["source"]
    }
    nrSendCustomEvent("RokuSystem", "APP_STARTED", attr)
end function

function nrSceneLoaded(sceneName as String) as Void
    nrSendCustomEvent("RokuSystem", "SCENE_LOADED", {"sceneName": sceneName})
end function

function nrSetCustomAttribute(key as String, value as Object, actionName = "" as String) as Void
    dict = CreateObject("roAssociativeArray")
    dict[key] = value
    nrSetCustomAttributeList(dict, actionName)
end function

'TODO: fix global stuff
function nrSetCustomAttributeList(attr as Object, actionName = "" as String) as Void
    return
    dictName = actionName
    if dictName = "" then dictName = "GENERAL_ATTR"
    
    if m.global[dictName] = invalid
        m.global.addField(dictName, "assocarray", false)
        m.global[dictName] = CreateObject("roAssociativeArray")
    end if
    
    actionDict = m.global[dictName]
    
    actionDict.Append(attr)
    m.global[dictName] = actionDict
    
    nrLog(["Custom Attributes: ", m.global[dictName]])
end function

'======================='
' Video Agent functions '
'======================='

function NewRelicVideoStart(videoObject as Object) as Void
    nrLog("NewRelicVideoStart")

    'Current state
    m.nrLastVideoState = "none"
    m.nrIsAd = false
    m.nrVideoCounter = 0
    m.nrIsInitialBuffering = false
    'Setup event listeners 
    videoObject.observeField("state", "__nrStateObserver")
    videoObject.observeField("contentIndex", "__nrIndexObserver")
    'Store video object
    m.nrVideoObject = videoObject
    'Init heartbeat timer
    m.hbTimer = CreateObject("roSGNode", "Timer")
    m.hbTimer.repeat = true
    m.hbTimer.duration = 30
    m.hbTimer.observeField("fire", "__nrHeartbeatHandler")
    m.hbTimer.control = "start"
    'Timestamps for timeSince attributes
    m.nrTimeSinceBufferBegin = 0.0
    m.nrTimeSinceLastHeartbeat = 0.0
    m.nrTimeSincePaused = 0.0
    m.nrTimeSinceRequested = 0.0
    m.nrTimeSinceStarted = 0.0
    m.nrTimeSinceTrackerReady = 0.0
    'Counters
    m.nrNumberOfErrors = 0
    
    'Player Ready
    nrSendPlayerReady()
end function

function nrSendPlayerReady() as Void
    m.nrTimeSinceTrackerReady = m.nrTimer.TotalMilliseconds()
    nrSendVideoEvent("PLAYER_READY")
end function

function nrSendRequest() as Void
    m.nrTimeSinceRequested = m.nrTimer.TotalMilliseconds()
    nrSendVideoEvent(nrAction("REQUEST"))
end function

function nrSendStart() as Void
    m.nrNumberOfErrors = 0
    m.nrTimeSinceStarted = m.nrTimer.TotalMilliseconds()
    nrSendVideoEvent(nrAction("START"))
end function

function nrSendEnd() as Void
    nrSendVideoEvent(nrAction("END"))
    m.nrVideoCounter = m.nrVideoCounter + 1
end function

function nrSendPause() as Void
    m.nrTimeSincePaused = m.nrTimer.TotalMilliseconds()
    nrSendVideoEvent(nrAction("PAUSE"))
end function

function nrSendResume() as Void
    nrSendVideoEvent(nrAction("RESUME"))
end function

function nrSendBufferStart() as Void
    m.nrTimeSinceBufferBegin = m.nrTimer.TotalMilliseconds()
    
    if m.nrTimeSinceStarted = 0
        m.nrIsInitialBuffering = true
    else
        m.nrIsInitialBuffering = false
    end if
    nrSendVideoEvent(nrAction("BUFFER_START"), {"isInitialBuffering": m.nrIsInitialBuffering})
end function

function nrSendBufferEnd() as Void
    if m.nrTimeSinceStarted = 0
        m.nrIsInitialBuffering = true
    else
        m.nrIsInitialBuffering = false
    end if
    nrSendVideoEvent(nrAction("BUFFER_END"), {"isInitialBuffering": m.nrIsInitialBuffering})
end function

function nrSendError(msg as String) as Void
    errMsg = msg
    if msg = invalid or msg = ""
        errMsg = "UNKNOWN"
    end if
    nrSendVideoEvent(nrAction("ERROR"), {"errorMessage": errMsg})
end function

'Used by all video senders
function nrSendVideoEvent(actionName as String, attr = invalid) as Void
    ev = nrCreateEvent("RokuVideo", actionName)
    ev = nrAddVideoAttributes(ev)
    if type(attr) = "roAssociativeArray"
       ev.Append(attr)
    end if
    nrRecordEvent(ev)
    'Backup attributes (cloning it)
    m.nrBackupAttributes = {}
    m.nrBackupAttributes.Append(ev)
end function

function nrSendSystemEvent(actionName as String, attr = invalid) as Void
    nrSendCustomEvent("RokuSystem", actionName, attr)
end function

function nrSendBackupVideoEvent(actionName as String, attr = invalid) as Void
    'Use attributes in the backup (m.nrBackupAttributes) and recalculate some of them.
    ev = m.nrBackupAttributes
    
    '- Set correct actionName
    backupActionName = ev["actionName"]
    ev["actionName"] = actionName
    '- Set current timestamp
    backupTimestamp = ev["timestamp"]
    ev["timestamp"] = FormatJson(nrTimestamp())
    '- Recalculate playhead, adding timestamp offset, except if last action is PAUSE
    if not isAction("PAUSE", backupActionName) 
        lint& = ParseJson(ev["timestamp"]) - ParseJson(backupTimestamp)
        offsetTime = lint&
        nrLog(["Offset time = ", offsetTime])
        if ev["contentPlayhead"] <> invalid then ev["contentPlayhead"] = ev["contentPlayhead"] + offsetTime
        if ev["adPlayhead"] <> invalid then ev["adPlayhead"] = ev["adPlayhead"] + offsetTime
    end if
    '- Regen memory level
    dev = CreateObject("roDeviceInfo")
    ev["memoryLevel"] = dev.GetGeneralMemoryLevel()
    '- Regen is muted
    if m.nrVideoObject <> invalid
        if ev["contentIsMuted"] <> invalid then ev["contentIsMuted"] = m.nrVideoObject.mute
        if ev["adIsMuted"] <> invalid then ev["adIsMuted"] = m.nrVideoObject.mute
    end if
    '- Regen HDMI connected
    hdmi = CreateObject("roHdmiStatus")
    ev["hdmiIsConnected"] = hdmi.IsConnected()
    '- Recalculate all timeSinceXXX, adding timestamp offset
    ev["timeSinceLastHeartbeat"] = ev["timeSinceLastHeartbeat"] + offsetTime '(ms)
    ev["timeSinceLastKeypress"] = dev.TimeSinceLastKeypress() * 1000
    ev["timeSinceLoad"] = ev["timeSinceLoad"] + offsetTime/1000 ' (s)
    ev["timeSinceRequested"] = ev["timeSinceRequested"] + offsetTime ' (ms)
    ev["timeSinceStarted"] = ev["timeSinceStarted"] + offsetTime ' (ms)
    ev["timeSinceTrackerReady"] = ev["timeSinceTrackerReady"] + offsetTime ' (ms)
    'PROBLEMS:
    '- Custom attributes remains the same, could be problematic depending on the app
    
    nrLog(["nrSendBackupVideoEvent => ", ev])
    
    nrRecordEvent(ev)
    
end function

'=================='
' Helper functions '
'=================='

function nrStartSysTracker(port) as Object
    syslog = CreateObject("roSystemLog")
    
    syslog.SetMessagePort(port)
    syslog.EnableType("http.error")
    syslog.EnableType("http.connect")
    syslog.EnableType("bandwidth.minute")
    syslog.EnableType("http.complete")
    
    return syslog
end function

function nrProcessMessage(msg as Object) as Boolean
    msgType = type(msg)
    if msgType = "roSystemLogEvent" then
        i = msg.GetInfo()
        if i.LogType = "http.error"
            nrSendHTTPError(i)
            return true
        else if i.LogType = "http.connect" 
            nrSendHTTPConnect(i)
            return true
        else if i.LogType = "http.complete"
            nrSendHTTPComplete(i)
            return true
        else if i.LogType = "bandwidth.minute"
            nrSendBandwidth(i)
            return true
        end If
    end if
    
    return false
end function

function nrAddCommonHTTPAttr(info as Object) as Object
    attr = {
        "httpCode": info["HttpCode"],
        "method": info["Method"],
        "origUrl": info["OrigUrl"],
        "status": info["Status"],
        "targetIp": info["TargetIp"],
        "url": info["Url"]
    }
    return attr
end function

function nrAction(action as String) as String
    if m.nrIsAd = true
        return "AD_" + action
    else
        return "CONTENT_" + action
    end if
end function

function isAction(name as String, action as String) as Boolean
    regExp = "(CONTENT|AD)_" + name
    r = CreateObject("roRegex", regExp, "")
    return r.isMatch(action)
end function

function nrAttr(attribute as String) as String
    if m.nrIsAd = true
        return "ad" + attribute
    else
        return "content" + attribute
    end if
end function

function nrAddVideoAttributes(ev as Object) as Object
    ev.AddReplace(nrAttr("Duration"), m.nrVideoObject.duration * 1000)
    ev.AddReplace(nrAttr("Playhead"), m.nrVideoObject.position * 1000)
    ev.AddReplace(nrAttr("IsMuted"), m.nrVideoObject.mute)
    streamUrl = __nrGenerateStreamUrl()
    ev.AddReplace(nrAttr("Src"), streamUrl)
    'Generate Id from Src (hashing it)
    ba = CreateObject("roByteArray")
    ba.FromAsciiString(streamUrl)
    ev.AddReplace(nrAttr("Id"), ba.GetCRC32())
    if m.nrVideoObject.streamInfo <> invalid
        ev.AddReplace(nrAttr("Bitrate"), m.nrVideoObject.streamInfo["streamBitrate"])
        ev.AddReplace(nrAttr("MeasuredBitrate"), m.nrVideoObject.streamInfo["measuredBitrate"])
    end if
    if m.nrVideoObject.streamingSegment <> invalid
        ev.AddReplace(nrAttr("SegmentBitrate"), m.nrVideoObject.streamingSegment["segBitrateBps"])
    end if
    ev.AddReplace("playerName", "RokuVideoPlayer")
    dev = CreateObject("roDeviceInfo")
    ver = __nrParseVersion(dev.GetVersion())
    ev.AddReplace("playerVersion", ver["version"])
    ev.AddReplace("sessionDuration", m.nrTimer.TotalMilliseconds() / 1000.0)
    ev.AddReplace("viewId", m.nrSessionId + "-" + m.nrVideoCounter.ToStr())
    ev.AddReplace("viewSession", m.nrSessionId)
    ev.AddReplace("trackerName", "rokutracker")
    ev.AddReplace("trackerVersion", m.nrAgentVersion)
    ev.AddReplace("videoFormat", m.nrVideoObject.videoFormat)
    if (m.nrVideoObject <> invalid) then ev.AddReplace("isPlaylist", m.nrVideoObject.contentIsPlaylist)
    'Add counters
    ev.AddReplace("numberOfVideos", m.nrVideoCounter + 1)
    ev.AddReplace("numberOfErrors", m.nrNumberOfErrors)
    
    'Add timeSince attributes
    'TODO:
    'timeSinceLastAd -> all
    'totalPlaytime -> all
    if isAction("BUFFER_END", ev["actionName"])
        ev.AddReplace("timeSinceBufferBegin", m.nrTimer.TotalMilliseconds() - m.nrTimeSinceBufferBegin)
    end if
    if isAction("RESUME", ev["actionName"])
        ev.AddReplace("timeSincePaused", m.nrTimer.TotalMilliseconds() - m.nrTimeSincePaused)
    end if
    ev.AddReplace("timeSinceLastHeartbeat", m.nrTimer.TotalMilliseconds() - m.nrTimeSinceLastHeartbeat)
    ev.AddReplace("timeSinceRequested", m.nrTimer.TotalMilliseconds() - m.nrTimeSinceRequested)
    ev.AddReplace("timeSinceStarted", m.nrTimer.TotalMilliseconds() - m.nrTimeSinceStarted)
    ev.AddReplace("timeSinceTrackerReady", m.nrTimer.TotalMilliseconds() - m.nrTimeSinceTrackerReady)
    
    return ev
end function

function nrGroupNewEvent(ev as Object, actionName as String) as Void
    if ev["Url"] = invalid then return
    urlKey = ev["Url"]
    matchUrl = nrParseVideoStreamUrl(urlKey)
    if matchUrl <> "" then urlKey = matchUrl
    ev["actionName"] = actionName
    
    if actionName = "HTTP_COMPLETE"
        m.nrEventGroupsComplete = nrGroupMergeEvent(urlKey, m.nrEventGroupsComplete, ev)
    else if actionName = "HTTP_CONNECT"
        m.nrEventGroupsConnect = nrGroupMergeEvent(urlKey, m.nrEventGroupsConnect, ev)
    end if
end function

function nrGroupMergeEvent(urlKey as String, group as Object, ev as Object) as Object
    evGroup = group[urlKey]
    if evGroup = invalid
        'Create new group from event
        ev["counter"] = 1
        ev["initialTimestamp"] = nrTimestamp()
        ev["finalTimestamp"] = ev["initialTimestamp"]
        group[urlKey] = ev
    else
        'Add new event to existing group
        evGroup["counter"] = evGroup["counter"] + 1
        evGroup["finalTimestamp"] = nrTimestamp()
        
        'Add all numeric values
        if ev["actionName"] = "HTTP_COMPLETE"
            'Summations
            evGroup["bytesDownloaded"] = evGroup["bytesDownloaded"] + ev["bytesDownloaded"]
            evGroup["bytesUploaded"] = evGroup["bytesUploaded"] + ev["bytesUploaded"]
            'Averages, we will divide it by count right before sending the event
            evGroup["transferTime"] = evGroup["transferTime"] + ev["transferTime"]
            evGroup["connectTime"] = evGroup["connectTime"] + ev["connectTime"]
            evGroup["dnsLookupTime"] = evGroup["dnsLookupTime"] + ev["dnsLookupTime"]
            evGroup["downloadSpeed"] = evGroup["downloadSpeed"] + ev["downloadSpeed"]
            evGroup["uploadSpeed"] = evGroup["uploadSpeed"] + ev["uploadSpeed"]
            evGroup["firstByteTime"] = evGroup["firstByteTime"] + ev["firstByteTime"]
        end if 
        
        group[urlKey] = evGroup
    end if
    return group
end function

function nrParseVideoStreamUrl(url as String) as String
    r = CreateObject("roRegex", "\/\/|\/", "")
    arr = r.Split(url)
    
    if arr.Count() = 0 then return ""
    if arr[0] <> "http:" and arr[0] <> "https:" then return ""
    
    lastItem = arr[arr.Count() - 1]
    r = CreateObject("roRegex", "^\w+\.\w+$", "")
    
    if r.IsMatch(lastItem) = false then return ""
    
    matchUrl = Left(url, url.Len() - lastItem.Len())
    
    return matchUrl
end function

'========================'
' Observers and Handlers '
'========================'

function nrHarvestTimerHandler() as Void
    nrLog("--- nrHarvestTimerHandler ---")
    
    'NRTask still running
    if m.bgTask.state = "RUN"
        nrLog("NRTask still running, abort")
        return
    end if
    
    nrProcessGroupedEvents()
    m.bgTask.control = "RUN"
end function

function __nrStateObserver() as Void
    nrLog("---------- State Observer ----------")
    __logVideoInfo()

    if m.nrVideoObject.state = "playing"
        __nrStateTransitionPlaying()
    else if m.nrVideoObject.state = "paused"
        __nrStateTransitionPaused()
    else if m.nrVideoObject.state = "buffering"
        __nrStateTransitionBuffering()
    else if m.nrVideoObject.state = "finished" or m.nrVideoObject.state = "stopped"
        __nrStateTransitionEnd()
    else if m.nrVideoObject.state = "error"
        __nrStateTransitionError()
    end if
    
    m.nrLastVideoState = m.nrVideoObject.state

end function

function __nrStateTransitionPlaying() as Void
    nrLog("__nrStateTransitionPlaying")
    if m.nrLastVideoState = "paused"
        nrSendResume()
    else if m.nrLastVideoState = "buffering"
        'if current Src is equal to previous, send start, otherwise not
        currentSrc = __nrGenerateStreamUrl()
        lastSrc = m.nrBackupAttributes["contentSrc"]
        if lastSrc = invalid then lastSrc = m.nrBackupAttributes["adSrc"]
        
        'Store intial buffering state and send buffer end
        shouldSendStart = m.nrIsInitialBuffering
        nrSendBufferEnd()
        
        if m.nrVideoObject.position = 0
            if lastSrc = currentSrc OR m.nrVideoObject.contentIsPlaylist = false
                'Send Start only if initial start not sent already
                if shouldSendStart then nrSendStart()
            end if
        end if
    end if
end function

function __nrStateTransitionPaused() as Void
    nrLog("__nrStateTransitionPaused")
    if m.nrLastVideoState = "playing"
        nrSendPause()
    end if
end function

function __nrStateTransitionBuffering() as Void
    nrLog("__nrStateTransitionBuffering")
    if m.nrLastVideoState = "none"
        nrSendRequest()
    end if
    nrSendBufferStart()
end function

function __nrStateTransitionEnd() as Void
    nrLog("__nrStateTransitionEnd")
    if m.nrLastVideoState = "buffering"
        nrSendBufferEnd()
    end if
    nrSendEnd()
end function

function __nrStateTransitionError() as Void
    nrLog("__nrStateTransitionError")
    if m.nrLastVideoState = "buffering"
        nrSendBufferEnd()
    end if
    m.nrNumberOfErrors = m.nrNumberOfErrors + 1
    nrSendError(m.nrVideoObject.errorMsg)
end function

'This corresponds to the NEXT event, it happens when the playlist index changes
function __nrIndexObserver() as Void
    nrLog("---------- Index Observer ----------")
    __logVideoInfo()
    
    '- Use nrSendBackupVideoEvent to send the END using previous video attributes
    nrSendBackupVideoEvent(nrAction("END"))
    '- Send REQUEST and START using normal send, with current video attributes
    m.nrVideoCounter = m.nrVideoCounter + 1
    nrSendRequest()
    nrSendStart()
end function

function __nrHeartbeatHandler() as Void
    'Only send while it is playing (state is not "none" or "finished")
    if m.nrVideoObject.state <> "none" and m.nrVideoObject.state <> "finished"
        nrSendVideoEvent(nrAction("HEARTBEAT"))
        m.nrTimeSinceLastHeartbeat = m.nrTimer.TotalMilliseconds()
    end if
end function

function __nrGenerateId() as String
    timestamp = CreateObject("roDateTime").asSeconds()
    randStr = "ID" + Str(timestamp) + Str(Rnd(0) * 1000.0)
    ba = CreateObject("roByteArray")
    ba.FromAsciiString(randStr)
    digest = CreateObject("roEVPDigest")
    digest.Setup("md5")
    result = digest.Process(ba)
    return result
end function

function __nrGenerateStreamUrl() as String
    if m.nrVideoObject.streamInfo <> invalid
        return m.nrVideoObject.streamInfo["streamUrl"]
    else
        if (m.nrVideoObject.contentIsPlaylist)
            currentChild = m.nrVideoObject.content.getChild(m.nrVideoObject.contentIndex)
            if currentChild <> invalid
                'Get url from content child
                return currentChild.url
            end if
        end if
    end if
    return ""
end function

'**********************************************************
' Code from old NRUtils.brs file
'**********************************************************

'Used to send generic events
function nrSendCustomEvent(eventType as String, actionName as String, attr = invalid as Object) as Void
    nrLog("nrSendCustomEvent")
    ev = nrCreateEvent(eventType, actionName)
    if attr <> invalid
        ev.Append(attr)
    end if
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
    
    ev["timestamp"] = FormatJson(nrTimestamp())
    ev = nrAddAttributes(ev)
    
    return ev
end function

function nrTimestamp() as LongInteger
    timestamp = CreateObject("roDateTime").asSeconds()
    timestampLong& = timestamp
    timestampMS& = timestampLong& * 1000
    
    if timestamp = m.nrLastTimestamp
        m.nrTicks = m.nrTicks + 1
    else
        m.nrTicks = 0
    end if
    
    timestampMS& = timestampMS& + m.nrTicks
    m.nrLastTimestamp = timestamp
    
    return timestampMS&
end function

function nrAddAttributes(ev as Object) as Object
    ev.AddReplace("newRelicAgent", "RokuAgent")
    ev.AddReplace("newRelicVersion", m.nrAgentVersion)
    ev.AddReplace("sessionId", m.nrSessionId)
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
    ver = __nrParseVersion(dev.GetVersion())
    ev.AddReplace("osVersionString", dev.GetVersion())
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
    if appbuild = 0 then appbuild = 1
    ev.AddReplace("appBuild", appbuild)
    
    'Add custom attributes
    'TODO: fix global stuff
    'genCustomAttr = m.global["GENERAL_ATTR"]
    'if genCustomAttr <> invalid then ev.Append(genCustomAttr)
    'actionName = ev["actionName"]
    'actionCustomAttr = m.global[actionName]
    'if actionCustomAttr <> invalid then ev.Append(actionCustomAttr)
    
    'Time Since Load
    date = CreateObject("roDateTime")
    ev.AddReplace("timeSinceLoad", date.AsSeconds() - m.nrInitTimestamp)
    
    return ev
end function

function nrProcessGroupedEvents() as Void
    'Convert groups into custom events and flush the groups dictionaries
    
    nrLog("-- Process Grouped Events --")
    __logEvGroups()
    
    if m.nrEventGroupsConnect.Count() > 0
        nrConvertGroupsToEvents(m.nrEventGroupsConnect)
        m.nrEventGroupsConnect = {}
    end if
    
    if m.nrEventGroupsComplete.Count() > 0
        nrConvertGroupsToEvents(m.nrEventGroupsComplete)
        m.nrEventGroupsComplete = {}
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
    if m.nrEventArray.Count() < 500
        m.nrEventArray.Push(event)
        
        nrLog("====================================")
        nrLog(["RECORD NEW EVENT = ", m.nrEventArray.Peek()])
        nrLog(["EVENTARRAY SIZE = ", m.nrEventArray.Count()])
        nrLog("====================================")
        '__logVideoInfo()
    else
        nrLog("Events overflow, discard event")
    end if
end function

'Extracts the first event from the list. Returns an roAssociativeArray as argument
function nrExtractEvent() as Object
    res = m.nrEventArray.Pop()
    return res
end function

function nrLog(msg as Dynamic) as Void
    if m.nrLogsState = true
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
    m.nrLogsState = state
end function

function __logEvGroups() as Void
    nrLog("============ Event Groups HTTP_CONNECT ===========")
    for each item in m.nrEventGroupsConnect.Items()
        nrLog([item.key, item.value])
    end for
    nrLog("=========== Event Groups HTTP_COMPLETE ===========")
    for each item in m.nrEventGroupsComplete.Items()
        nrLog([item.key, item.value])
    end for
    nrLog("==================================================")
end function

function __logVideoInfo() as Void
    nrLog("====================================")
    if (m.nrVideoObject <> invalid)
        nrLog(["Player state = ", m.nrVideoObject.state])
        nrLog(["Current position = ", m.nrVideoObject.position])
        nrLog(["Current duration = ", m.nrVideoObject.duration])
        if (m.nrVideoObject.contentIsPlaylist)
            nrLog(["Video content playlist size = ", m.nrVideoObject.content.getChildCount()])
            nrLog(["Video content index = ", m.nrVideoObject.contentIndex])
            currentChild = m.nrVideoObject.content.getChild(m.nrVideoObject.contentIndex)
            if currentChild <> invalid
                nrLog(["Current child url = ", currentChild.url])
                nrLog(["Current child title = ", currentChild.title])
            else
                nrLog("Current child is invalid")
            end if
        else
            nrLog("Content is not a playlist")
        end if
        nrLog(["Muted = ", m.nrVideoObject.mute])
        if m.nrVideoObject.streamInfo <> invalid
            nrLog(["Stream URL = ", m.nrVideoObject.streamInfo["streamUrl"]])
            nrLog(["Stream Bitrate = ", m.nrVideoObject.streamInfo["streamBitrate"]])
            nrLog(["Stream Measured Bitrate = ", m.nrVideoObject.streamInfo["measuredBitrate"]])
            nrLog(["Stream isResumed = ", m.nrVideoObject.streamInfo["isResumed"]])
            nrLog(["Stream isUnderrun = ", m.nrVideoObject.streamInfo["isUnderrun"]])
        end if
        if m.nrVideoObject.streamingSegment <> invalid
            nrLog(["Segment URL = ", m.nrVideoObject.streamingSegment["segUrl"]])
            nrLog(["Segment Bitrate = ", m.nrVideoObject.streamingSegment["segBitrateBps"]])
            nrLog(["Segment Sequence = ", m.nrVideoObject.streamingSegment["segSequence"]])
            nrLog(["Segment Start time = ", m.nrVideoObject.streamingSegment["segStartTime"]])
        end if
        nrLog(["Manifest data = ", m.nrVideoObject.manifestData])
    else
        nrLog("m.nrVideoObject is invalid")
    end if
    nrLog("====================================")
end function

function __logEventArray() as Void
    nrLog("=========== EVENT ARRAY ============")
    for each ev in m.nrEventArray
        nrLog(ev)
        nrLog("----------------------------------")
    end for
    nrLog("====================================")
end function

function __nrParseVersion(verStr as String) as Object
    return {version: verStr.Mid(2, 3) + "." + verStr.Mid(5, 1), build: verStr.Mid(8, 4)}
end function
