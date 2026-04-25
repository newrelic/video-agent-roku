'**********************************************************
' MediaTailorTrackerInterface.brs
' New Relic AWS Elemental MediaTailor Tracker Interface.
'
' Factory and wrapper functions for the MediaTailor SSAI tracker.
' Include this file in any Scene component that needs MediaTailor
' ad tracking (add it to the <script> list in the scene's .xml).
'
' Copyright 2024 New Relic Inc. All Rights Reserved.
'**********************************************************

' Create and return a new MediaTailorTracker node wired to the NRAgent.
'
' @param nr  New Relic Agent node (returned by NewRelic()).
' @return    MediaTailorTracker node ready for use.
function MediaTailorTracker(nr as Object) as Object
    print "MediaTailorTrackerInterface: MediaTailorTracker"
    tracker = CreateObject("roSGNode", "com.newrelic.trackers.MediaTailorTracker")
    tracker.setField("nr", nr)
    return tracker
end function

' Forward a raw RAF event and its context to the tracker.
' Call this from the RAF tracking-callback closure in your MediaTailorTask.
'
' @param tracker  MediaTailorTracker node from MediaTailorTracker().
' @param evtType  RAF event type string (e.g. "PodStart", "Start", …).
' @param ctx      RAF context object for this event.
function nrTrackMediaTailorEvent(tracker as Object, evtType as String, ctx as Object) as Void
    tracker.callFunc("nrTrackMediaTailorEvent", evtType, ctx)
end function

' Inject ads_metadata sidecar key/value pairs into the tracker so they are
' appended to every subsequent AD_* event.  Call this after receiving the
' sidecar response from your MediaTailor ads_metadata URL, *before* ads play.
'
' @param tracker   MediaTailorTracker node from MediaTailorTracker().
' @param metadata  roAssociativeArray of key→value pairs from the sidecar.
function nrSetMediaTailorAdMetadata(tracker as Object, metadata as Object) as Void
    tracker.callFunc("nrSetMediaTailorAdMetadata", metadata)
end function
