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
    countTimer = CreateObject("roTimespan")
    countTimer.Mark()

    m_min = 999999
    m_max = 0
    m_sum = 0

    while true
        _url = box("https://www.google.com/search?source=hp&q=" + m.top.searchString)
        if Rnd(5) = 4
            ' Generates an error
            _url = box("https://www.google.com/shitrequest")
        end if
        urlReq = CreateObject("roUrlTransfer")
        urlReq.SetUrl(_url)
        urlReq.RetainBodyOnError(true)
        urlReq.EnablePeerVerification(false)
        urlReq.EnableHostVerification(false)
        urlReq.SetMessagePort(m.port)
        urlReq.AsyncGetToString()
        
        requestTimer = CreateObject("roTimespan")

        'Send HTTP_REQUEST action
        print "URL REQ OBJECT = ", urlReq
        nrSendHttpRequest(m.nr, urlReq)
        requestTimer.Mark()
        
        msg = wait(5000, m.port)
        if type(msg) = "roUrlEvent" then
            'Send HTTP_RESPONSE action
            nrSendHttpResponse(m.nr, _url, msg)
            nrSendLog(m.nr, "Google Search", "URL Request", { "url": _url, "counter": counter, "bodysize": Len(msg) })
            nrSendMetric(m.nr, "roku.http.response", requestTimer.TotalMilliseconds())

            ' Update max, min and sum
            if requestTimer.TotalMilliseconds() > m_max then m_max = requestTimer.TotalMilliseconds()
            if requestTimer.TotalMilliseconds() < m_min then m_min = requestTimer.TotalMilliseconds()
            m_sum = m_sum + requestTimer.TotalMilliseconds()
        end if
        
        sleep(2500)
        counter = counter + 1

        if countTimer.TotalMilliseconds() > 7500
            nrSendCountMetric(m.nr, "roku.http.request.count", counter, countTimer.TotalMilliseconds())
            nrSendSummaryMetric(m.nr, "roku.http.response.summary", countTimer.TotalMilliseconds(), counter, m_sum, m_min, m_max)
            m_min = 999999
            m_max = 0
            m_sum = 0
            counter = 0
            countTimer.Mark()
        end if
    end while
end function
