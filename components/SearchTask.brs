sub init()
    m.top.functionName = "searchTaskMain"


    ' Init HTTP Sender plugin
    m.plugin = nrPluginHttpSenderInit()

    'Define multiple domain substitutions
    nrPluginHttpSenderAddDomainSubstitution(m.plugin, "^www\.google\.com$", "Google COM")
    nrPluginHttpSenderAddDomainSubstitution(m.plugin, "^www\.google\.cat$", "Google CAT")
    nrPluginHttpSenderAddDomainSubstitution(m.plugin, "^www\.google\.us$", "Google US")
    nrPluginHttpSenderAddDomainSubstitution(m.plugin, "^google\.com$", "Google ERROR")
    nrPluginHttpSenderAddDomainSubstitution(m.plugin, "^.+\.googleapis\.com$", "Google APIs")
    nrPluginHttpSenderAddDomainSubstitution(m.plugin, "^.+\.akamaihd\.net$", "Akamai")
end sub

function nrRefUpdated()
    print "SearchTask - Updated NR object reference"
    m.nr = m.top.nr
end function

function searchTaskMain()
    print "SearchTaskMain function"
    m.port = CreateObject("roMessagePort")

    cnt = 0

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
        nrPluginHttpSenderRequest(m.plugin, urlReq)
        
        msg = wait(10000, m.port)
        if type(msg) = "roUrlEvent" then
            'Send HTTP_RESPONSE event
            nrPluginHttpSenderResponse(m.plugin, _url, msg)
        end if

        if cnt >= 5
            'Sync
            nrPluginHttpSenderSync(m.plugin, m.nr)
            cnt = 0
        end if

        cnt += 1

        Sleep(3000)
    end while
end function
