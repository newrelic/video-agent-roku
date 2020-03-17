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
    url = box("https://insights-collector.newrelic.com/v1/accounts/" + m.accountNumber + "/events")
    jsonString = FormatJson(attributes)

    rport = CreateObject("roMessagePort")
    urlReq = CreateObject("roUrlTransfer")

    urlReq.SetUrl(url)
    urlReq.RetainBodyOnError(true)
    urlReq.EnablePeerVerification(false)
    urlReq.EnableHostVerification(false)
    urlReq.AddHeader("Content-Type", "application/json")
    urlReq.AddHeader("X-Insert-Key", m.apikey)
    urlReq.SetMessagePort(rport)
    urlReq.AsyncPostFromString(jsonString)
    
    msg = wait(0, rport)
    if type(msg) = "roUrlEvent" then
        return msg.GetResponseCode()
    end if
    return 0
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
        end if
    end while
end function

function nrTaskMain() as Void
    'Assuming that parent node is com.newrelic.NRAgent
    m.nr = m.top.getParent()
    m.apiKey = m.top.apiKey
    m.accountNumber = m.top.accountNumber
    nrEventProcessor()
end function
