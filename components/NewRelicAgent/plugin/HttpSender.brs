'**********************************************************
' HTTP Sender Plugin
' Record HTTP_REQUEST and HTTP_RESPONSE events,
' allowing to manually set time references.
'
' Copyright 2023 New Relic Inc. All Rights Reserved. 
'**********************************************************

' Initialize plugin state.
function nrPluginHttpSenderInit()
    print "nrPluginHttpSenderInit"

    'Buffer of events
    m._nrPluginHttpSenderEventArray = []

    'HTTP Request/Response IDs
    m._nrRequestIdentifiers = CreateObject("roAssociativeArray")

    'Domain attribute matching patterns
    m._nrDomainPatterns = CreateObject("roAssociativeArray")
end function

' Add a matching pattern for the domain attribute and substitute it by another string.
function nrPluginHttpSenderAddDomainSubstitution(pattern as String, subs as String) as Void
    m._nrDomainPatterns.AddReplace(pattern, subs)
end function

' Delete a matching pattern created with nrAddDomainSubstitution
function nrPluginHttpSendeDelDomainSubstitution(pattern as String) as Void
    m._nrDomainPatterns.Delete(pattern)
end function

'TODO: sync function: send all data to NRAgent

' Send an HTTP_REQUEST event of type RokuSystem.
'
' @param urlReq URL request, roUrlTransfer object.
function nrPluginHttpSenderRequest(urlReq as Object) as Void
    print "nrPluginHttpSenderRequest", urlReq.GetUrl()

    if type(urlReq) = "roUrlTransfer"
        attr = {
            "origUrl": urlReq.GetUrl(),
            "transferIdentity": urlReq.GetIdentity(),
            "method": urlReq.GetRequest()
        }
        _nr_plugin_SendHttpRequest(attr)
    end if
end function

' Send an HTTP_RESPONSE event of type RokuSystem.
'
' @param _url Request URL.
' @param msg A message of type roUrlEvent.
function nrPluginHttpSenderResponse(_url as String, msg as Object) as Void
    print "nrPluginHttpSenderResponse", _url

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
        
        _nr_plugin_SendHttpResponse(attr)
    end if
end function

'----- Private Functions -----

function _nr_plugin_SendHttpRequest(attr as Object) as Void
    domain = _nr_plugin_ExtractDomainFromUrl(attr["origUrl"])
    attr["domain"] = domain
    transId = stri(attr["transferIdentity"])
    m._nrRequestIdentifiers[transId] = _nr_plugin_Timestamp()
    'Clean up old transfers
    toDeleteKeys = []
    for each item in m._nrRequestIdentifiers.Items()
        'More than 10 minutes without a response, delete the request ID
        if _nr_plugin_Timestamp() - item.value > 10*60*1000
            toDeleteKeys.Push(item.key)
        end if
    end for
    for each key in toDeleteKeys
        m._nrRequestIdentifiers.Delete(key)
    end for

    'TODO: send custom event
    'nrSendCustomEvent("RokuSystem", "HTTP_REQUEST", attr)
    print "TODO: SEND HTTP_REQUEST", attr
end function

function _nr_plugin_SendHttpResponse(attr as Object) as Void
    domain = _nr_plugin_ExtractDomainFromUrl(attr["origUrl"])
    attr["domain"] = domain
    transId = stri(attr["transferIdentity"])
    if m._nrRequestIdentifiers[transId] <> invalid
        deltaMs = _nr_plugin_Timestamp() - m._nrRequestIdentifiers[transId]
        attr["timeSinceHttpRequest"] = deltaMs
        m._nrRequestIdentifiers.Delete(transId)
    end if
    
    'TODO: send custom event
    'nrSendCustomEvent("RokuSystem", "HTTP_RESPONSE", attr)
    print "TODO: SEND HTTP_RESPONSE", attr
end function

function _nr_plugin_ExtractDomainFromUrl(url as String) as String
    'Extract domain from the URL
    r = CreateObject("roRegex", "\/\/|\/", "")
    arr = r.Split(url)
    if arr.Count() < 2 then return ""
    if arr[0] <> "http:" and arr[0] <> "https:" then return ""
    if arr[1] = "" then return ""
    domain = arr[1]

    ' Check all patterns
    for each item in m._nrDomainPatterns.Items()
        r = CreateObject("roRegex", item.key, "")
        if r.isMatch(domain)
            return r.Replace(domain, item.value)
        end if
    end for

    ' If nothing matches, it just returns the whole domain
    return domain
end function

function _nr_plugin_Timestamp() as LongInteger
    timestampObj = CreateObject("roDateTime")
    timestamp = timestampObj.asSeconds()
    nowMilliseconds = timestampObj.GetMilliseconds()

    timestampLong& = timestamp
    timestampMS& = timestampLong& * 1000 + nowMilliseconds

    return timestampMS&
end function