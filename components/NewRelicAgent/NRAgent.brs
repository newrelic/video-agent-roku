'**********************************************************
' NRAgent.brs
' New Relic Agent Component.
'
' Copyright 2019 New Relic Inc. All Rights Reserved. 
'**********************************************************

sub init()
    m.nrLogsState = false
    m.nrAgentVersion = m.top.version
    m.eventApiUrl = ""
    m.logApiUrl = ""
    m.metricApiUrl = ""
    m.nrRegion = "US"
    m.testServer = "http://my.test.server:8888"
    print "************************************************************"
    print "   New Relic Agent for Roku v" + m.nrAgentVersion
    print "   Copyright 2019-2023 New Relic Inc. All Rights Reserved."
    print "************************************************************"
end sub

'=========================='
' Public Wrapped Functions '
'=========================='

function NewRelicInit(account as String, apikey as String,appName as String, region as String, appToken = "" as String) as Void
    'Session
    m.nrAccountNumber = account
    m.nrInsightsApiKey = apikey
    m.nrMobileAppToken = appToken
    appConfig = nrCreateAppInfo()
    m.nrDeviceInfo = appConfig.deviceInfo
    m.appName = appName
    m.nrRegion = region
    dataToken = nrConnect(appToken, appConfig.appInfo)
    m.dataToken = dataToken
    m.nrSessionId = nrGenerateId()
    'Reservoir sampling for events
    m.nrEventArray = []
    m.nrEventArrayIndex = 0
    m.nrEventArrayNormalK = 400
    m.nrEventArrayMinK = 40
    m.nrEventArrayDeltaK = 40
    m.nrEventArrayK = m.nrEventArrayNormalK
    'Harvest cycles for events
    m.nrEventHarvestTimeNormal = 60
    m.nrEventHarvestTimeMax = 600
    m.nrEventHarvestTimeDelta = 60
    'Reservoir sampling for logs
    m.nrLogArray = []
    m.nrLogArrayIndex = 0
    m.nrLogArrayNormalK = 400
    m.nrLogArrayMinK = 40
    m.nrLogArrayDeltaK = 40
    m.nrLogArrayK = m.nrLogArrayNormalK
    'Harvest cycles for logs
    m.nrLogHarvestTimeNormal = 60
    m.nrLogHarvestTimeMax = 600
    m.nrLogHarvestTimeDelta = 60
    'Reservoir sampling for metrics
    m.nrMetricArray = []
    m.nrMetricArrayIndex = 0
    m.nrMetricArrayNormalK = 400
    m.nrMetricArrayMinK = 40
    m.nrMetricArrayDeltaK = 40
    m.nrMetricArrayK = m.nrMetricArrayNormalK
    'Harvest cycles for metrics
    m.nrMetricHarvestTimeNormal = 60
    m.nrMetricHarvestTimeMax = 600
    m.nrMetricHarvestTimeDelta = 60

    'Attributes
    m.nrBackupAttributes = CreateObject("roAssociativeArray")
    m.nrCustomAttributes = CreateObject("roAssociativeArray")

    'HTTP_CONNECT/HTTP_COMPLETE state
    m.http_events_enabled = false

    'HTTP metric counters
    m.http_counters_min_ts = CreateObject("roDateTime")
    m.http_counters_max_ts = CreateObject("roDateTime")

    'HTTP_REQUEST counters
    m.num_http_request_counters = CreateObject("roAssociativeArray")
    'HTTP_RESPONSE counters
    m.num_http_response_counters = CreateObject("roAssociativeArray")
    m.num_http_response_errors = CreateObject("roAssociativeArray")
    'HTTP_CONNECT counters
    m.num_http_connect_counters = CreateObject("roAssociativeArray")
    'HTTP_COMPLETE counters
    m.num_http_complete_counters = CreateObject("roAssociativeArray")
    'HTTP_ERROR counters
    m.num_http_error_counters = CreateObject("roAssociativeArray")

    'HTTP Request/Response IDs
    m.nrRequestIdentifiers = CreateObject("roAssociativeArray")
    
    date = CreateObject("roDateTime")
    m.nrInitTimestamp = date.AsSeconds()
    
    'Init main timer
    m.nrTimer = CreateObject("roTimespan")
    m.nrTimer.Mark()

    'Create and configure tasks (events)
    m.bgTaskEvents = m.top.findNode("NRTaskEvents")
    m.bgTaskEvents.setField("apiKey", m.nrInsightsApiKey)
    m.bgTaskEvents.setField("dataToken", m.dataToken)
    m.bgTaskEvents.setField("appName", m.appName)
    m.bgTaskEvents.setField("region", m.nrRegion)
    m.bgTaskEvents.setField("appToken", m.nrMobileAppToken)
    m.bgTaskEvents.setField("appInfo", m.nrDeviceInfo)
    m.eventApiUrl = box(nrEventApiUrl())
    m.bgTaskEvents.setField("eventApiUrl", m.eventApiUrl)
    m.bgTaskEvents.sampleType = "event"
    'Create and configure tasks (logs)
    m.bgTaskLogs = m.top.findNode("NRTaskLogs")
    m.bgTaskLogs.setField("apiKey", m.nrInsightsApiKey)
    m.logApiUrl = box(nrLogApiUrl())
    m.bgTaskEvents.setField("appName", m.appName)
    m.bgTaskEvents.setField("region", m.nrRegion)
    m.bgTaskLogs.setField("logApiUrl", m.logApiUrl)
    m.bgTaskLogs.sampleType = "log"
    'Create and configure tasks (metrics)
    m.bgTaskMetrics = m.top.findNode("NRTaskMetrics")
    m.bgTaskMetrics.setField("apiKey", m.nrInsightsApiKey)
    m.metricApiUrl = box(nrMetricApiUrl())
    m.bgTaskEvents.setField("region", m.nrRegion)
    m.bgTaskEvents.setField("appName", m.appName)
    m.bgTaskMetrics.setField("metricApiUrl", m.metricApiUrl)
    m.bgTaskMetrics.sampleType = "metric"

    'Init harvest timer (events)
    m.nrHarvestTimerEvents = m.top.findNode("nrHarvestTimerEvents")
    m.nrHarvestTimerEvents.ObserveField("fire", "nrHarvestTimerHandlerEvents")
    m.nrHarvestTimerEvents.duration = m.nrEventHarvestTimeNormal
    m.nrHarvestTimerEvents.control = "start"
    'Init harvest timer (logs)
    m.nrHarvestTimerLogs = m.top.findNode("nrHarvestTimerLogs")
    m.nrHarvestTimerLogs.ObserveField("fire", "nrHarvestTimerHandlerLogs")
    m.nrHarvestTimerLogs.duration = m.nrLogHarvestTimeNormal
    m.nrHarvestTimerLogs.control = "start"
    'Init harvest timer (metrics)
    m.nrHarvestTimerMetrics = m.top.findNode("nrHarvestTimerMetrics")
    m.nrHarvestTimerMetrics.ObserveField("fire", "nrHarvestTimerHandlerMetrics")
    m.nrHarvestTimerMetrics.duration = m.nrMetricHarvestTimeNormal
    m.nrHarvestTimerMetrics.control = "start"

    'Domain attribute matching patterns
    m.domainPatterns = CreateObject("roAssociativeArray")
    
    'Ad tracker states
    m.rafState = CreateObject("roAssociativeArray")
    m.rafState.numberOfAds = 0
    nrResetRAFTimers()
    nrResetRAFState()

    m.enableMemMonitor = false
    if isMemoryMonitorAvailable(CreateObject("roDeviceInfo").GetModel())
        'Available since v10.5
        m.memMonitor = CreateObject("roAppMemoryMonitor")
        if m.memMonitor <> invalid
            'UNDOCUMENTED TRICK:
            '   If EnableMemoryWarningEvent(true) returns false, a call to GetChannelAvailableMemory will freeze the device on v12.5
            enableMemWarningRet = m.memMonitor.EnableMemoryWarningEvent(true)
            m.memMonitor.EnableMemoryWarningEvent(false)

            if enableMemWarningRet
                'Available for RokuOS v12.5+
                m.enableMemMonitor = FindMemberFunction(m.memMonitor, "GetChannelAvailableMemory") <> Invalid
            end if
        end if
    end if

    nrLog(["NewRelicInit, m = ", m])
end function


function nrConnect(appToken as string, body as object)
    jsonRequestBody = FormatJSON(body)
    urlReq = CreateObject("roUrlTransfer")    
    rport = CreateObject("roMessagePort")
    if(m.nrRegion = "staging")
        urlReq.SetUrl("https://staging-mobile-collector.newrelic.com/mobile/v4/connect")
    else
        urlReq.SetUrl("https://mobile-collector.newrelic.com/mobile/v4/connect")
    end if
    urlReq.RetainBodyOnError(true)
    urlReq.EnablePeerVerification(false)
    urlReq.EnableHostVerification(false)
    urlReq.EnableEncodings(true)
    urlReq.AddHeader("CONTENT-TYPE", "application/json")
    urlReq.AddHeader("X-App-License-Key", appToken)
    urlReq.AddHeader("X-NewRelic-Connect-Time", nrTimestampFromDateTime(CreateObject("roDateTime")).toStr())
    urlReq.SetMessagePort(rport)
    urlReq.AsyncPostFromString(jsonRequestBody)
    
    msg = wait(10000, rport)

    if type(msg) = "roUrlEvent" then
        if msg.GetResponseCode() = 200 then 
                responseString = msg.GetString()
                response = ParseJson(responseString)
                dataToken = response.data_token
            else
                print "HTTP Error: "; msg.GetResponseCode()
                dataToken = invalid
        end if
        else
            print "No valid roUrlEvent message received."
            dataToken = invalid
    end if
    return dataToken
end function

function nrSetUserId(userId as String) as Void
    m.userId = userId
end function

function NewRelicVideoStart(videoObject as Object) as Void
    nrLog("NewRelicVideoStart")

    'Store video object
    m.nrVideoObject = videoObject
    'Current state
    m.nrLastVideoState = "none"
    m.nrIsInitialBuffering = false
    'Timestamps for timeSince attributes
    m.nrTimeSinceBufferBegin = 0.0
    m.nrTimeSinceLastHeartbeat = 0.0
    m.nrTimeSincePaused = 0.0
    m.nrTimeSinceRequested = 0.0
    m.nrTimeSinceStarted = 0.0
    m.nrTimeSinceTrackerReady = 0.0
    m.nrHeartbeatElapsedTime = 0.0
    m.nrLastPlayTimestamp = 0.0
    m.nrIsPlaying = false

    'timeSinceLastError
    m.nrTimeSinceLastError = 0.0
    
    'timeSinceLastAdError
    m.nrTimeSinceLastAdError = 0.0

    'Playtimes
    nrResetPlaytime()
    m.nrPlaytimeSinceLastEvent = invalid
    m.nrTotalAdPlaytime = 0
    'Counters
    m.nrVideoCounter = 0
    m.nrNumberOfErrors = 0

    'QOE (Quality of Experience) tracking fields
    m.qoePeakBitrate = 0
    m.qoeHadPlaybackFailure = false
    m.qoeTotalRebufferingTime = 0
    m.qoeBitrateSum = 0
    m.qoeBitrateCount = 0
    m.qoeLastTrackedBitrate = invalid
    m.qoeStartupTime = invalid  'Cached startup time, calculated once per view session

    'Startup time calculation fields - capture actual event timestamps
    m.contentRequestTimestamp = invalid
    m.contentStartTimestamp = invalid
    m.contentErrorTimestamp = invalid  'Timestamp when content error occurred (for startup failures)
    m.startupPeriodAdTime = 0  'Ad time that occurred during startup period
    m.hasContentStarted = false  'Tracks whether content has successfully started (for buffer classification)

    'Time-weighted bitrate calculation fields
    m.qoeCurrentBitrate = invalid
    m.qoeLastRenditionChangeTime = invalid
    m.qoeTotalBitrateWeightedTime = 0
    m.qoeTotalActiveTime = 0

    'QOE: Track if VideoAction events occurred in current harvest cycle (for T-4/T-5)
    m.qoeHasVideoActionThisHarvest = false

    'Setup event listeners 
    m.nrVideoObject.observeFieldScoped("state", "nrStateObserver")
    m.nrVideoObject.observeFieldScoped("contentIndex", "nrIndexObserver")
    m.nrvideoObject.observeFieldScoped("licenseStatus", "nrLicenseStatusObserver")

    'Init heartbeat timer
    m.hbTimer = m.top.findNode("nrHeartbeatTimer")
    m.hbTimer.observeFieldScoped("fire", "nrHeartbeatHandler")
    m.hbTimer.control = "start"
    
    'Player Ready
    nrSendPlayerReady()
end function

function NewRelicVideoStop() as Void
    ' Remove event listeners
    if m.nrVideoObject <> invalid
        m.nrVideoObject.unobserveFieldScoped("state")
        m.nrVideoObject.unobserveFieldScoped("contentIndex")
        m.nrVideoObject.unobserveFieldScoped("licenseStatus")
        m.nrVideoObject = Invalid
    end if
    ' Stop heartbeat timer
    if m.hbTimer <> invalid
        m.hbTimer.unobserveFieldScoped("fire")
        m.hbTimer.control = "stop"
    end if
end function

