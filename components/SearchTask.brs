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
    while true
        _url = box("https://www.google.com/search?source=hp&q=" + m.top.searchString)
        urlReq = CreateObject("roUrlTransfer")
        urlReq.SetUrl(_url)
        urlReq.RetainBodyOnError(true)
        urlReq.EnablePeerVerification(false)
        urlReq.EnableHostVerification(false)
        urlReq.SetMessagePort(m.port)
        urlReq.AsyncGetToString()
        
        nrSendHttpRequest(m.nr, urlReq)
        
        msg = wait(5000, m.port)
        if type(msg) = "roUrlEvent" then
            nrSendHttpResponse(m.nr, _url, msg)
        end if
        
        sleep(5000)
    end while
end function
