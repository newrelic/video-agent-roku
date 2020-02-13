'**********************************************************
' NRTask.brs
' New Relic Agent background task.
'
' Copyright 2020 New Relic Inc. All Rights Reserved. 
'**********************************************************

sub init()
    m.top.functionName = "nrTaskMain"
end sub

function nrInsertInsightsData(attributes as Object) as Object
    url = box("https://insights-collector.newrelic.com/v1/accounts/" + m.top.accountNumber + "/events")
    apikey = m.top.apiKey
    jsonString = FormatJson(attributes)

    urlReq = CreateObject("roUrlTransfer")

    urlReq.SetUrl(url)
    urlReq.RetainBodyOnError(true)
    urlReq.EnablePeerVerification(false)
    urlReq.EnableHostVerification(false)
    urlReq.AddHeader("Content-Type", "application/json")
    urlReq.AddHeader("X-Insert-Key", apikey)

    resp = urlReq.PostFromString(jsonString)
    
    return resp
end function

function nrEventProcessor() as Void
    while true
        ev = m.nr.callFunc("nrExtractEvent")
        if ev = invalid then exit while
        res = nrInsertInsightsData(ev)
        if res <> 200
            m.nr.callFunc("nrLog", "-- nrEventProcessor: FAILED, retry later --")
            m.nr.callFunc("nrRecordEvent", ev)
            return
        else
            m.nr.callFunc("nrLog", "-- nrEventProcessor: insert insights data --")
            m.nr.callFunc("nrLog", [ev["actionName"], " ", ev["timestamp"]])
        end if
    end while
end function

function nrTaskMain() as Void
    'Assuming that parent node is com.newrelic.NRAgent
    m.nr = m.top.getParent()
    m.nr.callFunc("nrLog", "---- NRTASK MAIN ----")
    nrEventProcessor()
end function
