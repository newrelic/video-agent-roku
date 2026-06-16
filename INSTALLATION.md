# New Relic Roku Video Agent — Installation Guide

## Requirements

- Roku firmware **8.1 or above**
- New Relic account — credentials are provided during the New Relic onboarding flow

---

## 1. Add the Agent Files

Copy the following into your Roku project:

```
components/NewRelicAgent/      ← agent SceneGraph component
source/NewRelicAgent.brs       ← public API
```

---

## 2. Initialize the Agent

In your `Main.brs`, create the agent before anything else. All credentials below come from the New Relic onboarding flow:

```brightscript
m.nr = NewRelic(
    "<ACCOUNT_ID>",     ' [required] New Relic account number
    "<API_KEY>",        ' [required] license key
    "<APP_NAME>",       ' [required] app name shown in NR UI
    "<APP_TOKEN>",      ' [required] mobile app token — used to connect to the collector and send video events
    "<REGION>",         ' [required] "US" or "EU"
    false               ' [optional] enable agent logs, default false
)
```

> **Note:** `APP_TOKEN` is required. The agent uses it to authenticate with the New Relic collector and obtain the data token that all video events are sent with. Without it, no events will be delivered.

Send the app-started lifecycle event immediately after init:

```brightscript
nrAppStarted(m.nr, aa)   ' aa = the args object passed to RunUserInterface
```

Pass the agent to your scene so components can use it:

```brightscript
scene.setField("nr", m.nr)
```

---

## 3. Video Tracking

Attach the agent to your `Video` node to automatically capture playback lifecycle events (`CONTENT_REQUEST`, `CONTENT_START`, `CONTENT_PAUSE`, `CONTENT_RESUME`, `CONTENT_END`, `CONTENT_ERROR`, `CONTENT_HEARTBEAT`).

**In your scene (e.g. `VideoScene.brs`):**

```brightscript
' Receive the nr reference from the scene field
function nrRefUpdated()
    m.nr = m.top.nr
    nrSceneLoaded(m.nr, "MyVideoScene")   ' sends SCENE_LOADED event

    m.video = m.top.findNode("myVideo")
    m.video.content = videoContent
    m.video.control = "play"

    NewRelicVideoStart(m.nr, m.video)     ' begin tracking
end function
```

Stop tracking when playback ends or the user exits:

```brightscript
NewRelicVideoStop(m.nr)
```

Events are sent as **`VideoAction`** type in New Relic.

---

## 4. System Tracking

System tracking captures app lifecycle and network events as **`ConnectedDeviceSystem`** type.

### 4.1 Lifecycle Events

```brightscript
nrAppStarted(m.nr, aa)                              ' APP_STARTED
nrSceneLoaded(m.nr, "MyVideoScene")                 ' SCENE_LOADED
nrSendSystemEvent(m.nr, "ConnectedDeviceSystem", "MY_ACTION")  ' custom
```

### 4.2 HTTP Network Events

`NewRelicSystemStart` hooks into Roku's `roSystemLog` to automatically capture HTTP activity (`http.connect`, `http.complete`, `http.error`, `bandwidth.minute`).

**In `Main.brs`, after initializing the agent:**

```brightscript
' Start system log on the same message port used by the main loop
m.syslog = NewRelicSystemStart(m.port)

' Enable HTTP_CONNECT / HTTP_COMPLETE events (disabled by default since v3.0.0)
nrEnableHttpEvents(m.nr)
```

**In the main message loop, pass every message through the agent first:**

```brightscript
while true
    msg = wait(0, m.port)

    if nrProcessMessage(m.nr, msg) = false
        ' not a system log message — handle your own events here
        if type(msg) = "roSGNodeEvent"
            ' ...
        end if
    end if
end while
```

`nrProcessMessage` returns `true` when it consumes a `roSystemLogEvent`; your code only sees the messages that aren't NR's.

#### Manual HTTP instrumentation (roUrlTransfer)

If you issue HTTP requests manually and want them tracked:

```brightscript
urlReq = CreateObject("roUrlTransfer")
urlReq.SetUrl("https://api.example.com/data")
nrSendHttpRequest(m.nr, urlReq)        ' before AsyncGetToString / AsyncPostFromString

' In your message port handler, after receiving the roUrlEvent:
nrSendHttpResponse(m.nr, urlReq.GetUrl(), msg)
```

---

## 5. Ad Tracking

Three ad integration patterns are supported. All ad events are sent as **`VideoAdAction`** type.

### 5.1 Roku Advertising Framework (RAF)

Use `nrTrackRAF` as the RAF callback. Pass it directly to RAF's `setTrackingCallback`:

```brightscript
adIface = Roku_Ads()
adIface.setTrackingCallback(nrTrackRAF, m.nr)
```

Ad events tracked: `AD_BREAK_START`, `AD_START`, `AD_QUARTILE`, `AD_END`, `AD_BREAK_END`, `AD_ERROR`.

### 5.2 Google IMA

Use the bundled `IMATracker` component. Create an IMA SDK task and pass the tracker:

```brightscript
' In your scene
m.sdkTask = CreateObject("roSGNode", "imasdk")
m.sdkTask.setField("tracker", IMATracker(m.nr))
m.sdkTask.streamData = { title: "VOD stream", contentSourceId: "...", videoId: "...", apiKey: "", type: "vod" }
m.sdkTask.video = m.video
m.sdkTask.control = "RUN"
```

The `IMATracker` automatically fires `AD_BREAK_START`, `AD_BREAK_END`, `AD_START`, `AD_END`, `AD_QUARTILE`, and `AD_ERROR` events as `VideoAdAction`.

