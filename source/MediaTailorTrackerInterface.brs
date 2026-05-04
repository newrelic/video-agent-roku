'**********************************************************
' MediaTailorTrackerInterface.brs
' New Relic AWS Elemental MediaTailor Tracker Interface.
'
' Public API for MediaTailor SSAI ad tracking.
' Include this file in any Task component that manages a RAFX_SSAI
' adapter (add it to the <script> list in the task's .xml).
'
' Copyright 2024 New Relic Inc. All Rights Reserved.
'**********************************************************

' One-call integration for customers who manage their own RAFX_SSAI adapter.
'
' Call this once after adIface.init() and NR will register its own listeners
' on the adapter directly — no manual event forwarding required.
' The tracker is stored as m.nrMTTracker in the calling task's scope so
' that the internal listener function can reach it.
'
' @param nr      New Relic Agent node (returned by NewRelic()).
' @param adIface RAFX_SSAI adapter object (from RAFX_SSAI({name:"awsemt"})).
function nrEnableMediaTailorTracking(nr as Object, adIface as Object) as Void
    m.nrMTTracker = MediaTailorTracker(nr)
    adIface.addEventListener(adIface.AdEvent.POD_START,      nrMTEventListener)
    adIface.addEventListener(adIface.AdEvent.IMPRESSION,     nrMTEventListener)
    adIface.addEventListener(adIface.AdEvent.FIRST_QUARTILE, nrMTEventListener)
    adIface.addEventListener(adIface.AdEvent.MIDPOINT,       nrMTEventListener)
    adIface.addEventListener(adIface.AdEvent.THIRD_QUARTILE, nrMTEventListener)
    adIface.addEventListener(adIface.AdEvent.COMPLETE,       nrMTEventListener)
    adIface.addEventListener(adIface.AdEvent.POD_END,        nrMTEventListener)
    adIface.addEventListener(adIface.AdEvent.ERROR,          nrMTEventListener)
end function

' Internal listener registered by nrEnableMediaTailorTracking.
' Runs in the calling task's scope so m.nrMTTracker is accessible.
function nrMTEventListener(adInfo as Object) as Void
    if adInfo = invalid or m.nrMTTracker = invalid then return
    evtType = ""
    if adInfo.event <> invalid then evtType = adInfo.event
    m.nrMTTracker.callFunc("nrTrackMediaTailorEvent", evtType, adInfo)
end function

' Create and return a new MediaTailorTracker node wired to the NRAgent.
' Used internally by nrEnableMediaTailorTracking and by the sample MediaTailorTask.
'
' @param nr  New Relic Agent node (returned by NewRelic()).
' @return    MediaTailorTracker node ready for use.
function MediaTailorTracker(nr as Object) as Object
    tracker = CreateObject("roSGNode", "com.newrelic.trackers.MediaTailorTracker")
    tracker.setField("nr", nr)
    return tracker
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

' Internal — used by the sample MediaTailorTask to forward events.
function nrTrackMediaTailorEvent(tracker as Object, evtType as String, ctx as Object) as Void
    tracker.callFunc("nrTrackMediaTailorEvent", evtType, ctx)
end function
