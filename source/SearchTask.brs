'Code for TestTask Task
function SearchTaskMain()
    while true
        _url = box("https://www.google.com/search?source=hp&q=" + m.top.searchString)
        urlReq = CreateObject("roUrlTransfer")
        urlReq.SetUrl(_url)
        urlReq.RetainBodyOnError(true)
        urlReq.EnablePeerVerification(false)
        urlReq.EnableHostVerification(false)
        
        resp = urlReq.GetToString()
        
        attr = {
            "origUrl": _url
        }
        nrSendCustomEvent("RokuSystem", "HTTP_REQUEST", attr)
        
        sleep(5000)
    end while
end function
