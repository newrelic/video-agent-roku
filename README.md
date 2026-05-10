[![Community Project header](https://github.com/newrelic/opensource-website/raw/master/src/images/categories/Community_Project.png)](https://opensource.newrelic.com/oss-category/#community-project)

# New Relic Roku Agent

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

The New Relic Roku Agent provides comprehensive video and system analytics for Roku applications. Track video playback events, monitor system performance, capture ad interactions, log errors, and gain deep insights into user engagement and streaming quality on Roku devices.

## Features

- 🎯 **Automatic Video Event Detection** — Captures Roku player events automatically without manual instrumentation
- 📊 **Comprehensive Bitrate Tracking** — Multiple bitrate metrics for complete quality analysis
- 📈 **QoE Metrics** — Quality of Experience aggregation for startup time, buffering, and playback quality
- 🎨 **Event Segregation** — Organized event types: `VideoAction`, `VideoAdAction`, `VideoErrorAction`, `VideoCustomAction`, `ConnectedDeviceSystem`
- 📡 **System Monitoring** — HTTP requests, bandwidth, device info, and app lifecycle events
- 🎬 **Ad Tracking** — Support for both Roku Advertising Framework (RAF) and Google IMA
- 📝 **Logs & Metrics API** — Send custom logs, gauge metrics, count metrics, and summary metrics
- 🔧 **Domain Substitution** — Regex-based URL domain rewriting for cleaner analytics
- ⚡ **Configurable Harvest** — Separate harvest timing for events, logs, and metrics

## Table of Contents

- [Installation](#installation)
- [Prerequisites](#prerequisites)
- [Usage](#usage)
- [Best Practices](#best-practices)
- [API Reference](#api-reference)
  - [Initialization](#initialization)
  - [System Tracking](#system-tracking)
  - [Video Tracking](#video-tracking)
  - [Custom Attributes](#custom-attributes)
  - [Custom Events](#custom-events)
  - [HTTP Events](#http-events)
  - [Harvest Control](#harvest-control)
  - [QoE Tracking](#qoe-tracking)
  - [Logs](#logs)
  - [Metrics](#metrics)
  - [Domain Substitution](#domain-substitution)
  - [Configuration](#configuration)
  - [User Identity](#user-identity)
- [Ad Tracking](#ad-tracking)
  - [RAF Usage](#raf-usage)
  - [Google IMA Usage](#google-ima-usage)
  - [AWS Elemental MediaTailor SSAI](#aws-elemental-mediatailor-ssai)
- [Bitrate Metrics](#bitrate-metrics)
- [Data Model](#data-model)
- [Testing](#testing)
- [Debugging](#debugging)
- [Pricing](#pricing)
- [Support](#support)
- [Contribute](#contribute)
- [License](#license)

## Installation

Copy the following files into your Roku project:

```
source/
    NewRelicAgent.brs
    IMATrackerInterface.brs               (only if using Google IMA ads)
    MediaTailorTrackerInterface.brs       (only if using MediaTailor SSAI)
components/
    NewRelicAgent/
        NRAgent.brs
        NRAgent.xml
        NRTask.brs
        NRTask.xml
        trackers/
            IMATracker.brs                (only if using Google IMA ads)
            IMATracker.xml                (only if using Google IMA ads)
            MediaTailorTracker.brs        (only if using MediaTailor SSAI)
            MediaTailorTracker.xml        (only if using MediaTailor SSAI)
```

Include the agent interface script in any component XML that needs access to the agent:

```xml
<script type="text/brightscript" uri="pkg:/source/NewRelicAgent.brs"/>
```

## Prerequisites

Before using the agent, ensure you have:

- **New Relic Account** — Active New Relic account with valid credentials (`ACCOUNT_ID`, `API_KEY`, `APP_TOKEN`)
- **Roku Device** — Firmware 8.1 or higher
- **Roku Development Environment** — Ability to side-load channels for development

## Usage

### Getting Your Configuration

Before initializing the agent, obtain your New Relic configuration:

1. Log in to [one.newrelic.com](https://one.newrelic.com)
2. Navigate to **Integrations & Agents** → **Streaming Video & Ads** → **Roku**
3. Complete the onboarding flow to get your `ACCOUNT_ID`, `API_KEY`, `APP_NAME`, and `APP_TOKEN`

### Basic Setup

Integration requires three steps: initialize the agent, start system and video tracking, and process system messages in your main loop.

**Main.brs**

```brightscript
sub Main(aa as Object)
    screen = CreateObject("roSGScreen")
    m.port = CreateObject("roMessagePort")
    screen.setMessagePort(m.port)

    scene = screen.CreateScene("VideoScene")
    screen.show()

    ' Initialize the New Relic Agent
    m.nr = NewRelic("ACCOUNT_ID", "API_KEY", "APP_NAME", "APP_TOKEN")

    ' Send APP_STARTED event
    nrAppStarted(m.nr, aa)

    ' Pass agent to scene
    scene.setField("nr", m.nr)

    ' Start system tracking
    m.syslog = NewRelicSystemStart(m.port)

    ' Main event loop — must call nrProcessMessage for system events
    while (true)
        msg = wait(0, m.port)
        if nrProcessMessage(m.nr, msg) = false
            ' Handle your own messages here
            if type(msg) = "roPosterScreenEvent"
                if msg.isScreenClosed()
                    exit while
                end if
            end if
        end if
    end while
end sub
```

**VideoScene.xml**

```xml
<?xml version="1.0" encoding="utf-8" ?>
<component name="VideoScene" extends="Scene">
    <interface>
        <field id="nr" type="node" onChange="nrRefUpdated" />
    </interface>

    <children>
        <Video id="myVideo" translation="[0,0]" />
    </children>

    <script type="text/brightscript" uri="pkg:/source/NewRelicAgent.brs"/>
    <script type="text/brightscript" uri="pkg:/components/VideoScene.brs"/>
</component>
```

**VideoScene.brs**

```brightscript
sub init()
    m.top.setFocus(true)
    setupVideoPlayer()
end sub

function nrRefUpdated()
    m.nr = m.top.nr

    ' Start video tracking
    NewRelicVideoStart(m.nr, m.video)
end function

function setupVideoPlayer()
    videoContent = createObject("RoSGNode", "ContentNode")
    videoContent.url = "https://example.com/stream.m3u8"
    videoContent.title = "My Video"

    m.video = m.top.findNode("myVideo")
    m.video.content = videoContent
    m.video.control = "play"
end function
```

## Best Practices

### 1. Setting `contentTitle`

The `contentTitle` attribute is populated from your video content metadata. For best results, always set the `title` field on your `ContentNode`:

```brightscript
videoContent = createObject("RoSGNode", "ContentNode")
videoContent.url = "https://example.com/stream.m3u8"
videoContent.title = "My Video Title"    ' This becomes contentTitle
m.video.content = videoContent
```

### 2. Setting `userId`

Set a user identifier to track video analytics per user:

```brightscript
' Set userId after agent initialization
nrSetUserId(m.nr, "user-12345")
```

### 3. Adding Custom Attributes for Your Deployment

Add custom attributes unique to your deployment to improve data aggregation and analysis:

```brightscript
' Set attributes for all events
nrSetCustomAttribute(m.nr, "subscriptionTier", "premium")
nrSetCustomAttribute(m.nr, "contentProvider", "studio-abc")
nrSetCustomAttribute(m.nr, "region", "us-west-2")
nrSetCustomAttribute(m.nr, "cdnProvider", "akamai")

' Set attributes for specific actions only
nrSetCustomAttribute(m.nr, "pauseReason", "user-initiated", "CONTENT_PAUSE")

' Set multiple attributes at once
attr = {"appVersion": "2.1.0", "campaign": "spring-promo"}
nrSetCustomAttributeList(m.nr, attr)
```

**Use these attributes in New Relic queries:**

```sql
-- Analyze by subscription tier
SELECT count(*) FROM VideoAction WHERE actionName = 'CONTENT_START'
FACET subscriptionTier SINCE 1 day ago

-- Monitor by region
SELECT average(contentNetworkDownloadBitrate) FROM VideoAction
FACET region SINCE 1 hour ago
```

### 4. Gradual Rollout

When deploying to production, consider enabling the agent for a subset of users first:

| Phase | Percentage | Duration | Validation |
|-------|-----------|----------|------------|
| Initial | 5% | 2–3 days | Verify data flowing to New Relic |
| Early | 15% | 3–5 days | Check data quality and performance |
| Expansion | 25% | 5–7 days | Validate across device types |
| Majority | 50% | 1–2 weeks | Monitor at scale |
| Full | 100% | Ongoing | Complete deployment |

## API Reference

### Initialization

#### `NewRelic(account, apikey, appName, appToken, region, activeLogs)`

Build a New Relic Agent object. Call this once at app startup.

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `account` | String | Yes | — | New Relic account number |
| `apikey` | String | Yes | — | Insights API key |
| `appName` | String | Yes | — | Application name |
| `appToken` | String | Yes | — | Mobile Application Token |
| `region` | String | No | `"US"` | API region: `"US"`, `"EU"`, or `"staging"` |
| `activeLogs` | Boolean | No | `false` | Enable agent debug logging |

```brightscript
m.nr = NewRelic("ACCOUNT_ID", "API_KEY", "APP_NAME", "APP_TOKEN")

' EU region with logging enabled
m.nr = NewRelic("ACCOUNT_ID", "API_KEY", "APP_NAME", "APP_TOKEN", "EU", true)
```

---

### System Tracking

#### `NewRelicSystemStart(port)`

Start system logging. Captures HTTP events and bandwidth data via `roSystemLog`.

```brightscript
m.syslog = NewRelicSystemStart(m.port)
```

#### `nrProcessMessage(nr, msg)`

Process system log messages in your main event loop. Returns `true` if the message was handled.

```brightscript
while (true)
    msg = wait(0, m.port)
    if nrProcessMessage(m.nr, msg) = false
        ' Handle your own messages
    end if
end while
```

#### `nrAppStarted(nr, obj)`

Send an `APP_STARTED` event of type `ConnectedDeviceSystem`.

```brightscript
nrAppStarted(m.nr, aa)   ' aa is the argument passed to Main
```

#### `nrSceneLoaded(nr, sceneName)`

Send a `SCENE_LOADED` event of type `ConnectedDeviceSystem`.

```brightscript
nrSceneLoaded(m.nr, "MyVideoScene")
```

---

### Video Tracking

#### `NewRelicVideoStart(nr, video)`

Start video event tracking on a Video node. Call this after passing the agent to your scene.

```brightscript
NewRelicVideoStart(m.nr, m.video)
```

#### `NewRelicVideoStop(nr)`

Stop video event tracking.

```brightscript
NewRelicVideoStop(m.nr)
```

---

### Custom Attributes

#### `nrSetCustomAttribute(nr, key, value, actionName)`

Set a custom attribute included in events. Optionally limit to a specific action.

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `key` | String | Yes | — | Attribute name |
| `value` | Object | Yes | — | Attribute value |
| `actionName` | String | No | `""` (all actions) | Limit to a specific action |

```brightscript
' Attribute on all events
nrSetCustomAttribute(m.nr, "myString", "hello")

' Attribute only on CONTENT_START
nrSetCustomAttribute(m.nr, "myNum", 123, "CONTENT_START")
```

#### `nrSetCustomAttributeList(nr, attr, actionName)`

Set multiple custom attributes at once.

```brightscript
attr = {"key0": "val0", "key1": "val1"}
nrSetCustomAttributeList(m.nr, attr, "CONTENT_HEARTBEAT")
```

#### Custom Attribute Limits

Limits for custom attributes added to default mobile events:

- **Attributes:** 128 maximum
- **String attributes:** 4 KB maximum length (empty string values are not accepted)

> **Note:** There are special keywords reserved for default attributes documented in [DATAMODEL.md](./DATAMODEL.md). Please do not use these as custom attribute names, as they will be dropped by the agent.

---

### Custom Events

#### `nrSendCustomEvent(nr, actionName, attr)`

Send a custom event of type `VideoCustomAction`.

```brightscript
nrSendCustomEvent(m.nr, "MY_ACTION")

attr = {"key0": "val0", "key1": "val1"}
nrSendCustomEvent(m.nr, "MY_ACTION", attr)
```

#### `nrSendVideoEvent(nr, actionName, attr)`

Send a video event of type `VideoAction`.

```brightscript
nrSendVideoEvent(m.nr, "MY_ACTION")

attr = {"key0": "val0", "key1": "val1"}
nrSendVideoEvent(m.nr, "MY_ACTION", attr)
```

#### `nrSendSystemEvent(nr, eventType, actionName, attr)`

Send a system event of type `ConnectedDeviceSystem`.

```brightscript
nrSendSystemEvent(m.nr, "ConnectedDeviceSystem", "MY_ACTION")

attr = {"key0": "val0", "key1": "val1"}
nrSendSystemEvent(m.nr, "ConnectedDeviceSystem", "MY_ACTION", attr)
```

---

### HTTP Events

#### `nrEnableHttpEvents(nr)`

Enable `HTTP_CONNECT` / `HTTP_COMPLETE` events. Disabled by default since v3.0.0.

```brightscript
nrEnableHttpEvents(m.nr)
```

#### `nrDisableHttpEvents(nr)`

Disable `HTTP_CONNECT` / `HTTP_COMPLETE` events.

```brightscript
nrDisableHttpEvents(m.nr)
```

#### `nrSendHttpRequest(nr, urlReq)`

Send an `HTTP_REQUEST` event. Pass an `roUrlTransfer` object.

```brightscript
urlReq = CreateObject("roUrlTransfer")
urlReq.SetUrl("https://api.example.com/data")
nrSendHttpRequest(m.nr, urlReq)
```

#### `nrSendHttpResponse(nr, url, msg)`

Send an `HTTP_RESPONSE` event. Pass the request URL and `roUrlEvent` message.

```brightscript
msg = wait(5000, m.port)
if type(msg) = "roUrlEvent" then
    nrSendHttpResponse(m.nr, requestUrl, msg)
end if
```

---

### Harvest Control

#### `nrSetHarvestTime(nr, time)`

Set harvest time (in seconds) for both events and logs. Minimum value is `60`.

```brightscript
nrSetHarvestTime(m.nr, 60)
```

#### `nrSetHarvestTimeEvents(nr, time)`

Set harvest time for events only. Minimum `60` seconds.

```brightscript
nrSetHarvestTimeEvents(m.nr, 90)
```

#### `nrSetHarvestTimeLogs(nr, time)`

Set harvest time for logs only. Minimum `60` seconds.

```brightscript
nrSetHarvestTimeLogs(m.nr, 120)
```

#### `nrSetHarvestTimeMetrics(nr, time)`

Set harvest time for metrics only. Minimum `60` seconds.

```brightscript
nrSetHarvestTimeMetrics(m.nr, 60)
```

#### `nrForceHarvest(nr)`

Immediately send buffered events and logs. Does not reset the harvest timer.

```brightscript
nrForceHarvest(m.nr)
```

#### `nrForceHarvestEvents(nr)`

Immediately send buffered events only.

```brightscript
nrForceHarvestEvents(m.nr)
```

#### `nrForceHarvestLogs(nr)`

Immediately send buffered logs only.

```brightscript
nrForceHarvestLogs(m.nr)
```

---

### QoE Tracking

Quality of Experience tracking is **disabled by default**. Once enabled, it cannot be disabled during the session.

#### `nrActivateQoeTracking(nr)`

Enable QoE tracking. Sends `QOE_AGGREGATE` events containing startup time, rebuffering, bitrate, and error KPIs.

```brightscript
m.nr = NewRelic("ACCOUNT_ID", "API_KEY", "APP_NAME", "APP_TOKEN")
nrActivateQoeTracking(m.nr)
```

#### `nrSetQoeAggregateIntervalMultiplier(nr, multiplier)`

Control how often QoE events are sent. A multiplier of `N` sends QoE events every N harvest cycles. Default is `1`, minimum is `1`.

```brightscript
' QoE evaluated every 2 harvest cycles (e.g., every 120s with 60s harvest)
nrSetQoeAggregateIntervalMultiplier(m.nr, 2)
```

**QoE behavior notes:**
- QoE events use dirty checking — repeated events are suppressed when KPI values haven't changed
- Ad breaks are automatically excluded from QoE calculations

---

### Logs

#### `nrSendLog(nr, message, logtype, fields)`

Record a log entry using the New Relic Log API.

Example:
	nrDelDomainSubstitution(nr, "^.+\.my\.domain\.com$")
```

**nrSetObfuscationRules**

```
nrSetObfuscationRules(nr as Object, rules as Object) as Void

Description:
	Set obfuscation rules to mask sensitive data in all outgoing events before they are
	buffered. Rules apply to all event types: VideoAction (including QOE_AGGREGATE),
	VideoErrorAction, VideoAdAction (RAF and IMA), VideoCustomAction, and
	ConnectedDeviceSystem. Only string attribute values are processed; numeric and boolean
	values are passed through unchanged. Rules are applied in array order. Call with an
	empty array to remove all rules.

Arguments:
	nr: New Relic Agent object.
	rules: Array of { regex: String, replacement: String } objects.

Return:
	Nothing

Example:
	nrSetObfuscationRules(m.nr, [
		{ regex: "account-[0-9]+",  replacement: "ACCOUNT_ID" },
		{ regex: "token=[^&]+",     replacement: "token=REDACTED" },
		{ regex: "/users/[^/]+",    replacement: "/users/USER_ID" }
	])
```

**nrSendLog**
```brightscript
nrSendLog(m.nr, "User started playback", "info")

' With additional fields
nrSendLog(m.nr, "Playback error detected", "error", {"errorCode": "500", "videoId": "abc123"})
```

---

### Metrics

#### `nrSendMetric(nr, name, value, attr)`

Record a gauge metric (a value that can increase or decrease over time).

```brightscript
nrSendMetric(m.nr, "currentBitrate", 5200000)

' With attributes
nrSendMetric(m.nr, "currentBitrate", 5200000, {"streamType": "HLS"})
```

#### `nrSendCountMetric(nr, name, value, interval, attr)`

Record a count metric (number of occurrences in a time interval). Interval is in milliseconds.

```brightscript
nrSendCountMetric(m.nr, "bufferEvents", 3, 60000)

' With attributes
nrSendCountMetric(m.nr, "bufferEvents", 3, 60000, {"contentType": "live"})
```

#### `nrSendSummaryMetric(nr, name, interval, count, sum, min, max, attr)`

Record a summary metric (pre-aggregated data). Interval is in milliseconds.

```brightscript
nrSendSummaryMetric(m.nr, "downloadSpeed", 2000, 5, 1000, 100, 200)
```

---

### Domain Substitution

#### `nrAddDomainSubstitution(nr, pattern, subs)`

Add a regex pattern to match and replace the `domain` attribute on events and metrics.

```brightscript
nrAddDomainSubstitution(m.nr, "^.+\.akamaihd\.net$", "Akamai")
nrAddDomainSubstitution(m.nr, "^.+\.googleapis\.com$", "Google APIs")
```

#### `nrDelDomainSubstitution(nr, pattern)`

Remove a domain substitution pattern.

```brightscript
nrDelDomainSubstitution(m.nr, "^.+\.akamaihd\.net$")
```

---

### Configuration

#### `nrUpdateConfig(nr, config)`

Update agent configuration, such as network proxy URL.

```brightscript
config = { proxyUrl: "http://proxy.example.com:8888/;" }
nrUpdateConfig(m.nr, config)
```

---

### User Identity

#### `nrSetUserId(nr, userId)`

Set a user identifier included as `enduser.id` on all events.

```brightscript
nrSetUserId(m.nr, "user-12345")
```

---

### Example: Complete Integration

```brightscript
' Main.brs
sub Main(aa as Object)
    screen = CreateObject("roSGScreen")
    m.port = CreateObject("roMessagePort")
    screen.setMessagePort(m.port)
    scene = screen.CreateScene("VideoScene")
    screen.show()

    ' Initialize agent
    m.nr = NewRelic("ACCOUNT_ID", "API_KEY", "APP_NAME", "APP_TOKEN")

    ' Configure harvest time
    nrSetHarvestTime(m.nr, 60)

    ' Enable QoE tracking
    nrActivateQoeTracking(m.nr)
    nrSetQoeAggregateIntervalMultiplier(m.nr, 2)

    ' Enable HTTP event tracking
    nrEnableHttpEvents(m.nr)

    ' Set user identity
    nrSetUserId(m.nr, "user-12345")

    ' Set custom attributes
    nrSetCustomAttribute(m.nr, "subscriptionTier", "premium")
    nrSetCustomAttribute(m.nr, "appVersion", "2.1.0")

    ' Domain substitutions for cleaner analytics
    nrAddDomainSubstitution(m.nr, "^.+\.akamaihd\.net$", "Akamai")
    nrAddDomainSubstitution(m.nr, "^.+\.googleapis\.com$", "Google APIs")

    ' Send APP_STARTED
    nrAppStarted(m.nr, aa)

    ' Pass agent to scene
    scene.setField("nr", m.nr)

    ' Start system tracking
    m.syslog = NewRelicSystemStart(m.port)

    while (true)
        msg = wait(0, m.port)
        if nrProcessMessage(m.nr, msg) = false
            if type(msg) = "roPosterScreenEvent"
                if msg.isScreenClosed()
                    exit while
                end if
            end if
        end if
    end while
end sub
```

## Ad Tracking

The agent supports two ad tracking APIs: [Roku Advertising Framework (RAF)](https://developer.roku.com/en-gb/docs/developer-program/advertising/roku-advertising-framework.md) and [Google IMA](https://developers.google.com/interactive-media-ads/docs/sdks/roku).

<a name="obfuscation-rules"></a>

### Obfuscation Rules

The agent can be configured with regex-based obfuscation rules to mask sensitive data before events are sent to New Relic. This is useful when fields like `contentSrc`, `contentTitle`, `origUrl`, or custom attributes may inadvertently contain user IDs, tokens, or other PII.

Rules are applied to every string attribute in every outgoing event — including video, ad (RAF and IMA), QOE, system, and custom events — before the event enters the internal buffer.

#### Configuration

Call `nrSetObfuscationRules` after creating the agent. Each rule is an associative array with a `regex` string and a `replacement` string:

```brightscript
m.nr = NewRelic("ACCOUNT_ID", "API_KEY", "APP_NAME", "APP_TOKEN")

nrSetObfuscationRules(m.nr, [
    { regex: "account-[0-9]+",  replacement: "ACCOUNT_ID" },
    { regex: "token=[^&]+",     replacement: "token=REDACTED" },
    { regex: "/users/[^/]+",    replacement: "/users/USER_ID" }
])
```

To remove all rules at runtime, call with an empty array:

```brightscript
nrSetObfuscationRules(m.nr, [])
```

#### Rule Ordering

Rules are applied in the order they appear in the array. The output of one rule is the input to the next. Order matters when patterns could overlap:

```brightscript
nrSetObfuscationRules(m.nr, [
    ' Applied first — masks the specific token format
    { regex: "auth-token-[a-z0-9]+", replacement: "AUTH_TOKEN" },
    ' Applied second — masks any remaining bare token references
    { regex: "token=[^&]+",          replacement: "token=REDACTED" }
])
```

#### Behavior and Edge Cases

| Case | Behavior |
|------|----------|
| No rules configured | No-op; zero performance overhead |
| Empty `replacement` string | Matched content is deleted from the value |
| Invalid regex pattern | Rule is skipped; a warning is written to the agent log |
| Non-string attribute values (numbers, booleans) | Passed through unchanged |
| Replacing all rules | Call `nrSetObfuscationRules` again with the new array; previous rules are discarded |

> **Note:** Roku uses `roRegex` for pattern matching. Complex lookahead/lookbehind assertions are not supported. Patterns that are valid in JavaScript or Java regex may need to be simplified for Roku.

<a name="data-model"></a>
### RAF Usage

No additional files needed — the RAF tracker is built into the agent. Pass the agent object to your Ads Task and call `nrTrackRAF`:

```brightscript
' In your Ads Task
adIface = Roku_Ads()

' Setup ads...

logFunc = Function(obj = Invalid as Dynamic, evtType = invalid as Dynamic, ctx = invalid as Dynamic)
    nrTrackRAF(obj, evtType, ctx)
End Function

' m.top.nr is the NRAgent object passed via a field
adIface.setTrackingCallback(logFunc, m.top.nr)
```

### Google IMA Usage

**Additional files required:**

```
components/NewRelicAgent/trackers/IMATracker.brs
components/NewRelicAgent/trackers/IMATracker.xml
source/IMATrackerInterface.brs
```

Include `IMATrackerInterface.brs` in your IMA task XML, then use the tracker functions:

```brightscript
' Create the IMA tracker
tracker = IMATracker(m.nr)

' Pass tracker to IMA task via field, then in the task:
m.player.adBreakStarted = Function(adBreakInfo as Object)
    nrSendIMAAdBreakStart(m.top.tracker, adBreakInfo)
End Function

m.player.adBreakEnded = Function(adBreakInfo as Object)
    nrSendIMAAdBreakEnd(m.top.tracker, adBreakInfo)
End Function

' Register ad event callbacks
m.streamManager.addEventListener(m.sdk.AdEvent.START, Function(ad as Object)
    nrSendIMAAdStart(m.top.tracker, ad)
End Function)

m.streamManager.addEventListener(m.sdk.AdEvent.FIRST_QUARTILE, Function(ad as Object)
    nrSendIMAAdFirstQuartile(m.top.tracker, ad)
End Function)

m.streamManager.addEventListener(m.sdk.AdEvent.MIDPOINT, Function(ad as Object)
    nrSendIMAAdMidpoint(m.top.tracker, ad)
End Function)

m.streamManager.addEventListener(m.sdk.AdEvent.THIRD_QUARTILE, Function(ad as Object)
    nrSendIMAAdThirdQuartile(m.top.tracker, ad)
End Function)

m.streamManager.addEventListener(m.sdk.AdEvent.COMPLETE, Function(ad as Object)
    nrSendIMAAdEnd(m.top.tracker, ad)
End Function)
```

#### IMA Tracker API

| Function | Description |
|----------|-------------|
| `IMATracker(nr)` | Create a Google IMA Tracker object |
| `nrSendIMAAdBreakStart(tracker, adBreakInfo)` | Send `AD_BREAK_START` event |
| `nrSendIMAAdBreakEnd(tracker, adBreakInfo)` | Send `AD_BREAK_END` event |
| `nrSendIMAAdStart(tracker, ad)` | Send `AD_START` event |
| `nrSendIMAAdEnd(tracker, ad)` | Send `AD_END` event |
| `nrSendIMAAdFirstQuartile(tracker, ad)` | Send `AD_QUARTILE` (first) event |
| `nrSendIMAAdMidpoint(tracker, ad)` | Send `AD_QUARTILE` (midpoint) event |
| `nrSendIMAAdThirdQuartile(tracker, ad)` | Send `AD_QUARTILE` (third) event |
| `nrSendIMAAdError(tracker, error)` | Send `AD_ERROR` event |

### AWS Elemental MediaTailor SSAI

New Relic provides a tracker component for [AWS Elemental MediaTailor](https://aws.amazon.com/mediatailor/) Server-Side Ad Insertion (SSAI). The tracker integrates with Roku's RAFX_SSAI `awsemt` adapter and records `VideoAdAction` events automatically for every ad lifecycle event in both VOD and LIVE streams (HLS and DASH).

#### Prerequisite: rafxssai.brs

The RAFX_SSAI library (`rafxssai.brs`) is **owned and distributed by Roku**, not by New Relic. You must obtain it from Roku and include it in your channel package:

1. Download `rafxssai.brs` from the [Roku Advertising Framework](https://developer.roku.com/en-gb/docs/developer-program/advertising/roku-advertising-framework.md)
2. Place it at `pkg:/source/rafxssai.brs` in your project

New Relic does not bundle this file. Because Roku owns and updates it, bundling it would risk version conflicts and certification issues.

#### Additional files required

```
source/
    MediaTailorTrackerInterface.brs
components/
    NewRelicAgent/trackers/
        MediaTailorTracker.brs
        MediaTailorTracker.xml
```

#### Integration steps

MediaTailor integration takes three small pieces of plumbing — one in your scene, two in your task.

**1. Create the tracker in the scene thread** and hand it to your task via a node field. The tracker MUST be created on the render thread — RAFX dispatches ad-event listeners via `callFunctionInGlobalNamespace`, which cannot reach a tracker stashed on the task's local `m`.

```brightscript
' In your scene (render thread)
m.myTask = createObject("roSGNode", "MyTask")
m.myTask.setField("tracker", MediaTailorTracker(m.nr))
m.myTask.control = "RUN"
```

Expose a matching `tracker` field on your task's `.xml`:

```xml
<field id="tracker" type="node"/>
```

**2. Enable tracking after `adIface.init()`** in your task:

```brightscript
adIface = RAFX_SSAI({name: "awsemt"})
adIface.init()

nrEnableMediaTailorTracking(m.top.nr, adIface)
```

`nrEnableMediaTailorTracking` picks up the tracker you set on `m.top.tracker` and registers its own listeners on every ad lifecycle event. Your existing adapter setup and listeners are untouched.

**3. Observe `position` on the Video node** in your task's event loop:

```brightscript
m.top.videoNode.observeField("state",    port)
m.top.videoNode.observeField("position", port)
```

RAFX's `onMessage(POSITION)` is what drives ad-break resolution. Without this observe, `PodStart` / `Impression` / `Complete` never fire.

#### Optional: inject sidecar metadata

If you have additional metadata from an `ads_metadata` sidecar response (e.g. targeting parameters, avail ID), inject it before the first ad plays:

```brightscript
metadata = {adTrackingUrl: "https://...", availId: "avail-123"}
nrSetMediaTailorAdMetadata(m.nrMTTracker, metadata)
```

After `nrEnableMediaTailorTracking`, the tracker is also accessible in the task scope as `m.nrMTTracker` (mirrored from `m.top.tracker`), so the sidecar call in the same task can reference it directly.

These attributes are appended to every subsequent `VideoAdAction` event for the duration of the session.

#### MediaTailor Tracker API

| Function | Description |
|----------|-------------|
| `nrEnableMediaTailorTracking(nr, adIface)` | Register NR listeners on your RAFX_SSAI adapter — one call, no forwarding needed |
| `nrSetMediaTailorAdMetadata(tracker, metadata)` | Inject sidecar key/value metadata before ads play |

---

## Bitrate Metrics

The agent captures three distinct bitrate metrics providing complete quality analysis:

| Attribute | Description | Use Case |
|-----------|-------------|----------|
| `contentBitrate` | Actual encoding bitrate (bps) of the currently playing rendition | Monitor video quality being delivered |
| `contentSegmentDownloadBitrate` | Bandwidth estimate (bps) used by the ABR algorithm | Analyze ABR decision-making |
| `contentNetworkDownloadBitrate` | Raw network download speed (bps) from the most recent segment | Monitor real-time network performance |

```sql
-- NRQL Query Examples
SELECT average(contentNetworkDownloadBitrate) FROM VideoAction
WHERE actionName = 'CONTENT_HEARTBEAT' SINCE 1 hour ago

SELECT contentBitrate, contentSegmentDownloadBitrate FROM VideoAction
WHERE actionName = 'CONTENT_HEARTBEAT' FACET contentTitle SINCE 1 day ago
```

## Data Model

The agent captures comprehensive analytics across five event types:

| Event Type | Description |
|------------|-------------|
| **ConnectedDeviceSystem** | System events — app lifecycle, HTTP requests, bandwidth, device info |
| **VideoAction** | Playback events — play, pause, buffer, seek, heartbeats, QoE aggregates |
| **VideoAdAction** | Ad events — ad start/end, quartiles, break start/end |
| **VideoErrorAction** | Error events — content errors, ad errors, HTTP errors |
| **VideoCustomAction** | Custom events defined by your application |

```sql
SELECT * FROM ConnectedDeviceSystem, VideoAction, VideoErrorAction, VideoAdAction, VideoCustomAction
```

**Full Documentation:** See [DATAMODEL.md](./DATAMODEL.md) for complete event and attribute reference.

## Testing

To run unit tests:

1. Copy `UnitTestFramework.brs` from [roku unit-testing-framework](https://github.com/rokudev/unit-testing-framework) to `source/testFramework/`
2. Install the demo channel on your Roku device
3. Run:

```bash
./test.sh ROKU_IP
```

Where `ROKU_IP` is the address of the Roku device. Connect to the debug terminal (port 8085) to see results. Optionally provide the dev password as a second argument to compile and deploy before running tests.

## Debugging

Network proxying is supported using URL re-write (see [App Level Proxying](https://rokulikeahurricane.io/proxying_network_requests)). To send all network requests via a proxy:

```brightscript
config = { proxyUrl: "http://proxy.example.com:8888/;" }
nrUpdateConfig(m.nr, config)
```

## Pricing

> **Important:** Ingesting video telemetry data via this agent requires a subscription to Advanced Compute. Contact your New Relic account representative for details on pricing and entitlement.

## Support

Should you need assistance with New Relic products, you are in good hands with several support channels.

If the issue has been confirmed as a bug or is a feature request, please file a GitHub issue.

### Support Channels

- [New Relic Documentation](https://docs.newrelic.com): Comprehensive guidance for using our platform
- [New Relic Community](https://discuss.newrelic.com): The best place to engage in troubleshooting questions
- [New Relic University](https://learn.newrelic.com): A range of online training for New Relic users of every level
- [New Relic Technical Support](https://support.newrelic.com): 24/7/365 ticketed support. Read more about our [Technical Support Offerings](https://docs.newrelic.com/docs/licenses/license-information/general-usage-licenses/support-plan)
- [Community Forum Thread](https://discuss.newrelic.com/t/new-relic-open-source-roku-agent/97802)

## Contribute

We encourage your contributions to improve the Roku Agent! Keep in mind that when you submit your pull request, you'll need to sign the CLA via the click-through using CLA-Assistant. You only have to sign the CLA one time per project.

If you have any questions, or to execute our corporate CLA (which is required if your contribution is on behalf of a company), drop us an email at opensource+videoagent@newrelic.com.

For more details on how best to contribute, see [CONTRIBUTING.md](./CONTRIBUTING.md).

### A note about vulnerabilities

As noted in our [security policy](../../security/policy), New Relic is committed to the privacy and security of our customers and their data. We believe that providing coordinated disclosure by security researchers and engaging with the security community are important means to achieve our security goals.

If you believe you have found a security vulnerability in this project or any of New Relic's products or websites, we welcome and greatly appreciate you reporting it to New Relic through our [bug bounty program](https://docs.newrelic.com/docs/security/security-privacy/information-security/report-security-vulnerabilities/).

If you would like to contribute to this project, review [these guidelines](./CONTRIBUTING.md).

To all contributors, we thank you! Without your contribution, this project would not be what it is today.

## License

The Roku Agent is licensed under the [Apache 2.0](http://apache.org/licenses/LICENSE-2.0.txt) License.

The Roku Agent also uses source code from third-party libraries. Full details on which libraries are used and the terms under which they are licensed can be found in the [third-party notices document](./THIRD_PARTY_NOTICES.md).