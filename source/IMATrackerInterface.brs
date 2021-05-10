
function IMATracker(nr as Object) as Object
    tracker = CreateObject("roSGNode", "com.newrelic.trackers.IMATracker")
    tracker.setField("nr", nr)
    return tracker
end function

function nrSendIMAAdBreakStart(tracker as Object, adBreakInfo as Object) as Void
    tracker.callFunc("nrSendIMAAdBreakStart", adBreakInfo)
end function

function nrSendIMAAdBreakEnd(tracker as Object, adBreakInfo as Object) as Void
    tracker.callFunc("nrSendIMAAdBreakEnd", adBreakInfo)
end function

function nrSendIMAAdStart(tracker as Object, ad as Object) as Void
    tracker.callFunc("nrSendIMAAdStart", ad)
end function

function nrSendIMAAdEnd(tracker as Object, ad as Object) as Void
    tracker.callFunc("nrSendIMAAdEnd", ad)
end function

function nrSendIMAAdQuartile(tracker as Object, ad as Object, quartile as Integer) as Void
    tracker.callFunc("nrSendIMAAdQuartile", ad, quartile)
end function
