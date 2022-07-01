sub init()
    m.top.functionName = "searchTaskMain"
end sub

function nrRefUpdated()
    print "SearchTask - Updated NR object reference"
    m.nr = m.top.nr
end function

function searchTaskMain()
    print "SearchTaskMain function"
    m.port = CreateObject("roMessagePort")
    counter = 0
    while true
        _url = box("https://www.google.com/search?source=hp&q=" + m.top.searchString)
        urlReq = CreateObject("roUrlTransfer")
        urlReq.SetUrl(_url)
        urlReq.RetainBodyOnError(true)
        urlReq.EnablePeerVerification(false)
        urlReq.EnableHostVerification(false)
        urlReq.SetMessagePort(m.port)
        urlReq.AsyncGetToString()
        
        requestTimer = CreateObject("roTimespan")

        'Send HTTP_REQUEST action
        nrSendHttpRequest(m.nr, urlReq)
        requestTimer.Mark()
        
        msg = wait(5000, m.port)
        if type(msg) = "roUrlEvent" then
            'Send HTTP_RESPONSE action
            'nrSendHttpResponse(m.nr, _url, msg)
            'nrSendLog(m.nr, "Google Search", "URL Request", { "url": _url, "counter": counter, "bodysize": Len(msg) })
            nrSendMetric(m.nr, "roku.http.response", requestTimer.TotalMilliseconds())
        end if
        
        sleep(2500)
        counter = counter + 1
    end while
end function
