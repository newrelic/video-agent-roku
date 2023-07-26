sub init()
    m.top.functionName = "searchTaskMain"
    
    ' Init HTTP Sender plugin
    nrPluginHttpSenderInit()

    'Define multiple domain substitutions
    nrPluginHttpSenderAddDomainSubstitution("^www\.google\.com$", "Google COM")
    nrPluginHttpSenderAddDomainSubstitution("^www\.google\.cat$", "Google CAT")
    nrPluginHttpSenderAddDomainSubstitution("^www\.google\.us$", "Google US")
    nrPluginHttpSenderAddDomainSubstitution("^google\.com$", "Google ERROR")
    nrPluginHttpSenderAddDomainSubstitution("^.+\.googleapis\.com$", "Google APIs")
    nrPluginHttpSenderAddDomainSubstitution("^.+\.akamaihd\.net$", "Akamai")
end sub

function nrRefUpdated()
    print "SearchTask - Updated NR object reference"
    m.nr = m.top.nr
end function

function searchTaskMain()
    print "SearchTaskMain function"
    m.port = CreateObject("roMessagePort")

    while true
        dice = Rnd(4)
        if dice = 1
            _url = box("https://www.google.com/search?source=hp&q=" + m.top.searchString)
        else if dice = 2
            _url = box("https://www.google.cat/search?source=hp&q=" + m.top.searchString)
        else if dice = 3
            _url = box("https://www.google.us/search?source=hp&q=" + m.top.searchString)
        else if dice = 4
            _url = box("https://google.com/wrongrequest")
        end if
        urlReq = CreateObject("roUrlTransfer")
        urlReq.SetUrl(_url)
        urlReq.RetainBodyOnError(true)
        urlReq.EnablePeerVerification(false)
        urlReq.EnableHostVerification(false)
        urlReq.SetMessagePort(m.port)
        urlReq.AsyncGetToString()

        'Send HTTP_REQUEST event
        nrPluginHttpSenderRequest(urlReq)
        
        msg = wait(5000, m.port)
        if type(msg) = "roUrlEvent" then
            'Send HTTP_RESPONSE event
            nrPluginHttpSenderResponse(_url, msg)
        end if
    end while
end function
