# New Relic Roku – AWS Elemental MediaTailor SSAI Ad Tracking POC

## Overview

This document describes the proof-of-concept implementation that enables New Relic ad observability on **Roku** for streams delivered through **AWS Elemental MediaTailor** (Server-Side Ad Insertion). It covers the problem, how Roku ad detection works, what was built, and what New Relic events are produced.

If you are familiar with New Relic video tracking on VideoJS, iOS, or Android, the event model (`AD_BREAK_START`, `AD_START`, `AD_QUARTILE`, `AD_END`, etc.) is identical. The interesting part is *how* those events are detected on Roku — which is fundamentally different from client-side ad insertion.

---

## Background: What Makes Roku Different

### Roku's Programming Model

Roku apps are written in **BrightScript**, a proprietary scripting language. The UI framework is called **SceneGraph**. Unlike a browser or a mobile app, Roku has a strict threading model:

- The **UI thread** handles rendering and user input
- **Task nodes** are background threads for blocking operations (network calls, playback management)
- Threads communicate only via **observed fields** and **message ports** — there is no shared memory

This matters for ad tracking because the entire SSAI adapter lifecycle — session init, manifest URL resolution, ad event detection, playback — must run inside a background Task node.

### Server-Side Ad Insertion vs Client-Side

On VideoJS, iOS, and Android, ads are often inserted client-side (CSAI): the player fetches a VAST/VMAP response, pauses content, plays a separate ad stream, then resumes content. The player has direct knowledge of when an ad starts and ends.

**MediaTailor SSAI is different.** The ads are stitched *into the content stream on the server* before the video bytes ever reach the device. From the player's perspective, it receives a single continuous HLS stream containing both content and ads — it does not "know" an ad is playing based on a separate stream switch. Ad boundaries are signalled purely through:

1. **`EXT-X-DATERANGE` markers** embedded in the HLS manifest
2. A **tracking URL** that MediaTailor provides at session init, which is polled during playback to receive ad avail data (start times, durations, beacon URLs)

This means you cannot detect ads by observing a stream change or a VAST fetch. You need a framework that understands these markers.

---

## The Roku Ad Framework: RAFX_SSAI

Roku provides **RAFX_SSAI** — a library specifically designed for Server-Side Ad Insertion. It ships with a named adapter called `awsemt` (AWS Elemental MediaTailor) that knows how to:

1. **Initialise a MediaTailor VOD session** by POSTing to the `/v1/session/` endpoint and receiving back a manifest URL and tracking URL
2. **Poll the tracking URL** during playback to discover ad avail windows (which ads are at which timestamps)
3. **Build a time-to-event map** so that as the player position advances, the adapter fires callbacks at the right moment (`PodStart` when an ad break begins, `Impression`/`Start` when an individual ad begins, `FirstQuartile`/`Midpoint`/`ThirdQuartile`/`Complete` as the ad progresses, `PodComplete` when the break ends)
4. **Fire client-side tracking beacons** (a Roku certification requirement)

RAFX_SSAI exposes an `addEventListener(eventType, callback)` API. When the adapter detects an ad event from the time-to-event map, it calls the registered callback with an `adInfo` object containing the event type, ad metadata, ad pod metadata, and playback position.

---

## What Was Built

### New Files

| File | Purpose |
|------|---------|
| `components/MediaTailorTask.brs` | Background Task that owns the full SSAI adapter lifecycle: session init, manifest resolution, RAF event loop, ad event callbacks |
| `components/MediaTailorTask.xml` | SceneGraph component definition for the Task node; declares all input fields |
| `components/NewRelicAgent/trackers/MediaTailorTracker.brs` | SceneGraph component that receives raw RAFX_SSAI ad events, enriches them with MediaTailor-specific metadata, and forwards them to the NRAgent as `VideoAdAction` events |
| `components/NewRelicAgent/trackers/MediaTailorTracker.xml` | Component definition for the tracker node |
| `source/MediaTailorTrackerInterface.brs` | Public BrightScript API (factory + wrappers) for creating and interacting with the tracker from scene code |
| `source/rafxssai.brs` | The Roku RAFX_SSAI library (Roku-provided, copied into project so it can be referenced as a local script) |

