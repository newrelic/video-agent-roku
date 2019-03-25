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
function NewRelic(account as String, apikey as String, screen as Object) as Void
    
    m.global = screen.getGlobalNode()
    
    nrLog("NewRelic")

    m.global.addFields({"nrAccountNumber": account})
    m.global.addFields({"nrInsightsApiKey": apikey})
    m.global.addFields({"nrSessionId": __nrGenerateId()})
    m.global.addFields({"nrEventArray": []})
    m.global.addFields({"nrEventGroupsConnect": CreateObject("roAssociativeArray")})
    m.global.addFields({"nrEventGroupsComplete": CreateObject("roAssociativeArray")})
    m.global.addFields({"nrLastTimestamp": 0})
    m.global.addFields({"nrTicks": 0})
    m.global.addFields({"nrAgentVersion": "0.10.0"})
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

'Used to send generic events
function nrSendCustomEvent(eventType as String, actionName as String, attr as Object) as Void
    ev = nrCreateEvent(eventType, actionName)
    ev.Append(attr)
    nrRecordEvent(ev)
end function

function nrSendHTTPError(info as Object) as Void
    attr = nrAddCommonHTTPAttr(info)   
    nrSendCustomEvent("RokuEvent", "HTTP_ERROR", attr)
end function

function nrSendHTTPConnect(info as Object) as Void
    'TODO: group event instead of sending it
    attr = nrAddCommonHTTPAttr(info)
    'nrSendCustomEvent("RokuEvent", "HTTP_CONNECT", attr)
    
    nrGroupNewEvent(attr, "HTTP_CONNECT")
end function

function nrSendHTTPComplete(info as Object) as Void
    'TODO: group event instead of sending it
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
    'nrSendCustomEvent("RokuEvent", "HTTP_COMPLETE", attr)
    
    nrGroupNewEvent(attr, "HTTP_COMPLETE")
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

function nrSendBandwidth(info as Object) as Void
    attr = {
        "bandwidth": info["bandwidth"]
    }
    nrSendCustomEvent("RokuEvent", "BANDWIDTH_MINUTE", attr)
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
    ev = nrCreateEvent("RokuVideoEvent", actionName)
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

function nrCreateEvent(eventType as String, actionName as String) as Object
    ev = CreateObject("roAssociativeArray")
    if actionName <> invalid and actionName <> "" then ev["actionName"] = actionName
    if eventType <> invalid and eventType <> "" then ev["eventType"] = eventType
    timestamp& = CreateObject("roDateTime").asSeconds()
    timestampMS& = timestamp& * 1000
    
    if timestamp& = m.global.nrLastTimestamp
        m.global.nrTicks = m.global.nrTicks + 1
    else
        m.global.nrTicks = 0
    end if
    
    timestampMS& = timestampMS& + m.global.nrTicks
    
    ev["timestamp"] = timestampMS&
    m.global.nrLastTimestamp = timestamp&
    
    ev = nrAddAttributes(ev)
    
    return ev
end function

'TODO: some attributes are not going to change, we can create it only once and then add every time

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
    ev.AddReplace("videoId", m.global.nrSessionId + "-" + m.nrVideoCounter.ToStr())
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
    appbuild = app.GetValue("build_version").ToInt()
    if appbuild = 0 then appbuild = 1
    ev.AddReplace("appBuild", appbuild)
    
    return ev
end function

'TODO: detect urls with same schema htt... /*.ext and group them, otherwise the chuks create hundreds of requests
' Where "ext" can be ts, mp4, etc

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
    
    __logEvGroups()
end function

function nrGroupMergeEvent(urlKey as String, group as Object, ev as Object) as Object
    evGroup = group[urlKey]
    if evGroup = invalid
        'Create new group from event
        ev["counter"] = 1
        group[urlKey] = ev
    else
        evGroup["counter"] = evGroup["counter"] + 1
        'TODO: merge event to existing group -> add numeric values and we will divide by counter to get the mean when creating the insights event 
        group[urlKey] = evGroup
    end if
    return group       
end function

'TODO: create function to parse URLs
function nrParseVideoStreamUrl(url as String) as String
    r = CreateObject("roRegex", "\/\/|\/", "")
    arr = r.Split(url)
    nrLog(["Parse URL = ", arr])
    if arr.Count() = 0 then return ""
    if arr[0] <> "http:" and arr[0] <> "https:" then return ""
    
    lastItem = arr[arr.Count() - 1]
    
    r = CreateObject("roRegex", "^\w+\.\w+$", "")
    if r.IsMatch(lastItem) = false then return ""
    
    matchUrl = Left(url, url.Len() - lastItem.Len())
    nrLog(["Match URL = ", matchUrl])
    
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

function __logEvGroups() as Void
    nrLog("============ Event Groups HTTP_CONNECT ===========")
    for each item in m.global.nrEventGroupsConnect.Items()
        print item.key, item.value
    end for
    nrLog("=========== Event Groups HTTP_COMPLETE ===========")
    for each item in m.global.nrEventGroupsComplete.Items()
        print item.key, item.value
    end for
    nrLog("==================================================")
end function