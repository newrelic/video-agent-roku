'**********************************************************
' NRTask.brs
' New Relic Agent background task.
'
' Copyright 2020 New Relic Inc. All Rights Reserved. 
'**********************************************************

sub init()
    m.top.functionName = "nrTaskMain"
end sub

function nrPushSamples(samples as Object, endpoint as String, sampleType as String) as Object
    'Metric API requires a specific format
    if sampleType = "metric"
        metricsModel = [{
            "metrics": samples
        }]
        samples = metricsModel
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
        m.nr.callFunc("nrLog", "-- nrPushSamples: timeout, cancel request and return --")
        urlReq.AsyncCancel()
        return 0
    end if
end function

function nrEventProcessor() as Void
    m.nr.callFunc("nrLog", "-- nrEventProcessor at URL " + m.eventApiUrl)
    nrSampleProcessor("event", m.eventApiUrl)
end function

function nrLogProcessor() as Void
    m.nr.callFunc("nrLog", "-- nrLogProcessor at URL " + m.logApiUrl)
    nrSampleProcessor("log", m.logApiUrl)
end function

function nrMetricProcessor() as Void
    m.nr.callFunc("nrLog", "-- nrMetricProcessor at URL " + m.metricApiUrl)
    nrSampleProcessor("metric", m.metricApiUrl)
end function

function isStatusErr(res) as boolean
    return res >= 400 or res = 0
end function

function nrSampleProcessor(sampleType as String, endpoint as String) as Void
    if m.nr <> invalid
        samples = m.nr.callFunc("nrExtractAllSamples", sampleType)
        if samples.Count() > 0
            res = nrPushSamples(samples, endpoint, sampleType)
            if isStatusErr(res)
                m.nr.callFunc("nrLog", "-- nrSampleProcessor (" + sampleType + "): FAILED with code " + Str(res) + ", retry later --")
                if res = 429 or res = 408 or res = 503
                    'Increasing harvest cycle duration in case of error 408 or 503
                    'Refer: https://docs.newrelic.com/docs/data-apis/ingest-apis/event-api/introduction-event-api/#errors-submission
                    m.nr.callFunc("nrReqErrorTooManyReq", sampleType)
                else if res = 413
                    m.nr.callFunc("nrReqErrorTooLarge", sampleType)
                else if res = 403
                    'Handle 403 error in scenario of missing invalid key error from NR collector, printing the log and clearing the buffer
                    m.nr.callFunc("nrLog", "-- missingInvalidLicenseKey (" + sampleType + "): FAILED with code " + Str(res))
                    m.nr.callFunc("nrReqOk", sampleType)
                    return
                end if
                m.nr.callFunc("nrGetBackAllSamples", sampleType, samples)
            else
                m.nr.callFunc("nrReqOk", sampleType)
            end if
        end if
    else
        print("-- nrSampleProcessor: m.nr is invalid!! --")
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
    end if
    m.nr.callFunc("nrLog", "---- Running NRTask ---- " + m.sampleType)
    if m.sampleType = "event"
        nrEventProcessor()
    else if m.sampleType = "log"
        nrLogProcessor()
    else if m.sampleType = "metric"
        nrMetricProcessor()
    end if
    m.nr.callFunc("nrLog", "---- Ended running NRTask ---- " + m.sampleType)
end function

function onConfigUpdate() as Void
    m.eventApiUrl = m.top.eventApiUrl
    m.logApiUrl = m.top.logApiUrl
    m.metricApiUrl = m.top.metricApiUrl
end function