### 5.3 AWS Elemental MediaTailor SSAI

Use the bundled `MediaTailorTask` component. The tracker **must** be created in the scene thread and passed as a field:

```brightscript
' In your scene (scene thread)
m.mediaTailorTask = CreateObject("roSGNode", "MediaTailorTask")
m.mediaTailorTask.setField("videoNode",    m.video)
m.mediaTailorTask.setField("nr",           m.nr)
m.mediaTailorTask.setField("tracker",      MediaTailorTracker(m.nr))   ' scene thread only
m.mediaTailorTask.setField("streamUrl",    "https://<account>.mediatailor.<region>.amazonaws.com/v1/session/<hash>/<config>/hls")
m.mediaTailorTask.setField("streamType",   "VOD")
m.mediaTailorTask.setField("streamFormat", "hls")
m.mediaTailorTask.control = "RUN"
```

Inside the task, `nrEnableMediaTailorTracking(m.top.nr, adIface)` wires up all RAFX_SSAI listeners automatically. You can inject sidecar metadata that is appended to every subsequent ad event:

```brightscript
nrSetMediaTailorAdMetadata(tracker, { campaignId: "summer2026", placement: "pre-roll" })
```

Ad events tracked: `AD_BREAK_START`, `AD_REQUEST`, `AD_START`, `AD_QUARTILE`, `AD_END`, `AD_BREAK_END`, `AD_ERROR`.

---

## 6. Quality of Experience (QoE) Tracking

QoE tracking is **enabled by default** (since v4.2.1). It emits a `QOE_AGGREGATE` event on each harvest interval containing:

| KPI | Description |
|-----|-------------|
| `averageBitrate` | Average rendition bitrate (bps) |
| `peakBitrate` | Highest rendition bitrate seen |
| `startupTime` | Time from request to first frame (ms) |
| `rebufferingRatio` | Rebuffer time / total play time |
| `totalRebufferingTime` | Cumulative stall time (ms) |
| `totalPauseTime` | Cumulative user-initiated pause time (ms) |
| `avgDownloadRate` | Average network download bitrate (bps) |
| `minDownloadRate` | Minimum network download bitrate (bps) |
| `maxDownloadRate` | Maximum network download bitrate (bps) |
| `totalSwitchUps` | Count of rendition upward switches |
| `totalSwitchDowns` | Count of rendition downward switches |
| `totalTimeSwitchedDown` | Time spent below peak rendition (ms) |
| `totalRenditions` | Distinct rendition bitrates selected |
| `qoeAggregateVersion` | Schema version (`1.1.0`) |

**Control QoE at runtime:**

```brightscript
' Disable QoE (if you want to opt out)
' QoE is ON by default — no call needed to enable it

' Set the harvest interval multiplier (default 2 → emits every 2× harvest intervals)
nrSetQoeAggregateIntervalMultiplier(m.nr, 2)
```

---

## 7. Custom Attributes & Events

```brightscript
' Single attribute on all events
nrSetCustomAttribute(m.nr, "subscriptionTier", "premium")

' Single attribute scoped to one action type
nrSetCustomAttribute(m.nr, "pauseCount", m.pauseCounter, "CONTENT_PAUSE")

' Multiple attributes at once
nrSetCustomAttributeList(m.nr, { key0: "val0", key1: "val1" }, "CONTENT_HEARTBEAT")

' Custom video event (VideoAction)
nrSendVideoEvent(m.nr, "MY_CUSTOM_ACTION")

' Custom ad event (VideoAdAction)
nrSendVideoAdEvent(m.nr, "AD_SKIP", { skipPosition: m.video.position })

' Fully custom event (VideoCustomAction)
nrSendCustomEvent(m.nr, "USER_RATING", { rating: 5 })
```

---

## 8. Harvest & Configuration

```brightscript
' Harvest interval in seconds (min 60, default 60)
nrSetHarvestTime(m.nr, 60)

' Per-type harvest intervals
nrSetHarvestTimeEvents(m.nr, 60)
nrSetHarvestTimeLogs(m.nr, 60)
nrSetHarvestTimeMetrics(m.nr, 60)

' Force an immediate harvest
nrForceHarvest(m.nr)

' Domain substitution (replaces raw hostnames in events)
nrAddDomainSubstitution(m.nr, "^.+\.cdn\.example\.com$", "Example CDN")

' Data obfuscation (applied before buffering)
nrSetObfuscationRules(m.nr, [
    { regex: "token=[^&]+", replacement: "token=REDACTED" }
])

' EU region — pass "EU" to NewRelic() or update at runtime
nrUpdateConfig(m.nr, { proxyUrl: "https://proxy.internal:8080" })
```

---

## Quick-Start Checklist

- [ ] Copy `components/NewRelicAgent/` and `source/NewRelicAgent.brs` into your project
- [ ] Call `NewRelic(...)` at the top of `Main.brs`
- [ ] Call `nrAppStarted(m.nr, aa)`
- [ ] Call `NewRelicSystemStart(m.port)` and add `nrProcessMessage` to your message loop
- [ ] Call `nrEnableHttpEvents(m.nr)` if you want HTTP tracking
- [ ] Pass `m.nr` to your scene via `scene.setField("nr", m.nr)`
- [ ] Call `NewRelicVideoStart(m.nr, m.video)` when the video node is ready
- [ ] Choose your ad integration: RAF → `nrTrackRAF`, IMA → `IMATracker`, MediaTailor → `MediaTailorTask`
