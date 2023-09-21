' Create HTTP Sender plugin.
'
' @return Plugin object.
function nrPluginHttpSenderInit() as Object
    plugin = CreateObject("roSGNode", "com.newrelic.plugin.HttpSender")
    return plugin
end function

' Add a matching pattern for the domain attribute and substitute it by another string.
'
' @param plugin HTTP Sende plugin.
' @param pattern: Regex pattern.
' @param subs: Substitution string.
function nrPluginHttpSenderAddDomainSubstitution(plugin as Object, pattern as String, subs as String) as Void
    plugin.callFunc("nrPluginHttpSenderAddDomainSubstitution", pattern, subs)
end function

' Delete a matching pattern created with nrAddDomainSubstitution
'
' @param plugin HTTP Sende plugin.
' @param pattern: Regex pattern.
function nrPluginHttpSenderDelDomainSubstitution(plugin as Object, pattern as String) as Void
    plugin.callFunc("nrPluginHttpSenderDelDomainSubstitution", pattern)
end function

' Send list of events to NRAgent.
'
' @param plugin HTTP Sende plugin.
' @param nr New Relic Agent object.
function nrPluginHttpSenderSync(plugin as Object, nr as Object) as Void
    plugin.callFunc("nrPluginHttpSenderSync", nr)
end function

' Send an HTTP_REQUEST event of type RokuSystem.
'
' @param plugin HTTP Sende plugin.
' @param urlReq URL request, roUrlTransfer object.
function nrPluginHttpSenderRequest(plugin as Object, urlReq as Object) as Void
    print "nrPluginHttpSenderRequest", urlReq.GetUrl()

    if type(urlReq) = "roUrlTransfer"
        attr = {
            "origUrl": urlReq.GetUrl(),
            "transferIdentity": urlReq.GetIdentity(),
            "method": urlReq.GetRequest()
        }
        plugin.callFunc("_nr_plugin_SendHttpRequest", attr)
    end if
end function

' Send an HTTP_RESPONSE event of type RokuSystem.
'
' @param plugin HTTP Sende plugin.
' @param _url Request URL.
' @param msg A message of type roUrlEvent.
function nrPluginHttpSenderResponse(plugin as Object, _url as String, msg as Object) as Void
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
        
        plugin.callFunc("_nr_plugin_SendHttpResponse", attr)
    end if
end function