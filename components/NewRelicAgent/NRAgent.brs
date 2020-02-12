'**********************************************************
' NRAgent.brs
' New Relic Agent for Roku.
' Minimum requirements: FW 8.1
'
' Copyright 2019 New Relic Inc. All Rights Reserved. 
'**********************************************************

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
    
    if m.nrLogsState = invalid
        m.nrLogsState = false
    end if
    
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
