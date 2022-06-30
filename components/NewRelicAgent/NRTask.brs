'**********************************************************
' NRTask.brs
' New Relic Agent background task.
'
' Copyright 2020 New Relic Inc. All Rights Reserved. 
'**********************************************************

sub init()
    m.top.functionName = "nrTaskMain"
end sub

'TODO: check that this works for metrics end point
function nrPushSamples(samples as Object, endpoint as String) as Object
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
    m.nr.callFunc("nrLog", "-- nrEventProcessor --")
    nrSampleProcessor("event", m.eventApiUrl)
end function

function nrLogProcessor() as Void
    m.nr.callFunc("nrLog", "-- nrLogProcessor --")
    nrSampleProcessor("log", m.logApiUrl)
end function

function nrMetricProcessor() as Void
    m.nr.callFunc("nrLog", "-- nrMetricProcessor --")
    'TODO: call sample processor. Prepare called functions to handle metrics
    'nrSampleProcessor("metric", m.metricApiUrl)
end function

function isStatusErr(res) as boolean
    return res >= 400
end function

function nrSampleProcessor(sampleType as String, endpoint as String) as Void
    if m.nr <> invalid
        samples = m.nr.callFunc("nrExtractAllSamples", sampleType)
        if samples.Count() > 0
            res = nrPushSamples(samples, endpoint)
            if isStatusErr(res)
                m.nr.callFunc("nrLog", "-- nrSampleProcessor (" + sampleType + "): FAILED with code " + Str(res) + ", retry later --")
                if res = 429
                    m.nr.callFunc("nrReqErrorTooManyReq", sampleType)
                else if res = 413
                    m.nr.callFunc("nrReqErrorTooLarge", sampleType)
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
    'print "---- Running NRTask ----"
    if m.nr = invalid
        'Assuming that parent node is com.newrelic.NRAgent
        m.nr = m.top.getParent()
        m.apiKey = m.top.apiKey
        m.eventApiUrl = m.top.eventApiUrl
        m.logApiUrl = m.top.logApiUrl
        m.metricApiUrl = m.top.metricApiUrl
        m.sampleType = m.top.sampleType
    end if
    if m.sampleType = "event"
        nrEventProcessor()
    else if m.sampleType = "log"
        nrLogProcessor()
    else if m.sampleType = "metric"
        nrMetricProcessor()
    end if
    'print "---- Ended running NRTask ----"
end function