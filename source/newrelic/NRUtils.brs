'**********************************************************
' NRUtils.brs
' New Relic Agent Utility functions for Roku.
' Minimum requirements: FW 7.2
'
' Copyright 2019 New Relic Inc. All Rights Reserved. 
'**********************************************************

function nrInsertInsightsData(attributes as Object) as Object
    _url = box("https://insights-collector.newrelic.com/v1/accounts/" + m.global.nrAccountNumber + "/events")
    apikey = m.global.nrInsightsApiKey
    jsonString = FormatJson(attributes)

    urlReq = CreateObject("roUrlTransfer")

    urlReq.SetUrl(_url)
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
        ev = nrExtractEvent()
        if ev = invalid then exit while
        res = nrInsertInsightsData(ev)
        nrLog("-- nrEventProcessor: insert insights data --")
        if res <> 200
            'Failed, reinsert event and will retry later
            nrRecordEvent(ev)
        end if
    end while
end function

function nrProcessGroupedEvents() as Void
    'TODO: convert grouped events into events in the Event Array
end function

'Record an event to the list. Takes an roAssociativeArray as argument 
function nrRecordEvent(event as Object) as Void
    if m.global.nrEventArray.Count() < 500
        arr = m.global.nrEventArray
        arr.Push(event)
        m.global.nrEventArray = arr
        
        nrLog(["Record New Event = ", event])
    else
        nrLog("Events overflow, discard event")
    end if
end function

'Extracts the first event from the list. Returns an roAssociativeArray as argument
function nrExtractEvent() as Object
    arr = m.global.nrEventArray
    res = arr.Pop()
    m.global.nrEventArray = arr
    return res
end function

function nrLog(msg as Dynamic) as Void
    if m.global.nrLogsState = true
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

function nrActivateLogging(state as Boolean) as Void
    m.global.nrLogsState = state
end function