' modifies current configuration
function nrUpdateConfig(config as Object) as Void
    if config = invalid then return
    if config.proxyUrl <> invalid
        nrLog("Set Proxy URL: " + config.proxyUrl)
        m.eventApiUrl = box(nrEventApiUrl())
        m.logApiUrl = box(nrLogApiUrl())
        m.metricApiUrl = box(nrMetricApiUrl())
        m.bgTaskEvents.setField("eventApiUrl", config.proxyUrl + m.eventApiUrl)
        m.bgTaskLogs.setField("logApiUrl", config.proxyUrl + m.logApiUrl)
        m.bgTaskMetrics.setField("metricApiUrl", config.proxyUrl + m.logApiUrl)
    end if
end function

' Add a matching pattern for the domain attribute and substitute it by another string.
function nrAddDomainSubstitution(pattern as String, subs as String) as Void
    m.domainPatterns.AddReplace(pattern, subs)
end function

' Delete a matching pattern created with nrAddDomainSubstitution
function nrDelDomainSubstitution(pattern as String) as Void
    m.domainPatterns.Delete(pattern)
end function

function nrAppStarted(aa as Object) as Void
    attr = {
        "lastExitOrTerminationReason": aa["lastExitOrTerminationReason"],
        "splashTime": aa["splashTime"],
        "instantOnRunMode": aa["instant_on_run_mode"],
        "launchSource": aa["source"]
    }
    nrSendSystemEvent("ConnectedDeviceSystem", "APP_STARTED", attr)
end function

function nrSceneLoaded(sceneName as String) as Void
    print "[New Relic] Scene loaded: " + sceneName
    nrSendSystemEvent("ConnectedDeviceSystem", "SCENE_LOADED", {"sceneName": sceneName})
end function

function nrSendSystemEvent(eventType as String, actionName as String, attr = invalid as Object) as Void
    nrLog("nrSendSystemEvent")
    ev = nrCreateEvent(eventType, actionName)
    ev = nrAddCustomAttributes(ev)
    if attr <> invalid
        ev.Append(attr)
    end if
    nrRecordEvent(ev)
end function

function nrSendVideoEvent(actionName as String, attr = invalid) as Void
    print "[New Relic] VideoAction: " + actionName
    ev = nrCreateEvent("VideoAction", actionName)
    ev = nrAddVideoAttributes(ev)
    ev = nrAddCustomAttributes(ev)
    if type(attr) = "roAssociativeArray"
       ev.Append(attr)
    end if
    nrRecordEvent(ev)
    'Backup attributes
    'Exclude *_BUFFER_* actions due to a problem with these events when skipping in a playlist: attributes are not reliable, can be mixed with next video attributes or just wrong.
    if actionName <> "CONTENT_BUFFER_START" and actionName <> "CONTENT_BUFFER_END"
        m.nrBackupAttributes = {}
        m.nrBackupAttributes.Append(ev)
    end if

    'Track that a VideoAction event occurred in this harvest cycle
    'Only set flag for non-QOE_AGGREGATE events to prevent circular logic
    'Don't set flag during ad breaks (prevents QOE_AGGREGATE during ad-only cycles)
    'This applies to ALL ad breaks: pre-roll, mid-roll, and post-roll
    if actionName <> "QOE_AGGREGATE"
        isInAdBreak = (m.rafState.timeSinceAdBreakBegin <> invalid and m.rafState.timeSinceAdBreakBegin > 0)

        'Only set flag if we're NOT in an ad break
        if not isInAdBreak
            m.qoeHasVideoActionThisHarvest = true
        else
            print "[QOE] Skipping flag set - in ad break (actionName: "; actionName; ")"
        end if
    end if
end function

function nrSendErrorEvent(actionName as String, attr as Dynamic) as Void
    ev = nrCreateEvent("VideoErrorAction", actionName)
    ev = nrAddVideoAttributes(ev)
    ev = nrAddCustomAttributes(ev)
    if type(attr) = "roAssociativeArray"
       ev.Append(attr)
    end if
    nrRecordEvent(ev)
end function

function nrSendCustomEvent(actionName as String, ctx as Dynamic, attr = invalid) as Void
    ev = nrCreateEvent("VideoCustomAction", actionName)
    ' Check if ctx contains attributes other than adpartner with value "raf"
    hasOtherAdAttributes = false
    if ctx <> invalid and type(ctx) = "roAssociativeArray"
        for each key in ctx
            if key <> "adpartner" or (key = "adpartner" and ctx[key] <> "raf")
                hasOtherAdAttributes = true
                exit for
            end if
        end for
    end if   
    ' Add RAF attributes only if there are other attributes present
    if hasOtherAdAttributes
        ev = nrAddRAFAttributes(ev, ctx)
    else
        ev = nrAddVideoAttributes(ev)
    end if
    ev = nrAddCustomAttributes(ev)
    if type(attr) = "roAssociativeArray"
       ev.Append(attr)
    end if
    nrRecordEvent(ev)
end function

function nrSendHttpRequest(attr as Object) as Void
    domain = nrExtractDomainFromUrl(attr["origUrl"])
    attr["domain"] = domain
    transId = stri(attr["transferIdentity"])
    m.nrRequestIdentifiers[transId] = nrTimestamp()
    'Clean up old transfers
    toDeleteKeys = []
    for each item in m.nrRequestIdentifiers.Items()
        'More than 10 minutes without a response, delete the request ID
        if nrTimestamp() - item.value > 10*60*1000
            toDeleteKeys.Push(item.key)
        end if
    end for
    for each key in toDeleteKeys
        m.nrRequestIdentifiers.Delete(key)
    end for

    'Calculate counts for metrics
    if m.num_http_request_counters.DoesExist(domain)
        new_count = m.num_http_request_counters[domain] + 1
        m.num_http_request_counters.AddReplace(domain, new_count)
    else
        m.num_http_request_counters.AddReplace(domain, 1)
    end if

    nrSendSystemEvent("ConnectedDeviceSystem", "HTTP_REQUEST", attr)
end function

function nrSendHttpResponse(attr as Object) as Void
    domain = nrExtractDomainFromUrl(attr["origUrl"])
    attr["domain"] = domain
    transId = stri(attr["transferIdentity"])
    if m.nrRequestIdentifiers[transId] <> invalid
        deltaMs = nrTimestamp() - m.nrRequestIdentifiers[transId]
        attr["timeSinceHttpRequest"] = deltaMs
        m.nrRequestIdentifiers.Delete(transId)
        'Generate metrics
        nrSendMetric("roku.http.response.time", deltaMs, {"domain": domain})
    end if

    'Calculate counts for metrics
    if m.num_http_response_counters.DoesExist(domain)
        new_count = m.num_http_response_counters[domain] + 1
        m.num_http_response_counters.AddReplace(domain, new_count)
    else
        m.num_http_response_counters.AddReplace(domain, 1)
    end if

    if attr["httpCode"] >= 400 or attr["httpCode"] < 0
        if m.num_http_response_errors.DoesExist(domain)
            new_count = m.num_http_response_errors[domain] + 1
            m.num_http_response_errors.AddReplace(domain, new_count)
        else
            m.num_http_response_errors.AddReplace(domain, 1)
        end if
    end if
    
    nrSendSystemEvent("ConnectedDeviceSystem", "HTTP_RESPONSE", attr)
end function

function nrEnableHttpEvents() as Void
    m.http_events_enabled = true
end function

function nrDisableHttpEvents() as Void
    m.http_events_enabled = false
end function

function nrSetCustomAttribute(key as String, value as Object, actionName = "" as String) as Void
    dict = CreateObject("roAssociativeArray")
    dict[key] = value
    nrSetCustomAttributeList(dict, actionName)
end function

function nrSetCustomAttributeList(attr as Object, actionName = "" as String) as Void
    dictName = actionName
    if dictName = "" then dictName = "GENERAL_ATTR"
    
    if m.nrCustomAttributes[dictName] = invalid
        m.nrCustomAttributes[dictName] = CreateObject("roAssociativeArray")
    end if
    
    actionDict = m.nrCustomAttributes[dictName]
    
    actionDict.Append(attr)
    m.nrCustomAttributes[dictName] = actionDict
    
    nrLog(["Custom Attributes: ", m.nrCustomAttributes[dictName]])
end function

function nrSetHarvestTime(seconds as Integer) as Void
    nrSetHarvestTimeEvents(seconds)
    nrSetHarvestTimeLogs(seconds)
    nrSetHarvestTimeMetrics(seconds)
end function

function nrSetHarvestTimeEvents(seconds as Integer) as Void
    if seconds < 60 then seconds = 60
    m.nrEventHarvestTimeNormal = seconds
    m.nrHarvestTimerEvents.duration = seconds
    nrLog(["Harvest time events = ", seconds])
end function

function nrSetHarvestTimeLogs(seconds as Integer) as Void
    if seconds < 60 then seconds = 60
    m.nrLogHarvestTimeNormal = seconds
    m.nrHarvestTimerLogs.duration = seconds
    nrLog(["Harvest time logs = ", seconds])
end function

function nrSetHarvestTimeMetrics(seconds as Integer) as Void
    if seconds < 60 then seconds = 60
    m.nrMetricHarvestTimeNormal = seconds
    m.nrHarvestTimerMetrics.duration = seconds
    nrLog(["Harvest time metrics = ", seconds])
end function

function nrForceHarvest() as Void
    nrHarvestTimerHandlerEvents()
    nrHarvestTimerHandlerLogs()
    nrHarvestTimerHandlerMetrics()
end function

function nrForceHarvestEvents() as Void
    nrHarvestTimerHandlerEvents()
end function

function nrForceHarvestLogs() as Void
    nrHarvestTimerHandlerLogs()
end function

function nrForceHarvestMetrics() as Void
    nrHarvestTimerHandlerMetrics()
end function

'Roku Advertising Framework tracking
function nrTrackRAF(evtType = invalid as Dynamic, ctx = invalid as Dynamic) as Void
    if GetInterface(evtType, "ifString") <> invalid and ctx <> invalid
        if evtType = "PodStart"
            nrResetRAFTimers()
            nrSendRAFEvent("AD_BREAK_START", ctx)
            m.rafState.timeSinceAdBreakBegin = m.nrTimer.TotalMilliseconds()

            'Capture CONTENT_REQUEST timestamp for pre-roll ads
            'When pre-roll ads start, that's when content was actually requested
            if m.contentRequestTimestamp = invalid
                m.contentRequestTimestamp = m.rafState.timeSinceAdBreakBegin
                print "[QOE] REQUEST (captured at AD_BREAK_START): "; m.contentRequestTimestamp
            end if
        else if evtType = "PodComplete"
            timeSinceAdBreakBegin = m.nrTimer.TotalMilliseconds() - m.rafState.timeSinceAdBreakBegin
            nrAddToTotalAdPlaytime(timeSinceAdBreakBegin)
            nrSendRAFEvent("AD_BREAK_END", ctx, {"timeSinceAdBreakBegin": timeSinceAdBreakBegin})
            'Reset timer to indicate ad break is complete
            m.rafState.timeSinceAdBreakBegin = 0
        else if evtType = "Impression"
            nrSendRAFEvent("AD_REQUEST", ctx)
            m.rafState.timeSinceAdRequested = m.nrTimer.TotalMilliseconds()
        else if evtType = "Start"
            m.rafState.numberOfAds = m.rafState.numberOfAds + 1
            nrResetAdBitrateTracker()  ' Reset tracker for new ad
            nrSendRAFEvent("AD_START", ctx)
            m.rafState.timeSinceAdStarted = m.nrTimer.TotalMilliseconds()
        else if evtType = "Complete"
            nrSendRAFEvent("AD_END", ctx)
            'Reset attributes after END
            nrResetRAFState()
            nrResetAdBitrateTracker()  ' Reset tracker when ad ends
            m.rafState.timeSinceAdRequested = 0
            m.rafState.timeSinceAdStarted = 0
        else if evtType = "Pause"
            nrSendRAFEvent("AD_PAUSE", ctx)
            m.rafState.timeSinceAdPaused = m.nrTimer.TotalMilliseconds()
        else if evtType = "Resume"
            timeSinceAdPaused = m.nrTimer.TotalMilliseconds() - m.rafState.timeSinceAdPaused
            nrSendRAFEvent("AD_RESUME", ctx, {"timeSinceAdPaused": timeSinceAdPaused})
        else if evtType = "Close"
            nrSendRAFEvent("AD_SKIP", ctx)
            nrSendRAFEvent("AD_END", ctx)
            'Reset attributes after END
            nrResetRAFState()
            m.rafState.timeSinceAdRequested = 0
            m.rafState.timeSinceAdStarted = 0
            timeSinceAdBreakBegin = m.nrTimer.TotalMilliseconds() - m.rafState.timeSinceAdBreakBegin
            nrSendRAFEvent("AD_BREAK_END", ctx, {"timeSinceAdBreakBegin": timeSinceAdBreakBegin})
            'Reset timer to indicate ad break is complete
            m.rafState.timeSinceAdBreakBegin = 0
        else if evtType = "Error"
            ' Set timestamp for last ad error
            m.nrTimeSinceLastAdError = m.nrTimer.TotalMilliseconds()
            
            attr = {}
            if ctx.errType <> invalid then attr.AddReplace("adErrorType", ctx.errType)
            if ctx.errCode <> invalid then attr.AddReplace("errorCode", ctx.errCode)
            if ctx.errMsg <> invalid then attr.AddReplace("errorMessage", ctx.errMsg)
            nrSendErrorEvent("AD_ERROR", attr)
        end if
    else if ctx <> invalid and ctx.time <> invalid and ctx.duration <> invalid
        'Time progress event
        firstQuartile = ctx.duration / 4.0
        secondQuartile = firstQuartile * 2.0
        thirdQuartile = firstQuartile * 3.0
        
        if ctx.time >= firstQuartile and ctx.time < secondQuartile and m.rafState.didFirstQuartile = false
            m.rafState.didFirstQuartile = true
            nrSendRAFEvent("AD_QUARTILE", ctx, {"adQuartile": 1})
        else if ctx.time >= secondQuartile and ctx.time < thirdQuartile and m.rafState.didSecondQuartile = false
            m.rafState.didSecondQuartile = true
            nrSendRAFEvent("AD_QUARTILE", ctx, {"adQuartile": 2})
        else if ctx.time >= thirdQuartile and m.rafState.didThirdQuartile = false
            m.rafState.didThirdQuartile = true
            nrSendRAFEvent("AD_QUARTILE", ctx, {"adQuartile": 3})
        end if
    end if
