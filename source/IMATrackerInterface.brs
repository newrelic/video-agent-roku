'**********************************************************
' IMATrackerInterface.brs
' New Relic Google IMA Tracker Interface.
'
' Copyright 2021 New Relic Inc. All Rights Reserved.
'**********************************************************

' Build a New Relic Google IMA Tracker object.
'
' @param nr New Relic Agent object.
' @return Google IMA Tracker object.
function IMATracker(nr as Object) as Object
    tracker = CreateObject("roSGNode", "com.newrelic.trackers.IMATracker")
    tracker.setField("nr", nr)
    return tracker
end function

' Send Ad Break Start.
'
' @param tracker Google IMA Tracker object.
' @param adBreakInfo Ad Break Info object.
function nrSendIMAAdBreakStart(tracker as Object, adBreakInfo as Object) as Void
    tracker.callFunc("nrSendIMAAdBreakStart", adBreakInfo)
end function

' Send Ad Break End.
'
' @param tracker Google IMA Tracker object.
' @param adBreakInfo Ad Break Info object.
function nrSendIMAAdBreakEnd(tracker as Object, adBreakInfo as Object) as Void
    tracker.callFunc("nrSendIMAAdBreakEnd", adBreakInfo)
end function

' Send Ad Start.
'
' @param tracker Google IMA Tracker object.
' @param ad Ad info object.
function nrSendIMAAdStart(tracker as Object, ad as Object) as Void
    tracker.callFunc("nrSendIMAAdStart", ad)
end function

' Send Ad End.
'
' @param tracker Google IMA Tracker object.
' @param ad Ad info object.
function nrSendIMAAdEnd(tracker as Object, ad as Object) as Void
    tracker.callFunc("nrSendIMAAdEnd", ad)
end function

' Send Ad Quartile.
'
' @param tracker Google IMA Tracker object.
' @param ad Ad info object.
' @param quartile Quartile number.
function nrSendIMAAdQuartile(tracker as Object, ad as Object, quartile as Integer) as Void
    tracker.callFunc("nrSendIMAAdQuartile", ad, quartile)
end function