### Modified Files

| File | Change |
|------|--------|
| `components/VideoScene.brs` | Added `setupMediaTailorVideo()` function — the sample integration entry point |
| `components/NewRelicAgent/NRAgent.brs` | Added explicit handling for `FirstQuartile`, `Midpoint`, `ThirdQuartile` events in `nrTrackRAF` so RAFX_SSAI's named events produce `AD_QUARTILE` actions |

---

## How Ad Detection Works — Step by Step

This is the core of the POC. The diagram below shows the complete flow from app start to a `VideoAdAction` event appearing in New Relic.

```
VideoScene (UI thread)
    │
    ├─ creates MediaTailorTracker node (wired to NRAgent)
    │
    └─ creates MediaTailorTask node, sets fields, sets control="RUN"
            │
            ▼
    MediaTailorTask (background thread)
            │
            ├─ 1. RAFX_SSAI({name:"awsemt"}).init()
            │      Initialises the AWS Elemental MediaTailor adapter
            │
            ├─ 2. addEventListener(POD_START|START|IMPRESSION|
            │                      FIRST_QUARTILE|MIDPOINT|THIRD_QUARTILE|
            │                      COMPLETE|POD_END|ERROR,  nrMTAdListener)
            │      Registers one callback for all ad event types
            │
            ├─ 3. adIface.requestStream({ type:"vod", url: sessionInitUrl, body:"{}" })
            │      POSTs to /v1/session/.../hls  →  MediaTailor returns JSON:
            │        { "manifestUrl": "/v1/master/.../hls?aws.sessionId=...",
            │          "trackingUrl": "/v1/tracking/..." }
            │
            ├─ 4. adIface.getStreamInfo()
            │      Reads manifestUrl and trackingUrl from the session response.
            │      manifestUrl is normalised: /hls? → /master.m3u8?
            │      trackingUrl is stored as sidecar metadata on the tracker.
            │
            ├─ 5. Video node.content.url = master.m3u8?aws.sessionId=...
            │      Video node.control = "play"
            │      Roku player fetches the stitched HLS manifest and begins buffering.
            │
            ├─ 6. adIface.enableAds({ player: { sgnode: videoNode, port: port } })
            │      Activates the adapter:
            │        • Observes "streamingSegment" on the video node
            │        • Calls stitchedAdsInit([]) on the Roku Ads Framework
            │
            └─ 7. Event loop: wait(1000, port)
                    │
                    ├─ Every 1-second tick → adIface.onMessage(invalid)
                    │    Adapter checks if it's time to poll the tracking URL.
                    │    On first poll: fetches /v1/tracking/... → receives ad avails
                    │    (list of ad breaks with start times, durations, beacon URLs).
                    │    Builds an internal time-to-event map:
                    │      second 0  → [POD_START, IMPRESSION]
                    │      second 5  → [FIRST_QUARTILE]
                    │      second 10 → [MIDPOINT]
                    │      second 15 → [THIRD_QUARTILE]
                    │      second 20 → [COMPLETE, POD_END]
                    │
                    ├─ "position" message → adIface.onMessage(msg)
                    │    Adapter checks current position against the time-to-event map.
                    │    When position crosses a key:
                    │      → fires nrMTAdListener(adInfo) via addEventListener callback
                    │
                    └─ "streamingSegment" message → adIface.onMessage(msg)
                         Segment sequence numbers refine ad break boundaries for VOD.
```

### The Callback: `nrMTAdListener`

When the adapter fires an ad event, `nrMTAdListener` is called on the Task thread:

```brightscript
function nrMTAdListener(adInfo as Object) as Void
    evtType = adInfo.event          ' e.g. "PodStart", "Impression", "FirstQuartile"
    m.nrTracker.callFunc("nrTrackMediaTailorEvent", evtType, adInfo)
end function
```

The `adInfo` object contains:
- `adInfo.event` — the event type string
- `adInfo.ad` — ad-level metadata (adId, duration, creativeId, tracking beacon URLs)
- `adInfo.adPod` — pod-level metadata (podId, renderSequence preroll/midroll)
- `adInfo.position` — playback position in seconds when the event fired