end function

function nrSendLog(message as String, logtype as String, fields as Object) as Void
    lg = CreateObject("roAssociativeArray")
    if message <> invalid and message <> "" then lg["message"] = message
    if logtype <> invalid and logtype <> "" then lg["logtype"] = logtype
    if fields <> invalid then lg.Append(fields)
    lg["timestamp"] = FormatJson(nrTimestamp())
    lg["newRelicAgentSource"] = "roku"

    nrLog(["RECORD NEW LOG = ", lg])

    m.nrLogArrayIndex = nrAddSample(lg, m.nrLogArray, m.nrLogArrayIndex, m.nrLogArrayK)
end function

'Send a Gauge metric
function nrSendMetric(name as String, value as dynamic, attr = invalid as Object) as Void
    metric = CreateObject("roAssociativeArray")
    metric["type"] = "gauge"
    metric["name"] = name
    metric["timestamp"] = nrTimestamp()
    if GetInterface(value, "ifInt") <> invalid
        metric["value"] = value.GetInt()
    else if GetInterface(value, "ifLongInt") <> invalid
        metric["value"] = value.GetLongInt()
    else if GetInterface(value, "ifFloat") <> invalid
        metric["value"] = value.GetFloat()
    else if GetInterface(value, "ifDouble") <> invalid
        metric["value"] = value.GetDouble()
    else
        metric["value"] = 0
    end if
    if attr <> invalid then metric["attributes"] = attr

    nrLog(["RECORD NEW METRIC = ", metric])

    m.nrMetricArrayIndex = nrAddSample(metric, m.nrMetricArray, m.nrMetricArrayIndex, m.nrMetricArrayK)
end function

'Send Count metric
function nrSendCountMetric(name as String, value as dynamic, interval as Integer, attr = invalid as Object) as Void
    metric = CreateObject("roAssociativeArray")
    metric["type"] = "count"
    metric["name"] = name
    metric["interval.ms"] = interval
    metric["timestamp"] = nrTimestamp()
    if GetInterface(value, "ifInt") <> invalid
        metric["value"] = value.GetInt()
    else if GetInterface(value, "ifLongInt") <> invalid
        metric["value"] = value.GetLongInt()
    else if GetInterface(value, "ifFloat") <> invalid
        metric["value"] = value.GetFloat()
    else if GetInterface(value, "ifDouble") <> invalid
        metric["value"] = value.GetDouble()
    else
        metric["value"] = 0
    end if
    if attr <> invalid then metric["attributes"] = attr

    nrLog(["RECORD NEW COUNT METRIC = ", metric])

    m.nrMetricArrayIndex = nrAddSample(metric, m.nrMetricArray, m.nrMetricArrayIndex, m.nrMetricArrayK)
end function

'Send Summary metric
function nrSendSummaryMetric(name as String, interval as Integer, value as Object, attr = invalid as Object) as Void
    metric = CreateObject("roAssociativeArray")
    metric["type"] = "summary"
    metric["name"] = name
    metric["interval.ms"] = interval
    metric["timestamp"] = nrTimestamp()
    metric["value"] = value
    if attr <> invalid then metric["attributes"] = attr

    nrLog(["RECORD NEW SUMMARY METRIC = ", metric])

    m.nrMetricArrayIndex = nrAddSample(metric, m.nrMetricArray, m.nrMetricArrayIndex, m.nrMetricArrayK)
end function

'=========================='
' Public Internal Functions '
'=========================='

function nrActivateLogging(state as Boolean) as Void
    m.nrLogsState = state
end function

function nrCheckLoggingState() as Boolean
    return m.nrLogsState
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

function nrExtractAllSamples(sampleType as String) as Object
    if sampleType = "event"
        return nrExtractAllEvents()
    else if sampleType = "log"
        return nrExtractAllLogs()
    else if sampleType = "metric"
        return nrExtractAllMetrics()
    end if
end function

function nrGetBackAllSamples(sampleType as String, samples as Object) as Void
    if sampleType = "event"
        nrGetBackEvents(samples)
    else if sampleType = "log"
        nrGetBackLogs(samples)
    else if sampleType = "metric"
        nrGetBackMetrics(samples)
    end if
end function

function nrRecordEvent(event as Object) as Void
    nrLog(["RECORD NEW EVENT = ", event])
    m.nrEventArrayIndex = nrAddSample(event, m.nrEventArray, m.nrEventArrayIndex, m.nrEventArrayK)
end function

function nrProcessSystemEvent(i as Object) as Boolean
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
    end if
    return false
end function

function nrAddToTotalAdPlaytime(adPlaytime as Integer) as Void
    m.nrTotalAdPlaytime = m.nrTotalAdPlaytime + adPlaytime
end function

function nrReqErrorTooManyReq(sampleType as String) as Void
    ' Error too many requests, increase harvest time
    if sampleType = "event"
        nrLog("NR API ERROR, TOO MANY REQUESTS, current event harvest time = " + str(m.nrHarvestTimerEvents.duration))
        if m.nrHarvestTimerEvents.duration < m.nrEventHarvestTimeMax
            m.nrHarvestTimerEvents.duration = m.nrHarvestTimerEvents.duration + m.nrEventHarvestTimeDelta
        end if
    else if sampleType = "log"
        nrLog("NR API ERROR, TOO MANY REQUESTS, current log harvest time = " + str(m.nrHarvestTimerLogs.duration))
        if m.nrHarvestTimerLogs.duration < m.nrLogHarvestTimeMax
            m.nrHarvestTimerLogs.duration = m.nrHarvestTimerLogs.duration + m.nrLogHarvestTimeDelta
        end if
    else if sampleType = "metric"
        nrLog("NR API ERROR, TOO MANY REQUESTS, current metric harvest time = " + str(m.nrHarvestTimerMetrics.duration))
        if m.nrHarvestTimerMetrics.duration < m.nrMetricHarvestTimeMax
            m.nrHarvestTimerMetrics.duration = m.nrHarvestTimerMetrics.duration + m.nrMetricHarvestTimeDelta
        end if
    end if
end function

function nrReqErrorTooLarge(sampleType as String) as Void
    ' Error content too large, decrease buffer K temporarly (until next harvest cycle)
    nrLog("NR API ERROR, BODY TOO LARGE")
    if sampleType = "event"
        if m.nrEventArrayK > m.nrEventArrayMinK
            m.nrEventArrayK = m.nrEventArrayK - m.nrEventArrayDeltaK
        end if
    else if sampleType = "log"
        if m.nrLogArrayK > m.nrLogArrayMinK
            m.nrLogArrayK = m.nrLogArrayK - m.nrLogArrayDeltaK
        end if
    else if sampleType = "metric"
        if m.nrMetricArrayK > m.nrMetricArrayMinK
            m.nrMetricArrayK = m.nrMetricArrayK - m.nrMetricArrayDeltaK
        end if
    end if
end function

function nrReqOk(sampleType as String) as Void
    if sampleType = "event"
        if m.nrHarvestTimerEvents.duration > m.nrEventHarvestTimeNormal
            m.nrHarvestTimerEvents.duration = m.nrHarvestTimerEvents.duration - m.nrEventHarvestTimeDelta
        end if
        if m.nrEventArrayK < m.nrEventArrayNormalK
            m.nrEventArrayK = m.nrEventArrayK + m.nrEventArrayDeltaK
        end if
        nrLog("NR API OK event, post K = " + str(m.nrEventArrayK) + " harvest time = " + str(m.nrHarvestTimerEvents.duration))
    else if sampleType = "log"
        if m.nrHarvestTimerLogs.duration > m.nrLogHarvestTimeNormal
            m.nrHarvestTimerLogs.duration = m.nrHarvestTimerLogs.duration - m.nrLogHarvestTimeDelta
        end if
        if m.nrLogArrayK < m.nrLogArrayNormalK
            m.nrLogArrayK = m.nrLogArrayK + m.nrLogArrayDeltaK
        end if
        nrLog("NR API OK logs, post K = " + str(m.nrLogArrayK) + " harvest time = " + str(m.nrHarvestTimerLogs.duration))
    else if sampleType = "metric"
        if m.nrHarvestTimerMetrics.duration > m.nrMetricHarvestTimeNormal
            m.nrHarvestTimerMetrics.duration = m.nrHarvestTimerMetrics.duration - m.nrMetricHarvestTimeDelta
        end if
        if m.nrMetricArrayK < m.nrMetricArrayNormalK
            m.nrMetricArrayK = m.nrMetricArrayK + m.nrMetricArrayDeltaK
        end if
        nrLog("NR API OK metrics, post K = " + str(m.nrMetricArrayK) + " harvest time = " + str(m.nrHarvestTimerMetrics.duration))
    end if
end function

'=================='
' System functions '
'=================='

function nrCreateAppInfo() as Object
    app = CreateObject("roAppInfo")
    dev = CreateObject("roDeviceInfo")

    APPLICATION_NAME = app.GetTitle()
    APPLICATION_VERSION = app.GetValue("major_version") + "." + app.GetValue("minor_version")
    APPLICATION_PACKAGE = "com.example." + APPLICATION_NAME
    OS_NAME = "Android"
    OS_VERSION = nrGetOSVersion(dev).version
    MANUFACTURE_AND_MODEL = dev.GetModel()
    AGENT_NAME = "RokuAgent"
    AGENT_VERSION = m.nrAgentVersion
    DEVICE_ID = dev.GetChannelClientId()
    DEPRECATED_COUNTRY_CODE = ""
    DEPRECATED_REGION_CODE = ""
    MANUFACTURER = "Roku"
    MISCELLANEOUS_PARAMETERS_JSON = {
        "platform" : "Native",
        "platformVersion" : OS_VERSION
    }

    appInfo = [
        [
            APPLICATION_NAME,
            APPLICATION_VERSION,
            APPLICATION_PACKAGE
        ],
        [
            OS_NAME,
            OS_VERSION,
            MANUFACTURE_AND_MODEL,
            AGENT_NAME,
            AGENT_VERSION,
            DEVICE_ID,
            DEPRECATED_COUNTRY_CODE,
            DEPRECATED_REGION_CODE,
            MANUFACTURER,
            MISCELLANEOUS_PARAMETERS_JSON
        ]
    ]
    
    return {"appInfo" : appInfo, "deviceInfo":appInfo[1]}
end function

function nrCreateEvent(eventType as String, actionName as String) as Object
    ev = CreateObject("roAssociativeArray")
    if actionName <> invalid and actionName <> "" then ev["actionName"] = actionName
    if eventType <> invalid and eventType <> "" then ev["eventType"] = eventType
    
    ev["timestamp"] = nrTimestamp()
    ev = nrAddBaseAttributes(ev)
    
    return ev
end function

