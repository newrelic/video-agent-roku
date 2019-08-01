'Code for TestTask Task
function SearchTaskMain()
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
        
        msg = wait(5000, m.port)
        if type(msg) = "roUrlEvent" then
            nrSendHttpEvent(_url, msg)
        end if
        
        sleep(5000)
    end while
end function
