'**********************************************************
' NRTask.brs
' New Relic Agent background task.
'
' Copyright 2020 New Relic Inc. All Rights Reserved. 
'**********************************************************

sub init()
    m.top.functionName = "nrTaskMain"
end sub

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
    nrSampleProcessor("nrExtractAllEvents", "nrGetBackEvents", m.eventApiUrl)
end function

function nrLogProcessor() as Void
    nrSampleProcessor("nrExtractAllLogs", "nrGetBackLogs", m.logApiUrl)
end function

function nrSampleProcessor(extractFunc as String, getbackFunc as String, endpoint as String) as Void
    if m.nr <> invalid
        samples = m.nr.callFunc(extractFunc)
        if samples.Count() > 0
            res = nrPushSamples(samples, endpoint)
            if res < 200 or res > 299
                m.nr.callFunc("nrLog", "-- nrSampleProcessor: FAILED with code " + Str(res) + ", retry later --")
                m.nr.callFunc(getbackFunc, samples)
            end if
        end if
    else
        print("-- nrSampleProcessor: m.nr is invalid!! --")
    end if
end function

function nrTaskMain() as Void
    'Assuming that parent node is com.newrelic.NRAgent
    'print "---- Running NRTask ----"
    if m.nr = invalid
        m.nr = m.top.getParent()
        m.apiKey = m.top.apiKey
        m.eventApiUrl = m.top.eventApiUrl
        m.logApiUrl = m.top.logApiUrl
    end if
    nrEventProcessor()
    nrLogProcessor()
    'print "---- Ended running NRTask ----"
end function