function nrAddBaseAttributes(ev as Object) as Object
    'Add default custom attributes for instrumentation'
    ev.AddReplace("enduser.id", m.userId)
    ev.AddReplace("src","Roku")
    ev.AddReplace("instrumentation.provider", "newrelic")
    ev.AddReplace("instrumentation.name", "roku")
    dev = CreateObject("roDeviceInfo")
    ver = nrGetOSVersion(dev)
    ev.AddReplace("instrumentation.version", ver["version"])
    ev.AddReplace("newRelicAgent", "RokuAgent")
    ev.AddReplace("newRelicVersion", m.nrAgentVersion)
    ev.AddReplace("sessionId", m.nrSessionId)
    hdmi = CreateObject("roHdmiStatus")
    ev.AddReplace("hdmiIsConnected", hdmi.IsConnected())
    ev.AddReplace("hdmiHdcpVersion", hdmi.GetHdcpVersion())
    dev = CreateObject("roDeviceInfo")
    ev.AddReplace("uuid", dev.GetChannelClientId()) 'GetDeviceUniqueId is deprecated, so we use GetChannelClientId
    ev.AddReplace("deviceName", dev.GetModelDisplayName())
    ev.AddReplace("deviceGroup", "Roku")
    ev.AddReplace("deviceManufacturer", "Roku")
    ev.AddReplace("deviceModel", dev.GetModel())
    ev.AddReplace("deviceType", dev.GetModelType())
    modelDetails = dev.GetModelDetails()
    ev.AddReplace("vendorName", modelDetails.VendorName)
    ev.AddReplace("modelNumber", modelDetails.ModelNumber)
    ev.AddReplace("vendorUsbName", modelDetails.VendorUSBName)
    ev.AddReplace("screenSize", modelDetails.ScreenSize)
    ev.AddReplace("osName", "RokuOS")
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
    if dev.GetDisplaySize() <> invalid
        ev.AddReplace("contentRenditionHeight", dev.GetDisplaySize().h)
        ev.AddReplace("contentRenditionWidth", dev.GetDisplaySize().w)
    end if
    ev.AddReplace("displayAspectRatio", dev.GetDisplayAspectRatio())
    ev.AddReplace("videoMode", dev.GetVideoMode())
    ev.AddReplace("graphicsPlatform", dev.GetGraphicsPlatform())
    ev.AddReplace("timeSinceLastKeypress", dev.TimeSinceLastKeypress() * 1000)

    if m.enableMemMonitor
        if m.memMonitor = invalid ' roAppMemoryMonitor might've been invalidated on thread ownership change
            m.memMonitor = CreateObject("roAppMemoryMonitor")
        end if
        ev.AddReplace("channelAvailMem", m.memMonitor.GetChannelAvailableMemory())
        ev.AddReplace("memLimitPercent", m.memMonitor.GetMemoryLimitPercent())
    end if

    app = CreateObject("roAppInfo")
    ev.AddReplace("appVersion", app.GetValue("major_version") + "." + app.GetValue("minor_version"))
    'ev.AddReplace("appName", app.GetTitle())
    ev.AddReplace("appDevId", app.GetDevID())
    ev.AddReplace("appIsDev", app.IsDev())
    appbuild = app.GetValue("build_version").ToInt()
    ev.AddReplace("appBuild", appbuild)
    'Uptime
    ev.AddReplace("uptime", Uptime(0))
    'Time Since Load
    date = CreateObject("roDateTime")
    ev.AddReplace("timeSinceLoad", date.AsSeconds() - m.nrInitTimestamp)
    
    return ev
end function

function nrAddCustomAttributes(ev as Object) as Object
    genCustomAttr = m.nrCustomAttributes["GENERAL_ATTR"]
    if genCustomAttr <> invalid then ev.Append(genCustomAttr)
    actionName = ev["actionName"]
    actionCustomAttr = m.nrCustomAttributes[actionName]
    if actionCustomAttr <> invalid then ev.Append(actionCustomAttr)
    return ev
end function

function nrAddCommonHTTPAttr(info as Object) as Object
    attr = {
        "httpCode": info["HttpCode"],
        "method": info["Method"],
        "origUrl": info["OrigUrl"],
        "domain": nrExtractDomainFromUrl(info["OrigUrl"]),
        "status": info["Status"],
        "targetIp": info["TargetIp"],
        "url": info["Url"]
    }
    return attr
end function

function nrCalculateBufferType(actionName as String) as String
    bufferType = "connection" ' Default buffer type
    if m.nrTimeSinceStarted = 0
        m.nrIsInitialBuffering = true
        bufferType = "initial"
    else
        m.nrIsInitialBuffering = false
        if m.nrLastVideoState = "paused"
            bufferType = "pause"
        else if m.nrLastVideoState = "seeking"
            bufferType = "seek"
        else
            bufferType = "connection"
        end if
    end if
    return bufferType
end function

function nrSendHTTPError(info as Object) as Void
    attr = nrAddCommonHTTPAttr(info)
    domain = attr["domain"]

    'Calculate counts for metrics
    if m.num_http_error_counters.DoesExist(domain)
        new_count = m.num_http_error_counters[domain] + 1
        m.num_http_error_counters.AddReplace(domain, new_count)
    else
        m.num_http_error_counters.AddReplace(domain, 1)
    end if
    nrSendErrorEvent("HTTP_ERROR", attr)
end function

function nrSendHTTPConnect(info as Object) as Void
    attr = nrAddCommonHTTPAttr(info)
    domain = attr["domain"]

    'Calculate counts for metrics
    if m.num_http_connect_counters.DoesExist(domain)
        new_count = m.num_http_connect_counters[domain] + 1
        m.num_http_connect_counters.AddReplace(domain, new_count)
    else
        m.num_http_connect_counters.AddReplace(domain, 1)
    end if

    if m.http_events_enabled then nrSendSystemEvent("ConnectedDeviceSystem", "HTTP_CONNECT", attr)
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
    domain = attr["domain"]

    'Calculate counts for metrics
    if m.num_http_complete_counters.DoesExist(domain)
        new_count = m.num_http_complete_counters[domain] + 1
        m.num_http_complete_counters.AddReplace(domain, new_count)
    else
        m.num_http_complete_counters.AddReplace(domain, 1)
    end if

    if m.http_events_enabled then nrSendSystemEvent("ConnectedDeviceSystem", "HTTP_COMPLETE", attr)

    domain = nrExtractDomainFromUrl(attr["origUrl"])
    nrSendMetric("roku.http.complete.connectTime", attr["connectTime"], {"domain": domain})
    nrSendMetric("roku.http.complete.downSpeed", attr["downloadSpeed"], {"domain": domain})
    nrSendMetric("roku.http.complete.upSpeed", attr["uploadSpeed"], {"domain": domain})
    nrSendMetric("roku.http.complete.firstByteTime", attr["transferTime"], {"domain": domain})
    nrSendMetric("roku.http.complete.dnsTime", attr["dnsLookupTime"], {"domain": domain})
end function

function nrSendBandwidth(info as Object) as Void
    attr = {
        "bandwidth": info["bandwidth"]
    }
    nrSendSystemEvent("ConnectedDeviceSystem", "BANDWIDTH_MINUTE", attr)
end function

'TODO:  Testing endpoint. If nrRegion is not US or EU, use it as endpoint. Deprecate the "TEST" region and "m.testServer".
'       We could even pass an object containing different endpoints for events, metrics and logs.

function nrEventApiUrl() as String
    if m.nrRegion = "US"
        return "https://insights-collector.newrelic.com/v1/accounts/" + m.nrAccountNumber + "/events"
    else if m.nrRegion = "EU"
        return "https://insights-collector.eu01.nr-data.net/v1/accounts/" + m.nrAccountNumber + "/events"
    else if m.nrRegion = "staging"
        'NOTE: set address hosting the test server
        return "https://staging-insights-collector.newrelic.com/v1/accounts/" + m.nrAccountNumber + "/events"
    end if
end function

function nrLogApiUrl() as String
    if m.nrRegion = "US"
        return "https://log-api.newrelic.com/log/v1"
    else if m.nrRegion = "EU"
        return "https://log-api.eu.newrelic.com/log/v1"
    else if m.nrRegion = "staging"
        'NOTE: set address hosting the test server
        return "https://staging-log-api.newrelic.com/log/v1" 
    end if
end function

function nrMetricApiUrl() as String
    if m.nrRegion = "US"
        return "https://metric-api.newrelic.com/metric/v1"
    else if m.nrRegion = "EU"
        return "https://metric-api.eu.newrelic.com/metric/v1"
    else if m.nrRegion = "staging"
        'NOTE: set address hosting the test server
        return "https://staging-metric-api.newrelic.com/metric/v1"
    end if
end function

'================='
' Video functions '
'================='

function nrSendPlayerReady() as Void
    m.nrTimeSinceTrackerReady = m.nrTimer.TotalMilliseconds()
    nrSendVideoEvent("PLAYER_READY")
end function

function nrSendRequest() as Void
    m.nrTimeSinceRequested = m.nrTimer.TotalMilliseconds()
    'Capture CONTENT_REQUEST timestamp for startup time calculation
    if m.contentRequestTimestamp = invalid
        m.contentRequestTimestamp = m.nrTimer.TotalMilliseconds()
        print "[QOE] REQUEST: "; m.contentRequestTimestamp
    else
        print "[QOE] REQUEST (already captured): "; m.contentRequestTimestamp; " | Current time: "; m.nrTimer.TotalMilliseconds()
    end if
    nrSendVideoEvent("CONTENT_REQUEST")
end function

function nrSendStart() as Void
    m.nrNumberOfErrors = 0
    m.nrTimeSinceStarted = m.nrTimer.TotalMilliseconds()

    'Capture CONTENT_START timestamp
    if m.contentStartTimestamp = invalid
        m.contentStartTimestamp = m.nrTimer.TotalMilliseconds()
        if m.contentRequestTimestamp <> invalid
            rawStartup = m.contentStartTimestamp - m.contentRequestTimestamp
            print "[QOE] START: "; m.contentStartTimestamp; " | Startup: "; rawStartup; " ms"
        else
            print "[QOE] START: "; m.contentStartTimestamp
        end if
    end if

    'Mark that content has successfully started (for buffer type classification)
    m.hasContentStarted = true

    'Store ad time for startup calculation (covers pre-roll scenario)
    m.startupPeriodAdTime = m.nrTotalAdPlaytime

    nrSendVideoEvent("CONTENT_START")
    nrResumePlaytime()
    m.nrPlaytimeSinceLastEvent = CreateObject("roTimespan")
end function

function nrSendEnd() as Void
    nrSendVideoEvent("CONTENT_END")
    m.nrVideoCounter = m.nrVideoCounter + 1
    nrResetPlaytime()
    m.nrPlaytimeSinceLastEvent = invalid

    'Reset playback state for replay scenarios
    m.nrTimeSinceStarted = 0.0

    'Reset QOE metrics for new view session
    nrResetQoeMetrics()
end function

function nrSendPause() as Void
    m.nrTimeSincePaused = m.nrTimer.TotalMilliseconds()
    nrSendVideoEvent("CONTENT_PAUSE")
    nrPausePlaytime()
    m.nrPlaytimeSinceLastEvent = invalid
end function

function nrSendResume() as Void
    nrSendVideoEvent("CONTENT_RESUME")
    nrResumePlaytime()
    m.nrPlaytimeSinceLastEvent = CreateObject("roTimespan")
end function

function nrSendBufferStart() as Void
    m.nrTimeSinceBufferBegin = m.nrTimer.TotalMilliseconds()

    if m.nrTimeSinceStarted = 0
        m.nrIsInitialBuffering = true
    else
        m.nrIsInitialBuffering = false
    end if
    bufferType = nrCalculateBufferType("CONTENT_BUFFER_START")
    print "[QOE] BUFFER_START ("; bufferType; ")"
    nrSendVideoEvent("CONTENT_BUFFER_START", {"isInitialBuffering": m.nrIsInitialBuffering, "bufferType": bufferType})
    nrPausePlaytime()
    m.nrPlaytimeSinceLastEvent = invalid
end function

function nrSendBufferEnd() as Void
    if m.nrTimeSinceStarted = 0
        m.nrIsInitialBuffering = true
    else
        m.nrIsInitialBuffering = false
    end if

    bufferType = nrCalculateBufferType("CONTENT_BUFFER_END")

    'Calculate rebuffering time (excludes initial buffering)
    if m.nrTimeSinceBufferBegin > 0 and bufferType <> "initial"
        rebufferDuration = m.nrTimer.TotalMilliseconds() - m.nrTimeSinceBufferBegin
        m.qoeTotalRebufferingTime = m.qoeTotalRebufferingTime + rebufferDuration
        print "[QOE] BUFFER_END: +"; rebufferDuration; " ms (Total: "; m.qoeTotalRebufferingTime; ")"
    end if

    nrSendVideoEvent("CONTENT_BUFFER_END", {"isInitialBuffering": m.nrIsInitialBuffering, "bufferType": bufferType})
    nrResumePlaytime()
    m.nrPlaytimeSinceLastEvent = CreateObject("roTimespan")
end function

function nrSendError(video as Object) as Void
    attr = {
        "errorMessage": video.errorMsg,
        "errorCode": video.errorCode
    }
    if video.errorStr <> invalid
        attr.append({
            "errorStr": video.errorStr
        })
    end if
    if video.errorInfo <> invalid
        attr.append({
            "errorClipId": video.errorInfo.clipid,
            "errorIgnored": video.errorInfo.ignored,
            "backtrace": video.errorInfo.source,
            "errorCategory": video.errorInfo.category,
            "errorInfoCode": video.errorInfo.errcode,
            "errorDrmInfoCode": video.errorInfo.drmerrcode,
            "errorDebugMsg": video.errorInfo.dbgmsg,
            "errorAttributes": video.errorInfo.error_attributes
        })
    end if
    if video.licenseStatus <> Invalid
        attr.append(getLicenseStatusAttributes(video.licenseStatus))
    end if

    'Capture CONTENT_ERROR timestamp for startup time calculation
    if m.contentErrorTimestamp = invalid
        m.contentErrorTimestamp = m.nrTimer.TotalMilliseconds()
    end if

    'Track playback errors for content (errors after CONTENT_START)
    if m.nrTimeSinceStarted > 0
        'Error occurred after CONTENT_START, so it's a playback failure
        m.qoeHadPlaybackFailure = true
        print "[QOE] ERROR: Playback failure"
    else
        print "[QOE] ERROR: Startup failure"
    end if

    nrSendErrorEvent("CONTENT_ERROR", attr)
end function