### The Tracker: `MediaTailorTracker`

The tracker receives the raw `adInfo`, enriches it, and produces New Relic events:

```
nrTrackMediaTailorEvent(evtType, adInfo)
    │
    ├─ nrMTExtractAdMetadata()
    │    Pulls ad/pod fields from adInfo into m.customAdMetadata:
    │      adId, adTitle, adSystem, adDurationMs, creativeId,
    │      adAdvertiser, adCampaignId, adLineItemId, adVastTagUri,
    │      adPodId, adPodIndex, adRenderSequence, adBreakDurationMs,
    │      adTrackingUrl, adPartner="mediatailor"
    │
    ├─ nrMTFlushCustomAdAttributes()
    │    Pushes accumulated metadata into NRAgent's custom attribute store
    │    so the imminent VideoAdAction event carries all of it.
    │
    ├─ nrTrackRAF(evtType, adInfo)   [on NRAgent]
    │    Maps RAFX_SSAI event names → New Relic VideoAdAction event types:
    │
    │      RAFX_SSAI event    →   New Relic action
    │      ─────────────────────────────────────────
    │      "PodStart"         →   AD_BREAK_START
    │      "Impression"       →   AD_REQUEST
    │      "Start" (synth.)   →   AD_START          ← synthesized (see below)
    │      "FirstQuartile"    →   AD_QUARTILE {adQuartile:1}
    │      "Midpoint"         →   AD_QUARTILE {adQuartile:2}
    │      "ThirdQuartile"    →   AD_QUARTILE {adQuartile:3}
    │      "Complete"         →   AD_END
    │      "PodComplete"      →   AD_BREAK_END
    │      "Error"            →   AD_ERROR
    │
    └─ nrMTClearAdLevelMetadata()   (after Complete/Close)
         Removes per-ad fields so they don't bleed into the next ad.
```

### One Quirk: Synthesised `AD_START`

The `awsemt` adapter maps both the MediaTailor `"start"` and `"impression"` tracking beacon types to a single `AdEvent.IMPRESSION` callback. It never fires `AdEvent.START` separately. This means without intervention, `AD_START` would never appear in New Relic.

The tracker works around this by **synthesising** `AD_START` immediately after `AD_REQUEST`:

```brightscript
' awsemt never fires "Start" separately — synthesize AD_START after AD_REQUEST
if evtType = "Impression"
    m.top.nr.callFunc("nrTrackRAF", "Start", ctx)
end if
```

This ensures the standard `AD_REQUEST → AD_START → AD_QUARTILE → AD_END` sequence is preserved and matches what iOS/Android/VideoJS trackers produce.

---

## New Relic Events Produced

Every event below is a `VideoAdAction` in New Relic Insights/NRQL with `actionName` as shown.

### Per Ad Break

| actionName | When |
|------------|------|
| `AD_BREAK_START` | Ad break begins (PodStart from adapter) |
| `AD_BREAK_END` | Ad break ends (PodComplete from adapter) |

### Per Individual Ad

| actionName | When | Key attributes |
|------------|------|----------------|
| `AD_REQUEST` | Ad impression detected | `adId`, `adTitle`, `adDurationMs` |
| `AD_START` | Ad video begins (synthesised) | `adId`, `adTitle`, `adSystem`, `creativeId` |
| `AD_QUARTILE` | 25 / 50 / 75% of ad played | `adQuartile: 1/2/3` |
| `AD_END` | Ad completes | `adId`, `timeSinceAdStarted` |
| `AD_SKIP` | Ad skipped (Close event) | — |
| `AD_ERROR` | Adapter reported an error | `adErrorType`, `errorCode`, `errorMessage` |

### Custom Attributes on Every AD_* Event

These are injected by `MediaTailorTracker` and appear on all ad events:

| Attribute | Source |
|-----------|--------|
| `adPartner` | Always `"mediatailor"` — identifies the ad system |
| `adTrackingUrl` | The MediaTailor tracking endpoint for this session |
| `adRenderSequence` | `"preroll"` or `"midroll"` |
| `adBreakDurationMs` | Total duration of the ad break in milliseconds |
| `adPodId` | MediaTailor avail ID for the pod |
| `adId` | Individual ad ID from the SSAI context |
| `adTitle` | Ad title (if provided by MediaTailor) |
| `adSystem` | Ad serving system name |
| `adDurationMs` | Duration of the individual ad in milliseconds |
| `creativeId` | Creative ID |
| `adAdvertiser` | Advertiser name |
| `adCampaignId` | Campaign ID |
| `adLineItemId` | Line item ID |

---

## Sample Integration (Minimal)

This is all that is needed in a Roku scene to get ad tracking working:

```brightscript
' 1. Init New Relic (done once at app start in Main.brs)
m.nr = NewRelic("YOUR_ACCOUNT_ID", "YOUR_NR_API_KEY", "MyApp")

' 2. In the scene, create tracker + task
m.mediaTailorTracker = MediaTailorTracker(m.nr)

m.mediaTailorTask = createObject("roSGNode", "MediaTailorTask")
m.mediaTailorTask.setField("videoNode",  m.video)
m.mediaTailorTask.setField("nr",         m.nr)
m.mediaTailorTask.setField("tracker",    m.mediaTailorTracker)
m.mediaTailorTask.setField("streamUrl",  "https://<account>.mediatailor.<region>.amazonaws.com/v1/session/<hash>/<config>/hls")
m.mediaTailorTask.setField("streamType", "VOD")   ' or "LIVE"
m.mediaTailorTask.control = "RUN"
```

The XML component must include the required scripts:

```xml
<component name="MediaTailorTask" extends="Task">
    <script type="text/brightscript" uri="pkg:/source/rafxssai.brs"/>
    <script type="text/brightscript" uri="pkg:/source/MediaTailorTrackerInterface.brs"/>
    <script type="text/brightscript" uri="pkg:/components/MediaTailorTask.brs"/>
</component>
```

---

## NRQL Queries

```sql
-- All ad events from MediaTailor
SELECT * FROM VideoAdAction
WHERE adPartner = 'mediatailor'
SINCE 1 hour ago

-- Ad break count and average duration
SELECT count(*) AS breaks, average(adBreakDurationMs)/1000 AS avgBreakSec
FROM VideoAdAction
WHERE actionName = 'AD_BREAK_START' AND adPartner = 'mediatailor'
SINCE 1 day ago

-- Ad completion rate
SELECT
  filter(count(*), WHERE actionName = 'AD_START') AS started,
  filter(count(*), WHERE actionName = 'AD_END')   AS completed
FROM VideoAdAction
WHERE adPartner = 'mediatailor'
SINCE 1 day ago

-- Quartile funnel per campaign
SELECT count(*) FROM VideoAdAction
WHERE adPartner = 'mediatailor'
FACET actionName, adCampaignId
SINCE 1 day ago
```

---

## Known Limitations / Next Steps

| Item | Detail |
|------|--------|
| **`AD_START` is synthesised** | The awsemt adapter merges `"start"` and `"impression"` into a single callback. `AD_START` is synthesised immediately after `AD_REQUEST` so they always fire together, which is slightly less precise than a true playback-start detection. |
| **VOD tracking URL polling** | The adapter polls the MediaTailor tracking URL on an ~11-second interval. Ad events fire when the position crosses the pre-built time map, not in real-time from a live beacon. For most analytics this is sufficient. |
| **Origin availability** | The stitched manifest URL (`/v1/master/.../master.m3u8?aws.sessionId=...`) depends on the origin content server being reachable from MediaTailor. If the origin is down, MediaTailor returns HTTP 504 and playback fails (not a Roku or NR agent issue). |
| **LIVE streams** | The `MediaTailorTask` supports `streamType="LIVE"` but was not fully tested in this POC. For LIVE, no session init POST is needed — the streamUrl is used directly as the manifest. |
| **Ad metadata richness** | Fields like `adTitle`, `adAdvertiser`, `adCampaignId` depend on what the MediaTailor configuration surfaces in its tracking response. Sparse ad server setups may leave these empty. |
