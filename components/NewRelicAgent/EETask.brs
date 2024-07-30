'**********************************************************
' EETask.brs
' New Relic Agent background task for Express Events.
'
' Copyright 2023 New Relic Inc. All Rights Reserved. 
'**********************************************************

sub init()
    m.top.functionName = "nrTaskMain"
    m.loggingState = false
end sub

function nrPushEvent(event as Object) as Object
    jsonString = FormatJson(event)

    rport = CreateObject("roMessagePort")
    urlReq = CreateObject("roUrlTransfer")

    urlReq.SetUrl(m.eventApiUrl)
    urlReq.RetainBodyOnError(true)
    urlReq.EnablePeerVerification(false)
    urlReq.EnableHostVerification(false)
    urlReq.EnableEncodings(true)
    urlReq.AddHeader("Api-Key", m.apikey)
    urlReq.SetMessagePort(rport)
    urlReq.AsyncPostFromString(jsonString)
    
    'Use a short connection timeout (5 seconds) to unlock the task asap
    msg = wait(5000, rport)
    if type(msg) = "roUrlEvent" then
        return msg.GetResponseCode()
    else
        'Connection timeout, cancel transfer and return error code (0)
        nrLog("-- Express Event Task nrPushSamples: timeout, cancel request --")
        urlReq.AsyncCancel()
        return 0
    end if
end function

function isStatusErr(res) as boolean
    return res >= 400 or res = 0
end function

function nrTaskMain() as Void
    if m.nr = invalid
        'Assuming that parent node is com.newrelic.NRAgent
        m.nr = m.top.getParent()
        m.apiKey = m.top.apiKey
        m.loggingState = m.nr.callFunc("nrCheckLoggingState")
    end if

    attributes = m.top.attributes.getFields()
    'Remove garbage introduced by ContentNode
    attributes.Delete("id")
    attributes.Delete("focusedChild")
    attributes.Delete("focusable")
    attributes.Delete("change")

    res = nrPushEvent(attributes)
    if isStatusErr(res)
        nrLog("-- Express Event Push FAILED with code " + Str(res) + " --")
        if res = 429 or res = 408 or res = 503 or res = 0
            'Too many requests, request timeout, service temporary unavailable, or connection timeout
            nrLog("-- Express Event ERROR: unable to complete request or send data --")

            'TODO: Disable EE for T seconds.
        else if res = 413
            'Request too large
            nrLog("-- Express Event ERROR: request too large --")
        else if res = 403
            'Invalid key
            nrLog("-- Express Event ERROR: invalid key --")
        end if
    else
        nrLog("Express Event successfully sent")
    end if
end function

function onConfigUpdate() as Void
    m.eventApiUrl = m.top.eventApiUrl
end function

function nrLog(msg as Dynamic) as Void
    if m.loggingState = true then m.nr.callFunc("nrLog", msg)
end function