function nrSendBackupVideoEvent(actionName as String, attr = invalid) as Void
    ev = m.nrBackupAttributes

    nrLog(["nrSendBackupVideoEvent: Using this event as a backup for attributes: ", ev])
    
    '- Set correct actionName
    ev["actionName"] = actionName
    '- Set current timestamp
    backupTimestamp = ev["timestamp"]
    ev["timestamp"] = nrTimestamp()
    '- Recalculate playhead, adding timestamp offset
    lint& = ev["timestamp"] - backupTimestamp
    offsetTime = lint&
    nrLog(["Offset time = ", offsetTime])
    if ev["contentPlayhead"] <> invalid then ev["contentPlayhead"] = ev["contentPlayhead"] + offsetTime
    if ev["adPlayhead"] <> invalid then ev["adPlayhead"] = ev["adPlayhead"] + offsetTime
    '- Regenerate memory level
    dev = CreateObject("roDeviceInfo")
    ev["memoryLevel"] = dev.GetGeneralMemoryLevel()
    '- Regen is muted
    if m.nrVideoObject <> invalid
        if ev["contentIsMuted"] <> invalid then ev["contentIsMuted"] = m.nrVideoObject.mute
        if ev["adIsMuted"] <> invalid then ev["adIsMuted"] = m.nrVideoObject.mute
    end if
    '- Regenerate HDMI connected
    hdmi = CreateObject("roHdmiStatus")
    ev["hdmiIsConnected"] = hdmi.IsConnected()
    '- Recalculate all timeSinceXXX, adding timestamp offset
    if ev["timeSinceLastHeartbeat"] <> invalid then ev["timeSinceLastHeartbeat"] = ev["timeSinceLastHeartbeat"] + offsetTime '(ms)
    if ev["timeSinceRequested"] <> invalid then ev["timeSinceRequested"] = ev["timeSinceRequested"] + offsetTime ' (ms)
    if ev["timeSinceStarted"] <> invalid then ev["timeSinceStarted"] = ev["timeSinceStarted"] + offsetTime ' (ms)
    ev["timeSinceTrackerReady"] = ev["timeSinceTrackerReady"] + offsetTime ' (ms)
    ev["timeSinceLastKeypress"] = dev.TimeSinceLastKeypress() * 1000
    ev["timeSinceLoad"] = ev["timeSinceLoad"] + offsetTime/1000 ' (s)
    ev["totalPlaytime"] = nrCalculateTotalPlaytime() * 1000
    if actionName = "CONTENT_END"
        ev.Delete("elapsedTime")
    end if
    if m.nrPlaytimeSinceLastEvent = invalid
        ev["playtimeSinceLastEvent"] = 0
    else
        ev["playtimeSinceLastEvent"] = m.nrPlaytimeSinceLastEvent.TotalMilliseconds()
    end if
    
    'PROBLEMS:
    '- Custom attributes remains the same, could be problematic depending on the app
    '- Playhead calculation is estimative.
    
    nrRecordEvent(ev)
    
end function

function nrSendBackupVideoEnd() as Void
    nrSendBackupVideoEvent("CONTENT_END")
    nrResetPlaytime()
    m.nrPlaytimeSinceLastEvent = invalid
end function

function nrAddVideoAttributes(ev as Object) as Object
    ev.AddReplace("errorMessage",m.nrVideoObject.errorMsg)
    ev.AddReplace("errorCode",m.nrVideoObject.errorCode)
    if m.nrVideoObject.errorInfo <> invalid
        ev.AddReplace("backtrace",m.nrVideoObject.errorInfo.source)
    end if
    ev.AddReplace("contentDuration", m.nrVideoObject.duration * 1000)
    ev.AddReplace("contentPlayhead", m.nrVideoObject.position * 1000)
    ev.AddReplace("contentIsMuted", m.nrVideoObject.mute)
    ev.AddReplace("contentIsFullscreen","true")
    streamUrl = nrGenerateStreamUrl()
    ev.AddReplace("contentSrc", streamUrl)
    'Generate Id from Src (hashing it)
    ba = CreateObject("roByteArray")
    ba.FromAsciiString(streamUrl)
    ev.AddReplace("contentId", ba.GetCRC32())
    ' Set contentBitrate: prefer segBitrateBps, fallback to streamBitrate
    contentBitrate = invalid
    if m.nrVideoObject.streamingSegment <> invalid and m.nrVideoObject.streamingSegment["segBitrateBps"] <> invalid
        contentBitrate = m.nrVideoObject.streamingSegment["segBitrateBps"]
    else if m.nrVideoObject.streamInfo <> invalid and m.nrVideoObject.streamInfo["streamBitrate"] <> invalid
        contentBitrate = m.nrVideoObject.streamInfo["streamBitrate"]
    end if
    ev.AddReplace("contentBitrate", contentBitrate)
    ' Keep contentMeasuredBitrate as before
    if m.nrVideoObject.streamInfo <> invalid and m.nrVideoObject.streamInfo["measuredBitrate"] <> invalid
        ev.AddReplace("contentMeasuredBitrate", m.nrVideoObject.streamInfo["measuredBitrate"])
    end if
    ' Keep contentSegmentBitrate for segment info
    if m.nrVideoObject.streamingSegment <> invalid and m.nrVideoObject.streamingSegment["segBitrateBps"] <> invalid
        ev.AddReplace("contentSegmentBitrate", m.nrVideoObject.streamingSegment["segBitrateBps"])
    end if
    ev.AddReplace("playerName", "RokuVideoPlayer")
    dev = CreateObject("roDeviceInfo")
    ver = nrGetOSVersion(dev)
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
    'Timings
    if isAction("BUFFER_END", ev["actionName"])
        ev.AddReplace("timeSinceBufferBegin", m.nrTimer.TotalMilliseconds() - m.nrTimeSinceBufferBegin)
    end if
    if isAction("RESUME", ev["actionName"])
        ev.AddReplace("timeSincePaused", m.nrTimer.TotalMilliseconds() - m.nrTimeSincePaused)
    end if
    if m.nrTimeSinceLastHeartbeat > 0
        ev.AddReplace("timeSinceLastHeartbeat", m.nrTimer.TotalMilliseconds() - m.nrTimeSinceLastHeartbeat)
    end if
    if m.nrTimeSinceRequested > 0
        ev.AddReplace("timeSinceRequested", m.nrTimer.TotalMilliseconds() - m.nrTimeSinceRequested)
    end if
    if m.nrTimeSinceStarted > 0
        ev.AddReplace("timeSinceStarted", m.nrTimer.TotalMilliseconds() - m.nrTimeSinceStarted)
    end if
    if m.nrTimeSinceTrackerReady > 0
        ev.AddReplace("timeSinceTrackerReady", m.nrTimer.TotalMilliseconds() - m.nrTimeSinceTrackerReady)
    end if
     if m.nrTimeSinceLastError > 0
        ev.AddReplace("timeSinceLastError", m.nrTimer.TotalMilliseconds() - m.nrTimeSinceLastError)
    end if
    'TTFF calculated internally by RokuOS
    ev.AddReplace("timeToStartStreaming", m.nrVideoObject.timeToStartStreaming * 1000)
    'Playtimes
    ev.AddReplace("totalPlaytime", nrCalculateTotalPlaytime() * 1000)
    if m.nrPlaytimeSinceLastEvent = invalid
        ev.AddReplace("playtimeSinceLastEvent", 0)
    else
        ev.AddReplace("playtimeSinceLastEvent", m.nrPlaytimeSinceLastEvent.TotalMilliseconds())
    end if
    if m.nrTotalAdPlaytime > 0
        ev.AddReplace("totalAdPlaytime", m.nrTotalAdPlaytime)
    end if
    videoContent = m.nrVideoObject.content
    if videoContent <> invalid
        contentNode = videoContent.getChild(m.nrVideoObject.contentIndex)
        ' Check if contentNode is valid
        if contentNode <> invalid
            contentTitle = contentNode.title
            if contentTitle <> invalid
                ev.AddReplace("contentTitle", contentTitle)
            end if
        end if
    end if

    'Track bitrate after all attributes are processed (including contentBitrate)
    if ev["actionName"] <> "QOE_AGGREGATE"
        nrTrackBitrateForQoe(ev["contentBitrate"], ev["actionName"])
    end if

return ev
end function

'=============='
' Ad functions '
'=============='

function nrExtractAdBitrate(ad as Object) as Integer
    ' Custom logic to extract bitrate from ad object properties - returns bitrate in bps
   
    if ad = invalid 
        nrLog("DEBUG: ad object is invalid, returning 0")
        return 0
    end if
    
    
    
    ' Method 1: Calculate dynamic bitrate from video node streaming data (similar to webkit approach)
    nrLog("DEBUG: Trying method 1 - dynamic bitrate calculation")
    dynamicBitrate = nrCalculateAdBitrate()
    nrLog(["DEBUG: dynamicBitrate result = ", dynamicBitrate])
    if dynamicBitrate > 0
        ' Dynamic bitrate is already in bps
        nrLog(["DEBUG: Returning dynamic bitrate (bps) = ", dynamicBitrate])
        return dynamicBitrate
    end if
    
    ' Method 2: Check for streams array with bitrate info
    nrLog("DEBUG: Trying method 2 - streams array bitrate")
    if ad.streams <> invalid and ad.streams.Count() > 0
        nrLog(["DEBUG: Found streams, count = ", ad.streams.Count()])
        for each stream in ad.streams
            if stream <> invalid
                nrLog(["DEBUG: stream keys = ", stream.Keys()])
                ' Check various bitrate fields in stream
                if stream.bitrate <> invalid
                    nrLog(["DEBUG: Found bitrate in stream = ", stream.bitrate])
                    nrLog(["DEBUG: bitrate type = ", type(stream.bitrate)])
                    ' Handle different types - bitrate might already be an integer
                    bitrateValue = 0
                    if type(stream.bitrate) = "roInt" or type(stream.bitrate) = "Integer"
                        bitrateValue = stream.bitrate
                    else if type(stream.bitrate) = "roString" or type(stream.bitrate) = "String"
                        bitrateValue = stream.bitrate.ToInt()
                    else
                        ' Try to convert to integer directly
                        bitrateValue = Int(stream.bitrate)
                    end if
                    ' Assume if value > 10000 it's in bps, otherwise it's in kbps and needs conversion
                    if bitrateValue > 10000
                        nrLog(["DEBUG: Returning bitrate (already in bps) = ", bitrateValue])
                        return bitrateValue
                    else
                        bitrateBps = bitrateValue * 1000
                        nrLog(["DEBUG: Converted kbps to bps = ", bitrateBps])
                        return bitrateBps
                    end if
                else if stream.bitrateKbps <> invalid
                    nrLog(["DEBUG: Found bitrateKbps in stream = ", stream.bitrateKbps])
                    ' Convert bitrateKbps to bps
                    bitrateValue = 0
                    if type(stream.bitrateKbps) = "roInt" or type(stream.bitrateKbps) = "Integer"
                        bitrateValue = stream.bitrateKbps
                    else if type(stream.bitrateKbps) = "roString" or type(stream.bitrateKbps) = "String"
                        bitrateValue = stream.bitrateKbps.ToInt()
                    else
                        bitrateValue = Int(stream.bitrateKbps)
                    end if
                    bitrateBps = bitrateValue * 1000
                    nrLog(["DEBUG: Converted bitrateKbps to bps = ", bitrateBps])
                    return bitrateBps
                else if stream.bitrateBps <> invalid
                    nrLog(["DEBUG: Found bitrateBps in stream = ", stream.bitrateBps])
                    ' bitrateBps is already in bps, return as-is
                    if type(stream.bitrateBps) = "roInt" or type(stream.bitrateBps) = "Integer"
                        return stream.bitrateBps
                    else if type(stream.bitrateBps) = "roString" or type(stream.bitrateBps) = "String"
                        return stream.bitrateBps.ToInt()
                    else
                        return Int(stream.bitrateBps)
                    end if
                else if stream.bandwidth <> invalid
                    nrLog(["DEBUG: Found bandwidth in stream = ", stream.bandwidth])
                    ' Convert bandwidth to bps if needed
                    bandwidthValue = 0
                    if type(stream.bandwidth) = "roInt" or type(stream.bandwidth) = "Integer"
                        bandwidthValue = stream.bandwidth
                    else if type(stream.bandwidth) = "roString" or type(stream.bandwidth) = "String"
                        bandwidthValue = stream.bandwidth.ToInt()
                    else
                        bandwidthValue = Int(stream.bandwidth)
                    end if
                    ' Assume if value > 10000 it's in bps, otherwise it's in kbps and needs conversion
                    if bandwidthValue > 10000
                        nrLog(["DEBUG: Returning bandwidth (already in bps) = ", bandwidthValue])
                        return bandwidthValue
                    else
                        bitrateBps = bandwidthValue * 1000
                        nrLog(["DEBUG: Converted bandwidth kbps to bps = ", bitrateBps])
                        return bitrateBps
                    end if
                end if
            end if
        end for
    else
        nrLog("DEBUG: No streams found")
    end if
    
    ' Method 2b: Check for media files with bitrate info (fallback)
    nrLog("DEBUG: Trying method 2b - media files bitrate")
    if ad.mediaFiles <> invalid
        nrLog(["DEBUG: Found mediaFiles, count = ", ad.mediaFiles.Count()])
        for each mediaFile in ad.mediaFiles
            nrLog(["DEBUG: mediaFile keys = ", mediaFile.Keys()])
            if mediaFile.bitrate <> invalid
                nrLog(["DEBUG: Found bitrate in mediaFile = ", mediaFile.bitrate])
                bitrateValue = mediaFile.bitrate.ToInt()
                ' Assume if value > 10000 it's in bps, otherwise it's in kbps and needs conversion
                if bitrateValue > 10000
                    nrLog(["DEBUG: Returning mediaFile bitrate (already in bps) = ", bitrateValue])
                    return bitrateValue
                else
                    bitrateBps = bitrateValue * 1000
                    nrLog(["DEBUG: Converted mediaFile bitrate kbps to bps = ", bitrateBps])
                    return bitrateBps
                end if
            else if mediaFile.bitrateKbps <> invalid
                nrLog(["DEBUG: Found bitrateKbps in mediaFile = ", mediaFile.bitrateKbps])
                bitrateBps = mediaFile.bitrateKbps.ToInt() * 1000
                nrLog(["DEBUG: Converted mediaFile bitrateKbps to bps = ", bitrateBps])
                return bitrateBps
            end if
        end for
    else
        nrLog("DEBUG: No mediaFiles found")
    end if
    
    ' Method 3: Parse bitrate from media URL patterns (e.g., "_1000k", "_2mbps")
    nrLog("DEBUG: Trying method 3 - URL pattern parsing")
    if ad.url <> invalid
        nrLog(["DEBUG: Found ad.url = ", ad.url])
        result = nrParseBitrateFromUrl(ad.url)
        if result > 0
            nrLog(["DEBUG: Parsed bitrate from url = ", result])
            return result
        end if
    else if ad.mediaurl <> invalid
        nrLog(["DEBUG: Found ad.mediaurl = ", ad.mediaurl])
        result = nrParseBitrateFromUrl(ad.mediaurl)
        if result > 0
            nrLog(["DEBUG: Parsed bitrate from mediaurl = ", result])
            return result
        end if
    else if ad.videourl <> invalid
        nrLog(["DEBUG: Found ad.videourl = ", ad.videourl])
        result = nrParseBitrateFromUrl(ad.videourl)
        if result > 0
            nrLog(["DEBUG: Parsed bitrate from videourl = ", result])
            return result
        end if
    else
        nrLog("DEBUG: No URL fields found in ad object")
    end if
    
    ' Method 4: Use minbandwidth as fallback if available
    nrLog("DEBUG: Trying method 4 - minbandwidth fallback")
    if ad.minbandwidth <> invalid and ad.minbandwidth > 0
        ' Convert minbandwidth to bps - assume it's in kbps if < 10000, otherwise already bps
        result = ad.minbandwidth
        if result < 10000
            result = result * 1000  ' Convert kbps to bps
        end if
        nrLog(["DEBUG: Found minbandwidth converted to bps = ", result])
        return result
    else
        nrLog("DEBUG: No minbandwidth available")
    end if
    
    nrLog("DEBUG: No bitrate found - returning 0")
    return 0  ' No bitrate found - only use truly dynamic methods, not hardcoded estimates
