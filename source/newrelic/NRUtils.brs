'**********************************************************
' NRUtils.brs
' New Relic Agent Utility functions for Roku.
' Minimum requirements: FW 7.2
'
' Copyright 2019 New Relic Inc. All Rights Reserved. 
'**********************************************************

function nrInsertInsightsData(eventType as String, attributes as Object) as Object
    _url = box("https://insights-collector.newrelic.com/v1/accounts/" + m.global.nrAccountNumber + "/events")
    _apikey = m.global.nrInsightsApiKey
    attributes["eventType"] = eventType
    _jsonString = FormatJson(attributes)

    _urlReq = CreateObject("roUrlTransfer")

    _urlReq.SetUrl(_url)
    _urlReq.RetainBodyOnError(true)
    _urlReq.EnablePeerVerification(false)
    _urlReq.EnableHostVerification(false)
    _urlReq.AddHeader("Content-Type","application/json")
    _urlReq.AddHeader("X-Insert-Key",_apikey)

    _resp = _urlReq.PostFromString(_jsonString)
    
    print "------"
    print _jsonString
    'print "m.global = " m.global
    print "------"
    
    return _resp
end function

'Record an event to the list. Takes an roAssociativeArray as argument 
function nrRecordEvent(event as Object) as Void
    if m.global.nrEventArray.Count() < 500
        arr = m.global.nrEventArray
        arr.Push(event)
        m.global.nrEventArray = arr
        
        printVideoEventList()
    end if
end function

'Extracts the first event from the list. Returns an roAssociativeArray as argument
function nrExtractEvent() as Object
    arr = m.global.nrEventArray
    res = arr.Pop()
    m.global.nrEventArray = arr
    return res
end function

function nrCreateEvent(actionName as String) as Object
    ev = CreateObject("roAssociativeArray")
    ev["actionName"] = actionName
    timestamp& = CreateObject("roDateTime").asSeconds()
    ev["timestamp"] = timestamp& * 1000
    
    print "Create Event = " ev
    
    return ev
end function

function printVideoEventList() as Void
    print "------------- printVideoEventList ------------" 
    i = 0
    while i < m.global.nrEventArray.Count()
        print m.global.nrEventArray[i]
        i = i + 1
    end while
    print "----------------------------------------------"
end function
