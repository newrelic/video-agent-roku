'**********************************************************
' NRTask.brs
' New Relic Agent background task.
'
' Copyright 2020 New Relic Inc. All Rights Reserved. 
'**********************************************************

sub init()
    m.top.functionName = "nrTaskMain"
    m.loggingState = false
end sub

function nrPushSamples(samples as Object, endpoint as String, sampleType as String) as Object
    'Common attributes, only used with Metric and Log API. Event API uses a different format, without a common object, and these
    'properties are inserted in every event.
    commonObject = {
        "attributes": {
            "instrumentation.provider": "media",
            "instrumentation.name": "roku",
            "instrumentation.version": m.top.getParent().version
        }
    }
    'Use a different format for Metric API and Log API
    if sampleType = "metric"
        metricsModel = [{
            "metrics": samples,
            "common": commonObject,
        }]
        samples = metricsModel
    else if sampleType = "log"
        logsModel = [{
            "logs": samples,
            "common": commonObject,
        }]
        samples = logsModel
    end if

    jsonString = FormatJson(samples)

    rport = CreateObject("roMessagePort")
    urlReq = CreateObject("roUrlTransfer")

    urlReq.SetUrl(endpoint)
    urlReq.RetainBodyOnError(true)
    urlReq.EnablePeerVerification(false)
    urlReq.EnableHostVerification(false)
    urlReq.EnableEncodings(true)
    urlReq.AddHeader("Api-Key", m.apikey)
    urlReq.SetMessagePort(rport)
    urlReq.AsyncPostFromString(jsonString)
    
    msg = wait(10000, rport)
    if type(msg) = "roUrlEvent" then
        return msg.GetResponseCode()
    else
        'Timeout, cancel transfer and return error code
        nrLog("-- nrPushSamples: timeout, cancel request and return --")
        urlReq.AsyncCancel()
        return 0
    end if
end function

function nrEventProcessor() as Void
    nrLog("-- nrEventProcessor at URL " + m.eventApiUrl)
    nrSampleProcessor("event", m.eventApiUrl)
end function

function nrLogProcessor() as Void
    nrLog("-- nrLogProcessor at URL " + m.logApiUrl)
    nrSampleProcessor("log", m.logApiUrl)
end function

function nrMetricProcessor() as Void
    nrLog("-- nrMetricProcessor at URL " + m.metricApiUrl)
    nrSampleProcessor("metric", m.metricApiUrl)
end function

function isStatusErr(res) as boolean
    return res >= 400
end function

function nrSampleProcessor(sampleType as String, endpoint as String) as Void
    if m.nr <> invalid
        samples = m.nr.callFunc("nrExtractAllSamples", sampleType)
        if samples.Count() > 0
            if(sampleType = "event")
                rokuSystemSamples = []
                videoSamples = []
                    for i = 0 to samples.count() - 1
                         item = samples[i]
                        if type(item) = "roAssociativeArray"
                            if item["eventType"] = "RokuSystem"
                                rokuSystemSamples.push(item)
                            else    
                                print "Video Event"; item
                                videoSamples.push(item)
                            end if
                        end if
                    end for
                    print "FOR LOOP ENDED";videoSamples.count()
                    if rokuSystemSamples.count() > 0
                        res = nrPushSamples(rokuSystemSamples, endpoint, sampleType)
                    end if
                     if videoSamples.count() > 0
                        print "VIDEO SAMPLES OUTSIDE"
                       nres = nrData(videoSamples)
                    end if
                else 
                    res = nrPushSamples(samples, endpoint, sampleType)
            if isStatusErr(res)
                nrLog("-- nrSampleProcessor (" + sampleType + "): FAILED with code " + Str(res) + ", retry later --")
                if res = 429 or res = 408 or res = 503
                    'Increasing harvest cycle duration in case of error 408 or 503
                    'Refer: https://docs.newrelic.com/docs/data-apis/ingest-apis/event-api/introduction-event-api/#errors-submission
                    m.nr.callFunc("nrReqErrorTooManyReq", sampleType)
                else if res = 413
                    m.nr.callFunc("nrReqErrorTooLarge", sampleType)
                else if res = 403
                    'Handle 403 error in scenario of missing invalid key error from NR collector, printing the log and clearing the buffer
                    nrLog("-- missingInvalidLicenseKey (" + sampleType + "): FAILED with code " + Str(res))
                    m.nr.callFunc("nrReqOk", sampleType)
                    return
                end if
                m.nr.callFunc("nrGetBackAllSamples", sampleType, samples)
            else
                m.nr.callFunc("nrReqOk", sampleType)
            end if
            end if
        end if
    else
        print("-- nrSampleProcessor: m.nr is invalid!! --")
    end if