end function

function nrCalculateAdBitrate() as Integer
    ' Calculate bitrate dynamically from streaming data (similar to webkitVideoDecodedByteCount)
    nrLog("DEBUG: nrCalculateAdBitrate called")
    if m.nrVideoObject = invalid 
        nrLog("DEBUG: nrVideoObject is invalid, returning 0")
        return 0
    end if
    
    ' Get current streaming info
    streamInfo = m.nrVideoObject.streamInfo
    if streamInfo = invalid 
        nrLog("DEBUG: streamInfo is invalid, returning 0")
        return 0
    end if
    
    nrLog(["DEBUG: streamInfo keys = ", streamInfo.Keys()])
    
    ' Method 1: Use streamInfo.measuredBitrate if available
    if streamInfo.measuredBitrate <> invalid and streamInfo.measuredBitrate > 0
        nrLog(["DEBUG: Found measuredBitrate = ", streamInfo.measuredBitrate])
        return streamInfo.measuredBitrate
    else
        nrLog("DEBUG: No measuredBitrate available")
    end if
    
    ' Method 2: Calculate from downloadedSegments and time
    if streamInfo.downloadedSegments <> invalid and streamInfo.downloadedSegments > 0
        ' Initialize tracking variables if not exists
        if m.nrAdBitrateTracker = invalid
            m.nrAdBitrateTracker = {
                lastBytes: 0,
                lastTime: 0,
                samples: []
            }
        end if
        
        currentTime = m.nrTimer.TotalMilliseconds()
        currentBytes = 0
        
        ' Sum up bytes from downloaded segments
        if streamInfo.downloadedBytes <> invalid
            currentBytes = streamInfo.downloadedBytes
        end if
        
        ' Calculate delta if we have previous measurement
        if m.nrAdBitrateTracker.lastBytes > 0 and currentBytes > m.nrAdBitrateTracker.lastBytes
            deltaBytes = currentBytes - m.nrAdBitrateTracker.lastBytes
            deltaTime = (currentTime - m.nrAdBitrateTracker.lastTime) / 1000.0  ' Convert to seconds
            
            if deltaTime > 0
                bitrate = Int((deltaBytes / deltaTime) * 8)  ' Convert bytes/sec to bits/sec
                
                ' Store sample for averaging
                m.nrAdBitrateTracker.samples.Push(bitrate)
                
                ' Keep only last 5 samples for rolling average
                if m.nrAdBitrateTracker.samples.Count() > 5
                    m.nrAdBitrateTracker.samples.Shift()
                end if
                
                ' Update tracking values
                m.nrAdBitrateTracker.lastBytes = currentBytes
                m.nrAdBitrateTracker.lastTime = currentTime
                
                ' Return averaged bitrate
                return nrCalculateAverageBitrate(m.nrAdBitrateTracker.samples)
            end if
        else
            ' First measurement, just store values
            m.nrAdBitrateTracker.lastBytes = currentBytes
            m.nrAdBitrateTracker.lastTime = currentTime
        end if
    end if
    
    ' Method 3: Use segment bitrate if available
    streamingSegment = m.nrVideoObject.streamingSegment
    if streamingSegment <> invalid and streamingSegment.segBitrateBps <> invalid
        return streamingSegment.segBitrateBps
    end if
    
    return 0
end function

function nrCalculateAverageBitrate(samples as Object) as Integer
    if samples.Count() = 0 then return 0
    
    total = 0
    for each sample in samples
        total = total + sample
    end for
    
    return Int(total / samples.Count())
end function

function nrResetAdBitrateTracker() as Void
    ' Reset bitrate tracking when ad starts/ends
    m.nrAdBitrateTracker = invalid
end function

function nrParseBitrateFromUrl(url as String) as Integer
    ' Parse common bitrate patterns from URLs - returns bitrate in bps
    if url = invalid then return 0
    
    ' Pattern: _1000k, _2000k, etc. (in kbps)
    regex = CreateObject("roRegex", "_(\d+)k", "i")
    match = regex.Match(url)
    if match.Count() > 1
        return match[1].ToInt() * 1000  ' Convert kbps to bps
    end if
    
    ' Pattern: _1mbps, _2mbps, etc. (in mbps)
    regex = CreateObject("roRegex", "_(\d+)mbps", "i")
    match = regex.Match(url)
    if match.Count() > 1
        return match[1].ToInt() * 1000000  ' Convert mbps to bps
    end if
    
    ' Pattern: bitrate=1000000 in URL parameters
    regex = CreateObject("roRegex", "bitrate=(\d+)", "i")
    match = regex.Match(url)
    if match.Count() > 1
        bitrateValue = match[1].ToInt()
        ' Assume if value > 10000 it's in bps, otherwise it's in kbps and needs conversion
        if bitrateValue > 10000
            return bitrateValue  ' Already in bps
        else
            return bitrateValue * 1000  ' Convert kbps to bps
        end if
    end if
    
    return 0
end function





function nrAddRAFAttributes(ev as Object, ctx as Dynamic) as Object
    if ctx.rendersequence <> invalid
        if ctx.rendersequence = "preroll" then ev.AddReplace("adPosition", "pre")
        if ctx.rendersequence = "midroll" then ev.AddReplace("adPosition", "mid")
        if ctx.rendersequence = "postroll" then ev.AddReplace("adPosition", "post")
    end if
    
    if ctx.duration <> invalid
        ev.AddReplace("adDuration", ctx.duration * 1000)
    end if
    
    if ctx.server <> invalid
        ev.AddReplace("adSrc", ctx.server)
    end if
    
    if ctx.ad <> invalid
        if ctx.ad.adid <> invalid
            ev.AddReplace("adId", ctx.ad.adid)
        end if
        if ctx.ad.creativeid <> invalid
            ev.AddReplace("adCreativeId", ctx.ad.creativeid)
        end if
        if ctx.ad.adtitle <> invalid
            ev.AddReplace("adTitle", ctx.ad.adtitle)
        end if
        ' Add adBitrate for IMA tracker
        if ctx.ad.bitrate <> invalid
            ev.AddReplace("adBitrate", ctx.ad.bitrate)
        else if ctx.ad.bitrateKbps <> invalid
            ev.AddReplace("adBitrate", ctx.ad.bitrateKbps * 1000)
        else if ctx.ad.bitrateBps <> invalid
            ev.AddReplace("adBitrate", ctx.ad.bitrateBps)
        else
            ' Custom logic to extract bitrate from ad properties
            nrLog("DEBUG: Attempting to extract ad bitrate from ctx.ad")
            extractedBitrate = nrExtractAdBitrate(ctx.ad)
            nrLog(["DEBUG: extractedBitrate result = ", extractedBitrate])
            if extractedBitrate > 0
                ev.AddReplace("adBitrate", extractedBitrate)
                nrLog(["DEBUG: Successfully set adBitrate to ", extractedBitrate])
            else
                nrLog("DEBUG: No bitrate extracted, adBitrate not set")
            end if
        end if
    end if
    
    ' Check for adBitrate directly in ctx for IMA SDK
    if ctx.adBitrate <> invalid
        ev.AddReplace("adBitrate", ctx.adBitrate)
    else if ctx.bitrate <> invalid
        ev.AddReplace("adBitrate", ctx.bitrate)
    end if
    
    if m.rafState.timeSinceAdRequested <> 0
        ev.AddReplace("timeSinceAdRequested", m.nrTimer.TotalMilliseconds() - m.rafState.timeSinceAdRequested)
    end if
    
    if m.rafState.timeSinceAdStarted <> 0
        ev.AddReplace("timeSinceAdStarted", m.nrTimer.TotalMilliseconds() - m.rafState.timeSinceAdStarted)
    end if
    
    ' Add timeSinceLastAdError attribute ONLY for VideoAdAction events
    if ev.eventType = "VideoAdAction" and m.nrTimeSinceLastAdError > 0
        ev.AddReplace("timeSinceLastAdError", m.nrTimer.TotalMilliseconds() - m.nrTimeSinceLastAdError)
    end if
    
    ev.AddReplace("adPartner", "raf")
    ev.AddReplace("numberOfAds", m.rafState.numberOfAds)
    
    return ev
end function

function nrSendRAFEvent(actionName as String, ctx as Dynamic, attr = invalid) as Void
    ev = nrCreateEvent("VideoAdAction", actionName)
    ev = nrAddVideoAttributes(ev)
    ev = nrAddRAFAttributes(ev, ctx)
    ev = nrAddCustomAttributes(ev)
    if type(attr) = "roAssociativeArray"
       ev.Append(attr)
    end if
    nrRecordEvent(ev)
end function

function nrResetRAFState() as Void
    m.rafState.didFirstQuartile = false
    m.rafState.didSecondQuartile = false
    m.rafState.didThirdQuartile = false
end function

function nrResetRAFTimers() as Void
    m.rafState.timeSinceAdBreakBegin = 0
    m.rafState.timeSinceAdRequested = 0
    m.rafState.timeSinceAdStarted = 0
    m.rafState.timeSinceAdPaused = 0
end function

'=================='
' Helper functions '
'=================='

function isAction(name as String, action as String) as Boolean
    regExp = "(CONTENT|AD)_" + name
    r = CreateObject("roRegex", regExp, "")
    return r.isMatch(action)
end function

function nrExtractDomainFromUrl(url as String) as String
    'Extract domain from the URL
    r = CreateObject("roRegex", "\/\/|\/", "")
    arr = r.Split(url)
    if arr.Count() < 2 then return ""
    if arr[0] <> "http:" and arr[0] <> "https:" then return ""
    if arr[1] = "" then return ""
    domain = arr[1]

    ' Check all patterns in m.domainPatterns
    for each item in m.domainPatterns.Items()
        r = CreateObject("roRegex", item.key, "")
        if r.isMatch(domain)
            return r.Replace(domain, item.value)
        end if
    end for

    ' If nothing matches, it just returns the whole domain
    return domain
end function

function nrGenerateId() as String
    timestamp = CreateObject("roDateTime").asSeconds()
    randStr = "ID" + Str(timestamp) + Str(Rnd(0) * 1000.0)
    ba = CreateObject("roByteArray")
    ba.FromAsciiString(randStr)
    digest = CreateObject("roEVPDigest")
    digest.Setup("md5")
    result = digest.Process(ba)
    return result
end function

function nrGenerateStreamUrl() as String
    if m.nrVideoObject.streamInfo <> invalid
        return m.nrVideoObject.streamInfo["streamUrl"]
    else
        if m.nrVideoObject.contentIsPlaylist and m.nrVideoObject.content <> invalid
            currentChild = m.nrVideoObject.content.getChild(m.nrVideoObject.contentIndex)
            if currentChild <> invalid
                'Get url from content child
                return currentChild.url
            end if
        end if
    end if
    return ""
