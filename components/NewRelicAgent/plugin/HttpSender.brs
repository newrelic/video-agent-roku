'**********************************************************
' HTTP Sender Plugin
' Record HTTP_REQUEST and HTTP_RESPONSE events,
' allowing to manually set time references.
'
' Copyright 2023 New Relic Inc. All Rights Reserved. 
'**********************************************************

function nrPluginHttpSenderStart()
    print "TODO: nrPluginHttpSenderStart"
    'TODO: start stuff, vars, etc
end function

' Send an HTTP_REQUEST event of type RokuSystem.
'
' @param urlReq URL request, roUrlTransfer object.
function nrPluginHttpSenderRequest(urlReq as Object) as Void
    print "TODO: nrPluginHttpSenderRequest", urlReq.GetUrl()

    if type(urlReq) = "roUrlTransfer"
        attr = {
            "origUrl": urlReq.GetUrl(),
            "transferIdentity": urlReq.GetIdentity(),
            "method": urlReq.GetRequest()
        }
        'TODO: actual event recording
        'nr.callFunc("nrSendHttpRequest", attr)
    end if
end function

' Send an HTTP_RESPONSE event of type RokuSystem.
'
' @param _url Request URL.
' @param msg A message of type roUrlEvent.
function nrPluginHttpSenderResponse(_url as String, msg as Object) as Void
    print "TODO: nrPluginHttpSenderResponse", _url

    if type(msg) = "roUrlEvent"
        attr = {
            "origUrl": _url
        }
        
        attr.AddReplace("httpCode", msg.GetResponseCode())
        attr.AddReplace("httpResult", msg.GetFailureReason())
        attr.AddReplace("transferIdentity", msg.GetSourceIdentity())
        
        header = msg.GetResponseHeaders()
        
        for each key in header
            parts = key.Tokenize("-")
            finalKey = "http"
            finalValue = header[key]
            for each part in parts
                firstChar = Left(part, 1)
                firstChar = UCase(firstChar)
                restStr = Right(part, Len(part) - 1)
                restStr = LCase(restStr)
                finalKey = finalKey + firstChar + restStr
            end for
            attr.AddReplace(finalKey, finalValue)
        end for
        
        'TODO: actual event recording
        'nr.callFunc("nrSendHttpResponse", attr)
    end if
end function
