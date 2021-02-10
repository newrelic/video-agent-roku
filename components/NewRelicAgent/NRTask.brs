'**********************************************************
' NRTask.brs
' New Relic Agent background task.
'
' Copyright 2020 New Relic Inc. All Rights Reserved. 
'**********************************************************

sub init()
    m.top.functionName = "nrTaskMain"
end sub

function nrInsertInsightsEvents(events as Object) as Object
    url = box("https://insights-collector.newrelic.com/v1/accounts/" + m.accountNumber + "/events")
    jsonString = FormatJson(events)
    
    print "EVENTS JSON STRING = ", jsonString

    rport = CreateObject("roMessagePort")
    urlReq = CreateObject("roUrlTransfer")

    urlReq.SetUrl(url)
    urlReq.RetainBodyOnError(true)
    urlReq.EnablePeerVerification(false)
    urlReq.EnableHostVerification(false)
    urlReq.EnableEncodings(true)
    urlReq.AddHeader("X-Insert-Key", m.apikey)
    urlReq.SetMessagePort(rport)
    urlReq.AsyncPostFromString(jsonString)
    
    msg = wait(0, rport)
    if type(msg) = "roUrlEvent" then
        return msg.GetResponseCode()
    else
        urlReq.AsyncCancel()
        return -1
    end if
end function

function nrEventProcessor() as Void
    if m.nr <> invalid
        events = m.nr.callFunc("nrExtractAllEvents")
        if events.Count() > 0
            res = nrInsertInsightsEvents(events)
            
            print "RESPONSE CODE = ", res
            
            if res <> 200
                m.nr.callFunc("nrLog", "-- nrEventProcessor: FAILED, retry later --")
                m.nr.callFunc("nrGetBackEvents", events)
            end if
        end if
    end if
end function

function nrTaskMain() as Void
    'Assuming that parent node is com.newrelic.NRAgent
    if m.nr = invalid
        m.nr = m.top.getParent()
        m.apiKey = m.top.apiKey
        m.accountNumber = m.top.accountNumber
    end if
    nrEventProcessor()
end function