end function

function nrTimestamp() as LongInteger
    return nrTimestampFromDateTime(CreateObject("roDateTime"))
end function

function nrTimestampFromDateTime(timestampObj as object) as LongInteger
    timestamp = timestampObj.asSeconds()
    nowMilliseconds = timestampObj.GetMilliseconds()

    timestampLong& = timestamp
    timestampMS& = timestampLong& * 1000 + nowMilliseconds

    return timestampMS&
end function

function nrGetOSVersion(dev as Object) as Object
    if FindMemberFunction(dev, "GetOSVersion") <> Invalid
        verDict = dev.GetOsVersion()
        return {version: verDict.major + "." + verDict.minor + "." + verDict.revision, build: verDict.build}
    else
        'As roDeviceInfo.GetVersion() has been deprecated in version 9.2, return last supported version or lower as version
        return {version: "<=9.1", build: "0"}
    end if
end function

function nrResetPlaytime() as Void
    m.nrTotalPlaytime = 0.0
    m.nrTotalPlaytimeLastTimestamp = 0
    m.nrPlaytimeIsRunning = false
end function

function nrResumePlaytime() as Void
    if m.nrPlaytimeIsRunning = false
        m.nrPlaytimeIsRunning = true
        date = CreateObject("roDateTime")
        m.nrTotalPlaytimeLastTimestamp = date.AsSeconds()
    end if
end function

function nrPausePlaytime() as Void
    if m.nrPlaytimeIsRunning = true
        m.nrPlaytimeIsRunning = false
        date = CreateObject("roDateTime")
        offset = date.AsSeconds() - m.nrTotalPlaytimeLastTimestamp
        m.nrTotalPlaytime = m.nrTotalPlaytime + offset 
    end if
end function

function nrCalculateTotalPlaytime() as Integer
    if m.nrPlaytimeIsRunning = true
        date = CreateObject("roDateTime")
        offset = date.AsSeconds() - m.nrTotalPlaytimeLastTimestamp
        return m.nrTotalPlaytime + offset        
    else
        return m.nrTotalPlaytime
    end if
end function

' Implement simple reservoir sampling (Algorithm R)
function nrAddSample(sample as Object, buffer as Object, i as Integer, k as Integer) as Integer
    if i < k
        buffer.Push(sample)
        nrLog(["RESERVOIR BUFFER SIZE AFTER PUSH = ", buffer.Count()])
    else
        j = Rnd(i) - 1
        if j < k
            buffer[j] = sample
            nrLog(["RESERVOIR: OVERWRITE SAMPLE AT = ", j])
        else
            nrLog("RESERVOIR: DISCARD SAMPLE")
        end if
    end if
    return i + 1
end function

' Get back samples after an error and resample buffer if necessary
function nrGetBackSamples(samples as Object, buffer as Object, i as Integer, k as Integer) as Integer
    if samples.Count() + buffer.Count() > k
        ' Buffer size exceeded, we have to resample
        tmpBuffer = []
        tmpBuffer.Append(buffer)
        buffer.Clear()
        i = 0
        for each s in samples
            i = nrAddSample(s, buffer, i, k)
        end for
        for each s in tmpBuffer
            i = nrAddSample(s, buffer, i, k)
        end for
        nrLog(["nrGetBackSamples: RESERVOIR RESAMPLED. ARRAY SIZE = ", buffer.Count()])
    else
        nrLog("nrGetBackSamples: JUST APPEND ARRAY AS IS")
        buffer.Append(samples)
        i = buffer.Count()
    end if
    return i
end function

function nrExtractAllEvents() as Object
    events = m.nrEventArray
    m.nrEventArray = []
    m.nrEventArrayIndex = 0
    return events
end function

function nrGetBackEvents(events as Object) as Void
    nrLog("------> nrGetBackEvents, current K = " + str(m.nrEventArrayK) + ", ev size = " + str(events.Count()))
    m.nrEventArrayIndex = nrGetBackSamples(events, m.nrEventArray, m.nrEventArrayIndex, m.nrEventArrayK)
end function

function nrExtractAllLogs() as Object
    logs = m.nrLogArray
    m.nrLogArray = []
    m.nrLogArrayIndex = 0
    return logs
end function

function nrGetBackLogs(logs as Object) as Void
    nrLog("------> nrGetBackLogs, current K = " + str(m.nrLogArrayK) + ", log size = " + str(logs.Count()))
    m.nrLogArrayIndex = nrGetBackSamples(logs, m.nrLogArray, m.nrLogArrayIndex, m.nrLogArrayK)
end function

function nrExtractAllMetrics() as Object
    metrics = m.nrMetricArray
    m.nrMetricArray = []
    m.nrMetricArrayIndex = 0
    return metrics
end function

function nrGetBackMetrics(metrics as Object) as Void
    nrLog("------> nrGetBackMetrics, current K = " + str(m.nrMetricArrayK) + ", metric size = " + str(metrics.Count()))
    m.nrMetricArrayIndex = nrGetBackSamples(metrics, m.nrMetricArray, m.nrMetricArrayIndex, m.nrMetricArrayK)
end function

' Check if roAppMemoryMonitor is available for current device according to official docs:
' https://developer.roku.com/docs/references/brightscript/interfaces/ifappmemorymonitor.md
function isMemoryMonitorAvailable(deviceModel as String) as boolean
    'Liberty 5000X
    'Austin 4200X
    'Mustang 4210X 4230X
    'Littlefield 3700X 3710X
    if deviceModel = "5000X" or deviceModel = "4200X" or deviceModel = "4210X" or deviceModel = "4230X" or deviceModel = "3700X" or deviceModel = "3710X"
        return false
    else
        return true
    end if
end function
'================================'
' Observers, States and Handlers '
'================================'

function nrStateObserver() as Void
    nrLog("---------- State Observer ----------")
    nrLogVideoInfo()

    if m.nrVideoObject.state = "playing"
        nrStateTransitionPlaying()
    else if m.nrVideoObject.state = "paused"
        nrStateTransitionPaused()
    else if m.nrVideoObject.state = "buffering"
        nrStateTransitionBuffering()
    else if m.nrVideoObject.state = "finished" or m.nrVideoObject.state = "stopped"
        nrStateTransitionEnd()
    else if m.nrVideoObject.state = "error"
        nrStateTransitionError()
    end if
    
    m.nrLastVideoState = m.nrVideoObject.state

end function

function nrStateTransitionPlaying() as Void
    if m.nrLastVideoState = "paused" or m.nrLastVideoState = "buffering"
        ' Resume playtime tracking
        m.nrIsPlaying = true
        m.nrLastPlayTimestamp = CreateObject("roDateTime").AsSeconds()
    end if
    nrLog("nrStateTransitionPlaying")
    if m.nrLastVideoState = "paused"
        nrSendResume()
    else if m.nrLastVideoState = "buffering"
        'if current Src is equal to previous, send start, otherwise not
        currentSrc = nrGenerateStreamUrl()
        lastSrc = m.nrBackupAttributes["contentSrc"]
        if lastSrc = invalid then lastSrc = m.nrBackupAttributes["adSrc"]
        
        'Store intial buffering state and send buffer end
        shouldSendStart = m.nrIsInitialBuffering
        nrSendBufferEnd()
        
        if lastSrc = currentSrc OR m.nrVideoObject.contentIsPlaylist = false
            'Send Start only if initial start not sent already
            if shouldSendStart then nrSendStart()
        end if
    end if
end function

function nrStateTransitionPaused() as Void
    nrLog("nrStateTransitionPaused")
    if m.nrLastVideoState = "playing"
        currentTime = CreateObject("roDateTime").AsSeconds()
        m.nrHeartbeatElapsedTime = m.nrHeartbeatElapsedTime + (currentTime - m.nrLastPlayTimestamp)
        m.nrIsPlaying = false
        nrSendPause()
    end if
end function

function nrStateTransitionBuffering() as Void
    nrLog("nrStateTransitionBuffering")
    ' Send CONTENT_REQUEST when transitioning from none, stopped, or finished
    ' This handles initial playback and replay scenarios
    if m.nrLastVideoState = "none" OR m.nrLastVideoState = "stopped" OR m.nrLastVideoState = "finished"
        nrSendRequest()
    end if
    nrSendBufferStart()
end function

function nrStateTransitionEnd() as Void
    nrLog("nrStateTransitionEnd")
    if m.nrLastVideoState = "buffering"
        nrSendBufferEnd()
    end if
    nrSendEnd()
end function

function nrStateTransitionError() as Void
    nrLog("nrStateTransitionError")
    if m.nrLastVideoState = "buffering"
        nrSendBufferEnd()
    end if
    m.nrNumberOfErrors = m.nrNumberOfErrors + 1
    m.nrTimeSinceLastError = m.nrTimer.TotalMilliseconds()  ' calculating time of error'
    nrSendError(m.nrVideoObject)
end function

'This corresponds to the NEXT event, it happens when the playlist index changes
function nrIndexObserver() as Void
    nrLog("---------- Index Observer ----------")
    nrLogVideoInfo()
    
    'Check if the index change happened with an invalid playlist
    if m.nrVideoObject.contentIsPlaylist = false or m.nrVideoObject.content = invalid
        return
    end if
    
    '- Use nrSendBackupVideoEvent to send the END using previous video attributes.
    '  We do this because of how Roku handles playlists: when the next video starts, no "finished" event is sent for the previous,
    '  instead a buffering cycle happens, followed by an index change. The video attributes are mixed during this process, some belong
    '  to the next video, some to the previous. In order to send an END that belongs to the ending video, we have to make this trick.
    nrSendBackupVideoEnd()
    '- Send REQUEST and START using normal send, with current video attributes
    m.nrVideoCounter = m.nrVideoCounter + 1
    nrSendRequest()
    nrSendStart()
end function

function nrLicenseStatusObserver(event as Object) as Void
    licenseStatus = event.getData()
    attr = getLicenseStatusAttributes(licenseStatus)
    nrSendVideoEvent("LICENSE_STATUS", attr)
end function

function getLicenseStatusAttributes(licenseStatus as Object) as object
    return {
        "licenseStatusDuration": licenseStatus.duration,
        "licenseStatusKeySystem": licenseStatus.keySystem,
        "licenseStatusResponse": licenseStatus.response,
        "licenseStatusStatus": licenseStatus.status
    }
end function

function nrHeartbeatHandler() as Void
    ' Only send while it is playing (state is not "none" or "finished")
    if m.nrVideoObject.state <> "none" and m.nrVideoObject.state <> "finished"
        if m.nrIsPlaying
            currentTime = CreateObject("roDateTime").AsSeconds()
            m.nrHeartbeatElapsedTime = m.nrHeartbeatElapsedTime + (currentTime - m.nrLastPlayTimestamp)
            m.nrLastPlayTimestamp = currentTime
        end if

        ' Send content heartbeat with elapsed time for the last period
        m.nrHeartbeatElapsedTime = m.nrHeartbeatElapsedTime * 1000
        nrSendVideoEvent("CONTENT_HEARTBEAT", {"elapsedTime": m.nrHeartbeatElapsedTime})

        'Send QOE aggregate event with each heartbeat
        nrSendQoeAggregate()

        ' Reset the heartbeatElapsedTime after sending the heartbeat
        m.nrHeartbeatElapsedTime = 0.0

        m.nrTimeSinceLastHeartbeat = m.nrTimer.TotalMilliseconds()
        if m.nrPlaytimeSinceLastEvent <> invalid
            m.nrPlaytimeSinceLastEvent.Mark()
        end if
    end if
end function

function nrSendHttpCountMetrics() as Void
    'Set final time interval
    m.http_counters_max_ts.Mark()

    'Total counter interval (since last harvest)
    interval = nrTimestampFromDateTime(m.http_counters_max_ts) - nrTimestampFromDateTime(m.http_counters_min_ts)

    'Generate a counter metrics for each domain
    for each item in m.num_http_request_counters.Items()
        nrSendCountMetric("roku.http.request.count", item.value, interval, {"domain": item.key})
    end for
    for each item in m.num_http_response_counters.Items()
        nrSendCountMetric("roku.http.response.count", item.value, interval, {"domain": item.key})
    end for
    for each item in m.num_http_response_errors.Items()
        nrSendCountMetric("roku.http.response.error.count", item.value, interval, {"domain": item.key})
    end for
    for each item in m.num_http_connect_counters.Items()
        nrSendCountMetric("roku.http.connect.count", item.value, interval, {"domain": item.key})
    end for
    for each item in m.num_http_complete_counters.Items()
        nrSendCountMetric("roku.http.complete.count", item.value, interval, {"domain": item.key})
    end for
    for each item in m.num_http_error_counters.Items()
        nrSendCountMetric("roku.http.error.count", item.value, interval, {"domain": item.key})
    end for

    'Set initial time interval
    m.http_counters_min_ts.Mark()

    'Reset counters
    m.num_http_request_counters.Clear()
    m.num_http_response_counters.Clear()
    m.num_http_response_errors.Clear()
    m.num_http_connect_counters.Clear()
    m.num_http_complete_counters.Clear()
    m.num_http_error_counters.Clear()
end function