end function

function getV3ReqBody(dataToken,videoSamples,appInfo)
    ' To test if events are going or not you can write your own custom event name here
    '  videoSamples.push({ "timeSinceLoad": 3.4510000000000001, "eventType": "FinalTest", "timestamp": 1680034704303})
return [dataToken,appInfo,0,[],[],[],[],[],{},videoSamples]
end function

function nrData(videoSamples)
    
    body = getV3ReqBody(m.top.dataToken,videoSamples, m.top.appInfo)
    jsonRequestBody = FormatJSON(body)
    urlReq = CreateObject("roUrlTransfer")    
    rport = CreateObject("roMessagePort")
    urlReq.SetUrl("https://staging-mobile-collector.newrelic.com/mobile/v3/data")
    urlReq.RetainBodyOnError(true)
    urlReq.EnablePeerVerification(false)
    urlReq.EnableHostVerification(false)
    urlReq.EnableEncodings(true)
   
    urlReq.AddHeader("CONTENT-TYPE", "application/json")
    urlReq.AddHeader("X-NewRelic-OS-Name","RokuOS")
    urlReq.AddHeader("X-App-License-Key", m.top.appToken)
    urlReq.AddHeader("X-NewRelic-App-Version","1.0")
    urlReq.AddHeader("X-NewRelic-ID", "VwEFU1NaABAGVFBRAQUHU1w=")
    urlReq.SetMessagePort(rport)

    urlReq.AsyncPostFromString(jsonRequestBody)
    
   msg = wait(10000, rport)
    if type(msg) = "roUrlEvent" then
        print "Response Code: "; msg.GetResponseCode()
        return msg.GetResponseCode()
    else
        'Timeout, cancel transfer and return error code
        nrLog("-- nrData: timeout, cancel request and return --")
        urlReq.AsyncCancel()
        return 0
    end if
end function

function nrTaskMain() as Void
    if m.nr = invalid
        'Assuming that parent node is com.newrelic.NRAgent
        m.nr = m.top.getParent()
        m.apiKey = m.top.apiKey
        m.sampleType = m.top.sampleType
        if m.eventApiUrl = "" then m.eventApiUrl = m.top.eventApiUrl
        if m.logApiUrl = "" then m.logApiUrl = m.top.logApiUrl
        if m.metricApiUrl = "" then m.metricApiUrl = m.top.metricApiUrl
        m.loggingState = m.nr.callFunc("nrCheckLoggingState")
    end if
    nrLog("---- Running NRTask ---- " + m.sampleType)
    if m.sampleType = "event"
        nrEventProcessor()
    else if m.sampleType = "log"
        nrLogProcessor()
    else if m.sampleType = "metric"
        nrMetricProcessor()
    end if
    nrLog("---- Ended running NRTask ---- " + m.sampleType)
end function

function onConfigUpdate() as Void
    m.eventApiUrl = m.top.eventApiUrl
    m.logApiUrl = m.top.logApiUrl
    m.metricApiUrl = m.top.metricApiUrl
end function

function nrLog(msg as Dynamic) as Void
    if m.loggingState = true then m.nr.callFunc("nrLog", msg)
end function