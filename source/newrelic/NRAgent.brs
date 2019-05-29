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

'Must be called from Main
function NewRelicInit(account as String, apikey as String, screen as Object) as Void
    
    m.global = screen.getGlobalNode()

    m.global.addFields({"nrAccountNumber": account})
    m.global.addFields({"nrInsightsApiKey": apikey})
    m.global.addFields({"nrSessionId": __nrGenerateId()})
    m.global.addFields({"nrEventArray": []})
    m.global.addFields({"nrEventGroupsConnect": CreateObject("roAssociativeArray")})
    m.global.addFields({"nrEventGroupsComplete": CreateObject("roAssociativeArray")})
    m.global.addFields({"nrLastTimestamp": 0})
    m.global.addFields({"nrTicks": 0})
    m.global.addFields({"nrAgentVersion": "0.15.0"})
    m.global.addFields({"nrLogsState": false})
    
    m.syslog = nrStartSysTracker(screen.GetMessagePort())
    
end function

function NewRelicStart() as Void
    nrLog("NewRelicStart")
    
    m.nrTimer = CreateObject("roTimespan")
    m.nrTimer.Mark()
        
    'Init event processor
    m.bgTask = createObject("roSGNode", "NRTask")
    m.bgTask.functionName = "nrTaskMain"
    m.bgTask.control = "RUN"
    
end function

function NewRelicWait(port as Object, foo as Function) as Void
    while(true)
        msg = wait(0, port)
        if nrProcessMessage(msg) = false
            'handle message manually
            foo(msg)
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
        "instantOnRunMode": aa["instant_on_run_mode"]
    }
    nrSendCustomEvent("RokuSystem", "APP_STARTED", attr)
end function

function nrSetCustomAttribute(key as String, value as Object, actionName = "" as String)
    dict = CreateObject("roAssociativeArray")
    dict[key] = value
    nrSetCustomAttributeList(dict, actionName)
end function

function nrSetCustomAttributeList(attr as Object, actionName = "" as String)
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
    m.nrTimeSinceLoad = 0.0
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
    m.nrTimeSinceLoad = m.nrTimer.TotalMilliseconds()
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
    m.nrVideoCounter = m.nrVideoCounter + 1
    nrSendVideoEvent(nrAction("END"))
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
    nrSendVideoEvent(nrAction("BUFFER_START"))
end function

function nrSendBufferEnd() as Void
    nrSendVideoEvent(nrAction("BUFFER_END"))
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
    if msgType = "roSystemLogEvent" Then
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
    if m.nrVideoObject.streamInfo <> invalid
        'BUG: when using playlists reach the end and restart it, the src remains in the last track
        ev.AddReplace(nrAttr("Src"), m.nrVideoObject.streamInfo["streamUrl"])
        'Generate Id from Src (hashing it)
        ba = CreateObject("roByteArray")
        ba.FromAsciiString(m.nrVideoObject.streamInfo["streamUrl"])
        ev.AddReplace(nrAttr("Id"), ba.GetCRC32())
        ev.AddReplace(nrAttr("Bitrate"), m.nrVideoObject.streamInfo["streamBitrate"])
        ev.AddReplace(nrAttr("MeasuredBitrate"), m.nrVideoObject.streamInfo["measuredBitrate"])
    end if
    if m.nrVideoObject.streamingSegment <> invalid
        ev.AddReplace(nrAttr("SegmentBitrate"), m.nrVideoObject.streamingSegment["segBitrateBps"])
    end if
    ev.AddReplace("playerName", "RokuVideoPlayer")
    dev = CreateObject("roDeviceInfo")
    ev.AddReplace("playerVersion", dev.GetVersion())
    ev.AddReplace("sessionDuration", m.nrTimer.TotalMilliseconds() / 1000.0)
    ev.AddReplace("viewId", m.global.nrSessionId + "-" + m.nrVideoCounter.ToStr())
    ev.AddReplace("viewSession", m.global.nrSessionId)
    ev.AddReplace("trackerName", "rokutracker")
    ev.AddReplace("trackerVersion", m.global.nrAgentVersion)
    'Add counters
    ev.AddReplace("numberOfVideos", m.nrVideoCounter + 1)
    ev.AddReplace("numberOfErrors", m.nrNumberOfErrors)
    
    'Add timeSince attributes
    'TODO:
    'timeSinceLastAd -> all
    'totalPlaytime -> all
    if Right(ev["actionName"], 11) = "_BUFFER_END"
        ev.AddReplace("timeSinceBufferBegin", m.nrTimer.TotalMilliseconds() - m.nrTimeSinceBufferBegin)
    end if
    if Right(ev["actionName"], 7) = "_RESUME"
        ev.AddReplace("timeSincePaused", m.nrTimer.TotalMilliseconds() - m.nrTimeSincePaused)
    end if
    ev.AddReplace("timeSinceLastHeartbeat", m.nrTimer.TotalMilliseconds() - m.nrTimeSinceLastHeartbeat)
    ev.AddReplace("timeSinceLoad", m.nrTimer.TotalMilliseconds() - m.nrTimeSinceLoad)
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
        m.global.nrEventGroupsComplete = nrGroupMergeEvent(urlKey, m.global.nrEventGroupsComplete, ev)
    else if actionName = "HTTP_CONNECT"
        m.global.nrEventGroupsConnect = nrGroupMergeEvent(urlKey, m.global.nrEventGroupsConnect, ev)
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

function __nrStateObserver() as Void
    nrLog("---------- State Observer ----------")
    __logVideoInfo()

    if m.nrVideoObject.state = "playing"
        __nrStateTransitionPlaying()
    else if m.nrVideoObject.state = "paused"
        __nrStateTransitionPaused()
    else if m.nrVideoObject.state = "buffering"
        __nrStateTransitionBuffering()
    else if m.nrVideoObject.state = "finished"
        nrSendEnd()
    else if m.nrVideoObject.state = "stopped"
        nrSendEnd()
    else if m.nrVideoObject.state = "error"
        m.nrNumberOfErrors = m.nrNumberOfErrors + 1
        nrSendError(m.nrVideoObject.errorMsg)
    end if
    
    m.nrLastVideoState = m.nrVideoObject.state

end function

function __nrStateTransitionPlaying() as Void
    if m.nrLastVideoState = "paused"
        nrSendResume()
    else if m.nrLastVideoState = "buffering"
        nrSendBufferEnd()
        if m.nrVideoObject.position = 0
            nrSendStart()
        end if
    end if
end function

function __nrStateTransitionPaused() as Void
    if m.nrLastVideoState = "playing"
        nrSendPause()
    end if
end function

function __nrStateTransitionBuffering() as Void
    if m.nrLastVideoState = "none"
        nrSendRequest()
    end if
    nrSendBufferStart()
end function

function __nrIndexObserver() as Void
    nrLog("---------- Index Observer ----------")
    __logVideoInfo()
    
    m.nrVideoCounter = m.nrVideoCounter + 1
    nrSendVideoEvent(nrAction("NEXT"))
    
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

function __logVideoInfo() as Void
    nrLog("====================================")
    nrLog(["Player state = ", m.nrVideoObject.state])
    nrLog(["Current position = ", m.nrVideoObject.position])
    nrLog(["Current duration = ", m.nrVideoObject.duration])
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
    nrLog("====================================")
end function