function nrHarvestTimerHandlerEvents() as Void
    nrLog("--- nrHarvestTimerHandlerEvents ---")
    
    if LCase(m.bgTaskEvents.state) = "run"
        nrLog("NRTaskEvents still running, abort")
        return
    end if
    
    m.bgTaskEvents.control = "RUN"
end function

function nrHarvestTimerHandlerLogs() as Void
    nrLog("--- nrHarvestTimerHandlerLogs ---")
    
    if LCase(m.bgTaskLogs.state) = "run"
        nrLog("NRTaskLogs still running, abort")
        return
    end if
    
    m.bgTaskLogs.control = "RUN"
end function

function nrHarvestTimerHandlerMetrics() as Void
    nrLog("--- nrHarvestTimerHandlerMetrics ---")

    nrSendHttpCountMetrics()
    
    if LCase(m.bgTaskMetrics.state) = "run"
        nrLog("NRTaskMetrics still running, abort")
        return
    end if
    
    m.bgTaskMetrics.control = "RUN"
end function

'=================='
' Test and Logging '
'=================='

function nrLogVideoInfo() as Void
    nrLog("====================================")
    if (m.nrVideoObject <> invalid)
        nrLog(["Player state = ", m.nrVideoObject.state])
        nrLog(["Current position = ", m.nrVideoObject.position])
        nrLog(["Current duration = ", m.nrVideoObject.duration])
        if m.nrVideoObject.contentIsPlaylist and m.nrVideoObject.content <> invalid
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
            nrLog("Content is not a playlist or no content at all")
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

function nrLogEventArray() as Void
    nrLog("=========== EVENT ARRAY ============")
    for each ev in m.nrEventArray
        nrLog(ev)
        nrLog("----------------------------------")
    end for
    nrLog("====================================")
end function

'=========================='
' QOE Helper Functions     '
'=========================='

function nrTrackBitrateForQoe(contentBitrate as Dynamic, actionName as String) as Void
    if contentBitrate = invalid or contentBitrate = 0
        return
    end if

    'Skip if this is the same bitrate we just tracked (avoid duplicate processing)
    if m.qoeLastTrackedBitrate <> invalid and m.qoeLastTrackedBitrate = contentBitrate
        return
    end if

    'Update cached value to prevent duplicate processing
    m.qoeLastTrackedBitrate = contentBitrate

    nrUpdateTimeWeightedBitrate(contentBitrate)

    peakChanged = false
    if m.qoePeakBitrate = invalid or contentBitrate > m.qoePeakBitrate
        m.qoePeakBitrate = contentBitrate
        peakChanged = true
    end if

    m.qoeBitrateSum = m.qoeBitrateSum + contentBitrate
    m.qoeBitrateCount = m.qoeBitrateCount + 1

    'Log bitrate tracking (only when peak changes to reduce log spam)
    if peakChanged
        peakKbps = Int(m.qoePeakBitrate / 1000)
        print "[QOE] BITRATE: NEW PEAK "; peakKbps; " kbps"
    end if
end function

function nrUpdateTimeWeightedBitrate(newBitrate as Dynamic) as Void
    currentTime = m.nrTimer.TotalMilliseconds()

    'If we have a previous bitrate and timing, accumulate its weighted time
    if m.qoeCurrentBitrate <> invalid and m.qoeLastRenditionChangeTime <> invalid and m.qoeCurrentBitrate > 0
        if m.qoeLastRenditionChangeTime > 0 and currentTime >= m.qoeLastRenditionChangeTime
            segmentDuration = currentTime - m.qoeLastRenditionChangeTime
            if segmentDuration > 0
                'Convert to double to prevent integer overflow
                'BrightScript 32-bit integers overflow at ~2.1 billion
                'Example: 8,207,000 bps * 240,000 ms = 1.97 trillion (overflows!)
                bitrateDouble = CDbl(m.qoeCurrentBitrate)
                durationDouble = CDbl(segmentDuration)
                weightedContribution = bitrateDouble * durationDouble

                m.qoeTotalBitrateWeightedTime = m.qoeTotalBitrateWeightedTime + weightedContribution
                m.qoeTotalActiveTime = m.qoeTotalActiveTime + segmentDuration
            end if
        end if
    end if

    m.qoeCurrentBitrate = newBitrate
    m.qoeLastRenditionChangeTime = currentTime
end function

function nrCalculateTimeWeightedAverageBitrate() as Dynamic
    if m.qoeCurrentBitrate <> invalid and m.qoeLastRenditionChangeTime <> invalid and m.qoeCurrentBitrate > 0
        currentTime = m.nrTimer.TotalMilliseconds()

        if m.qoeLastRenditionChangeTime > 0 and currentTime >= m.qoeLastRenditionChangeTime
            currentSegmentDuration = currentTime - m.qoeLastRenditionChangeTime

            'Include current segment if it has meaningful duration
            if currentSegmentDuration > 0
                'Use double precision to prevent overflow in final calculation
                bitrateDouble = CDbl(m.qoeCurrentBitrate)
                durationDouble = CDbl(currentSegmentDuration)
                currentSegmentWeighted = bitrateDouble * durationDouble

                totalWeightedTime = m.qoeTotalBitrateWeightedTime + currentSegmentWeighted
                totalTime = m.qoeTotalActiveTime + currentSegmentDuration

                if totalTime > 0
                    return Int(totalWeightedTime / totalTime)
                end if
            else if m.qoeTotalActiveTime > 0
                'If current segment has zero duration, check if we have accumulated data
                return Int(m.qoeTotalBitrateWeightedTime / m.qoeTotalActiveTime)
            else if currentSegmentDuration = 0
                'If we have current bitrate but no accumulated time and zero segment duration,
                'return current bitrate as the average (single point average)
                return m.qoeCurrentBitrate
            end if
        end if
    end if

    'Fallback to accumulated data only
    if m.qoeTotalActiveTime <> invalid and m.qoeTotalActiveTime > 0 and m.qoeTotalBitrateWeightedTime <> invalid
        return Int(m.qoeTotalBitrateWeightedTime / m.qoeTotalActiveTime)
    end if

    return invalid  
end function

function nrCalculateQOEKpiAttributes() as Object
    kpiAttributes = CreateObject("roAssociativeArray")

    if m.qoeStartupTime = invalid and m.contentRequestTimestamp <> invalid
        endTimestamp = invalid

        'Determine end timestamp: use contentStartTimestamp (success) or contentErrorTimestamp (failure)
        if m.contentStartTimestamp <> invalid
            endTimestamp = m.contentStartTimestamp  
        else if m.contentErrorTimestamp <> invalid
            endTimestamp = m.contentErrorTimestamp  
        end if

        if endTimestamp <> invalid
            rawStartupTime = endTimestamp - m.contentRequestTimestamp

            print "[QOE] Calculating startup time: contentRequest="; m.contentRequestTimestamp; " contentStart="; m.contentStartTimestamp; " rawStartupTime="; rawStartupTime; " adTime="; m.startupPeriodAdTime

            'Exclude ad time from startup calculation
            if m.startupPeriodAdTime <> invalid and m.startupPeriodAdTime > 0
                if rawStartupTime >= m.startupPeriodAdTime
                    m.qoeStartupTime = rawStartupTime - m.startupPeriodAdTime
                    print "[QOE] Startup time calculated: "; m.qoeStartupTime; "ms (raw: "; rawStartupTime; "ms - ads: "; m.startupPeriodAdTime; "ms)"
                else
                    'rawStartupTime < adTime - This shouldn't happen in normal scenarios
                    'It means ads took longer than the time from request to content start
                    print "[QOE] WARNING: rawStartupTime ("; rawStartupTime; "ms) < adTime ("; m.startupPeriodAdTime; "ms) - Using 0"
                    m.qoeStartupTime = 0
                end if
            else
                'No ads - use raw calculation
                if rawStartupTime > 0
                    m.qoeStartupTime = rawStartupTime
                    print "[QOE] Startup time (no ads): "; m.qoeStartupTime; "ms"
                else
                    m.qoeStartupTime = 0
                    print "[QOE] Startup time set to 0 (no valid rawStartupTime)"
                end if
            end if
        else
            print "[QOE] Cannot calculate startup time - no endTimestamp (contentStart="; m.contentStartTimestamp; " contentError="; m.contentErrorTimestamp; ")"
        end if
    else if m.qoeStartupTime <> invalid
        print "[QOE] Using cached startup time: "; m.qoeStartupTime; "ms"
    end if

    'If startup succeeded or was instant (zero), include the numeric value
    'If startup failed (error before CONTENT_START), set to empty string per test requirement
    if m.qoeStartupTime <> invalid and m.qoeStartupTime >= 0
        kpiAttributes["startupTime"] = m.qoeStartupTime
    else if m.contentErrorTimestamp <> invalid and m.contentStartTimestamp = invalid
        'Error occurred before CONTENT_START, set startupTime to empty string
        kpiAttributes["startupTime"] = ""
    end if

    if m.qoePeakBitrate <> invalid and m.qoePeakBitrate > 0
        kpiAttributes["peakBitrate"] = m.qoePeakBitrate
    end if

    hadStartupFailure = false
    if m.contentErrorTimestamp <> invalid and m.contentStartTimestamp = invalid
        hadStartupFailure = true
    end if
    kpiAttributes["hadStartupFailure"] = hadStartupFailure

    kpiAttributes["hadPlaybackFailure"] = m.qoeHadPlaybackFailure

    kpiAttributes["totalRebufferingTime"] = m.qoeTotalRebufferingTime

    totalPlaytime = nrCalculateTotalPlaytime() * 1000  'Convert to milliseconds
    if totalPlaytime > 0
        rebufferingRatio = (m.qoeTotalRebufferingTime / totalPlaytime) * 100
        kpiAttributes["rebufferingRatio"] = rebufferingRatio
    else
        kpiAttributes["rebufferingRatio"] = 0.0
    end if

    kpiAttributes["totalPlaytime"] = totalPlaytime

    timeWeightedAverage = nrCalculateTimeWeightedAverageBitrate()
    if timeWeightedAverage <> invalid
        kpiAttributes["averageBitrate"] = timeWeightedAverage
    else if m.qoeBitrateCount > 0
        'Fallback to simple average if time-weighted calculation is not available
        averageBitrate = Int(m.qoeBitrateSum / m.qoeBitrateCount)
        kpiAttributes["averageBitrate"] = averageBitrate
    end if

    kpiAttributes["qoeAggregateVersion"] = "1.0.0"

    return kpiAttributes
end function

function nrSendQoeAggregate() as Void

    'Only send QOE_AGGREGATE if at least one VideoAction event occurred in this harvest cycle
    'This prevents QOE_AGGREGATE from being sent during ad-only periods
    if m.qoeHasVideoActionThisHarvest = false
        return  
    end if

    kpiAttributes = nrCalculateQOEKpiAttributes()

    'DEBUG: Log QOE metrics
    nrLogQoeMetrics(kpiAttributes)

    nrSendVideoEvent("QOE_AGGREGATE", kpiAttributes)

    'Reset flag for next harvest cycle
    m.qoeHasVideoActionThisHarvest = false
end function

'========================================
' QOE DEBUG LOGGING HELPER (Lightweight)
'========================================
function nrLogQoeMetrics(kpiAttributes as Object) as Void
    print "=== QOE_AGGREGATE ==="

    ' Startup Time
    if kpiAttributes.DoesExist("startupTime")
        print "startupTime: "; kpiAttributes.startupTime
    end if

    ' Bitrates
    if kpiAttributes.DoesExist("peakBitrate")
        print "peakBitrate: "; Int(kpiAttributes.peakBitrate / 1000); " kbps"
    end if
    if kpiAttributes.DoesExist("averageBitrate")
        print "averageBitrate: "; Int(kpiAttributes.averageBitrate / 1000); " kbps"
    end if

    ' Failures
    print "hadStartupFailure: "; kpiAttributes.hadStartupFailure
    print "hadPlaybackFailure: "; kpiAttributes.hadPlaybackFailure

    ' Rebuffering
    print "totalRebufferingTime: "; kpiAttributes.totalRebufferingTime; " ms"
    print "rebufferingRatio: "; kpiAttributes.rebufferingRatio; "%"

    ' Playtime
    print "totalPlaytime: "; Int(kpiAttributes.totalPlaytime / 1000); " sec"

    print "===================="
end function

function nrResetQoeMetrics() as Void
    'Reset QoE metrics when starting a new view session
    'This ensures that QoE KPIs are isolated per view ID
    m.qoePeakBitrate = 0
    m.qoeHadPlaybackFailure = false
    m.qoeTotalRebufferingTime = 0
    m.qoeBitrateSum = 0
    m.qoeBitrateCount = 0
    m.qoeLastTrackedBitrate = invalid
    m.qoeStartupTime = invalid  'Reset cached startup time for new view session

    'Reset startup time calculation fields
    m.contentRequestTimestamp = invalid
    m.contentStartTimestamp = invalid
    m.contentErrorTimestamp = invalid
    m.startupPeriodAdTime = 0
    m.hasContentStarted = false

    'Reset time-weighted bitrate fields
    m.qoeCurrentBitrate = invalid
    m.qoeLastRenditionChangeTime = invalid
    m.qoeTotalBitrateWeightedTime = 0
    m.qoeTotalActiveTime = 0

    'Reset harvest cycle tracking flag
    m.qoeHasVideoActionThisHarvest = false
end function
