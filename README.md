[![Community Project header](https://github.com/newrelic/open-source-office/raw/master/examples/categories/images/Community_Project.png)](https://github.com/newrelic/open-source-office/blob/master/examples/categories/index.md#community-project)

# New Relic Roku Agent

The New Relic Roku Agent tracks the behavior of a Roku App. It contains two parts, one to monitor general system level events and one to monitor video related events, for apps that use a video player.

Internally, it uses the Insights API to send events using the REST interface. It sends two types of events: RokuSystem for system events and RokuVideo for video events. After the agent has sent some data it will be accessible in NR One Dashboards and Insights with a simple NRQL request like:

```
SELECT * FROM RokuSystem, RokuVideo 
```
Will result in something like the following: 

![image](https://user-images.githubusercontent.com/8813505/77453470-b2942d00-6dcd-11ea-9d5b-e48b5ae3c9c6.png)

## On This Page
  * [Requirements](#requirements)  
  * [Installation](#installation)  
  * [Usage](#usage)  
  * [Agent API](#api)  
  * [Data Model](#data-model)  
&nbsp;&nbsp;  * [Roku System](#roku-system)  
&nbsp;&nbsp;  * [Roku Video](#roku-video)  
  * [Open Source License](#open-source)  
  * [Support](#support)  
  * [Contributing](#contributing)  

<a name="requirements"/>

### Requirements

Sending both system events and video events requires an Insights Pro subscription.   Insights Free accounts permit only one event type per API key.   If you are using an Insights Free account, you can enable only one type of Roku event capture at a time (system or video).

To initialize the agent you need an ACCOUNT ID and an API KEY. 

The ACCOUNT ID indicates the New Relic account to which you would like to send the Roku data.   For example, https://insights.newrelic.com/accounts/xxx.  Where “xxx” is the Account ID.

To register the API Key, follow the instructions found [here](https://docs.newrelic.com/docs/insights/insights-data-sources/custom-data/send-custom-events-event-api#register).

<a name="installation"/>

### Installation

1. Download the Roku Video Agent and unzip it. Inside the package you will find the following file structure:

```
components/NewRelicAgent/
	NRAgent.brs
	NRAgent.xml
	NRTask.brs
	NRTask.xml
source/
	NewRelicAgent.brs
```

2. Open your Roku app project’s directory and copy the “NewRelicAgent” folder to “components” and "NewRelicAgent.brs" file to “source”.

<a name="usage"/>

### Usage

To enable automatic event capture perform the following steps which are detailed below.

1. Call `NewRelic` from Main subroutine and store the returned object.
2. Right after that, call `nrAppStarted` (optional but recommended).
3. Call `NewRelicSystemStart` and `NewRelicVideoStart` to start capturing events for system and video (both optional).
4. Inside the main wait loop, call `nrProcessMessage` (only mandatory to capture system events, otherwise not necessary).

#### Example

> Note: For a more complete example, please refer to the sample app included in the present repository. Specifically files Main.brs and files inside components directory.

*Main.brs*

```
sub Main(aa as Object)
	screen = CreateObject("roSGScreen")
	m.port = CreateObject("roMessagePort")
	screen.setMessagePort(m.port)

	'Create the main scene that contains a video player
	scene = screen.CreateScene("VideoScene")
	screen.show()
	    
	'Init New Relic Agent (3rd argument is optional, True to show console logs)
	m.nr = NewRelic(“ACCOUNT ID“, “API KEY“)
	    
	'Send APP_STARTED event
	nrAppStarted(m.nr, aa)
	    
	'Pass NewRelicAgent object to the main scene
	scene.setField("nr", m.nr)
	    
	'Activate system tracking
	m.syslog = NewRelicSystemStart(m.port)
    
	while (true)
		msg = wait(0, m.port)
		if nrProcessMessage(m.nr, msg) = false
			'It is not a system message captured by New Relic Agent
			if type(msg) = "roPosterScreenEvent"
				if msg.isScreenClosed()
					exit while
				end if
			end if
		end if
	end while
end sub
```

*VideoScene.xml*

```
<?xml version="1.0" encoding="utf-8" ?>
<component name="VideoScene" extends="Scene"> 
	<interface>
		<!-- Field used to pass the NewRelicAgent object to the scene -->
		<field id="nr" type="node" onChange="nrRefUpdated" />
	</interface>
		
	<children>
		<Video
			id="myVideo"
			translation="[0,0]"
		/>
	</children>
	
	<!-- New Relic Agent Interface -->
	<script type="text/brightscript" uri="pkg:/source/NewRelicAgent.brs"/>
	
	<script type="text/brightscript" uri="pkg:/components/VideoScene.brs"/>
</component>
```

*VideoScene.brs*

```
sub init()
    m.top.setFocus(true)
    setupVideoPlayer()
end sub

function nrRefUpdated()
    m.nr = m.top.nr
    
    'Activate video tracking
    NewRelicVideoStart(m.nr, m.video)
end function

function setupVideoPlayer()
    videoUrl = "http://..."
    videoContent = createObject("RoSGNode", "ContentNode")
    videoContent.url = videoUrl
    videoContent.title = "Any Video"
    m.video = m.top.findNode("myVideo")
    m.video.content = videoContent
    m.video.control = "play"
end function
```
<a name="api"/>

### Agent API

To interact with the New Relic Agent it provides a set of functions that wrap internal behaviours. All wrappers are implemented inside NewRelicAgent.brs and all include inline documentation.

**NewRelic**

```
NewRelic(account as String, apikey as String, activeLogs = false as Boolean) as Object

Description:
	Build a New Relic Agent object.

Arguments:
	account: New Relic account number.
	apikey: Insights API key.
	activeLogs: (optional) Activate logs or not. Default False.
	
Return:
	New Relic Agent object.
	
Example:

	sub Main(aa as Object)
		screen = CreateObject("roSGScreen")
		m.port = CreateObject("roMessagePort")
		screen.setMessagePort(m.port)
		scene = screen.CreateScene("VideoScene")
		screen.show()
	
		m.nr = NewRelic("ACCOUNT ID", "API KEY")
```

**NewRelicSystemStart**

```
NewRelicSystemStart(port as Object) as Object

Description:
	Start system logging.

Arguments:
	port: A message port.
	
Return:
	The roSystemLog object created.
	
Example:

	m.syslog = NewRelicSystemStart(m.port)
```

**NewRelicVideoStart**

```
NewRelicVideoStart(nr as Object, video as Object) as Void

Description:
	Start video logging.

Arguments:
	nr: New Relic Agent object.
	video: A video object.
	
Return:
	Nothing.
	
Example:

	NewRelicVideoStart(m.nr, m.video)
```

**nrProcessMessage**

```
nrProcessMessage(nr as Object, msg as Object) as Boolean

Description:
	Check for a system log message, process it and sends the appropriate event.

Arguments:
	nr: New Relic Agent object.
	msg: A message of type roSystemLogEvent.
	
Return:
	True if msg is a system log message, False otherwise.
	
Example:

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
```

**nrSetCustomAttribute**

```
nrSetCustomAttribute(nr as Object, key as String, value as Object, actionName = "" as String) as Void

Description:
	Set a custom attribute to be included in the events.

Arguments:
	nr: New Relic Agent object.
	key: Attribute name.
	value: Attribute value.
	actionName: (optional) Action where the attribute will be included. Default all actions.
	
Return:
	Nothing.
		
Example:

	nrSetCustomAttribute(m.nr, "myNum", 123, "CONTENT_START")
	nrSetCustomAttribute(m.nr, "myString", "hello")
```

**nrSetCustomAttributeList**

```
nrSetCustomAttributeList(nr as Object, attr as Object, actionName = "" as String) as Void

Description:
	Set a custom attribute list to be included in the events.

Arguments:
	nr: New Relic Agent object.
	attr: Attribute list, as an associative array.
	actionName: (optional) Action where the attribute will be included. Default all actions.
	
Return:
	Nothing.
		
Example:

	attr = {"key0":"val0", "key1":"val1"}
	nrSetCustomAttributeList(m.nr, attr, "CONTENT_HEARTBEAT")
```

**nrAppStarted**

```
nrAppStarted(nr as Object, obj as Object) as Void

Description:
	Send an APP_STARTED event of type RokuSystem.

Arguments:
	nr: New Relic Agent object.
	obj: The object sent as argument of Main subroutine.
	
Return:
	Nothing.
		
Example:

	sub Main(aa as Object)
		...
		nrAppStarted(m.nr, aa)
```

**nrSceneLoaded**

```
nrSceneLoaded(nr as Object, sceneName as String) as Void

Description:
	Send a SCENE_LOADED event of type RokuSystem.

Arguments:
	nr: New Relic Agent object.
	sceneName: The scene name.
	
Return:
	Nothing.
		
Example:

	nrSceneLoaded(m.nr, "MyVideoScene")
```

**nrSendCustomEvent**

```
nrSendCustomEvent(nr as Object, eventType as String, actionName as String, attr = invalid as Object) as Void

Description:
	Send a custom event.

Arguments:
	nr: New Relic Agent object.
	eventType: Event type.
	actionName: Action name.
	attr: (optional) Attributes associative array.
	
Return:
	Nothing.
		
Example:

	nrSendCustomEvent(m.nr, "MyEvent", "MY_ACTION")
	attr = {"key0":"val0", "key1":"val1"}
	nrSendCustomEvent(m.nr, "MyEvent", "MY_ACTION", attr)
```

**nrSendSystemEvent**

```
nrSendSystemEvent(nr as Object, actionName as String, attr = invalid) as Void

Description:
	Send a system event, type RokuSystem.

Arguments:
	nr: New Relic Agent object.
	actionName: Action name.
	attr: (optional) Attributes associative array.
	
Return:
	Nothing.
		
Example:

	nrSendSystemEvent(m.nr, "MY_ACTION")
	attr = {"key0":"val0", "key1":"val1"}
	nrSendSystemEvent(m.nr, "MY_ACTION", attr)
```

**nrSendVideoEvent**

```
nrSendVideoEvent(nr as Object, actionName as String, attr = invalid) as Void

Description:
	Send a video event, type RokuVideo.

Arguments:
	nr: New Relic Agent object.
	actionName: Action name.
	attr: (optional) Attributes associative array.
	
Return:
	Nothing.
		
Example:

	nrSendVideoEvent(m.nr, "MY_ACTION")
	attr = {"key0":"val0", "key1":"val1"}
	nrSendVideoEvent(m.nr, "MY_ACTION", attr)
```

**nrSendHttpRequest**

```
nrSendHttpRequest(nr as Object, urlReq as Object) as Void

Description:
	Send an HTTP_REQUEST event of type RokuSystem.

Arguments:
	nr: New Relic Agent object.
	urlReq: URL request, roUrlTransfer object.
	
Return:
	Nothing.
		
Example:

	urlReq = CreateObject("roUrlTransfer")
	urlReq.SetUrl(_url)
	...
	nrSendHttpRequest(m.nr, urlReq)
```

**nrSendHttpResponse**

```
nrSendHttpResponse(nr as Object, _url as String, msg as Object) as Void

Description:
	Send an HTTP_RESPONSE event of type RokuSystem.

Arguments:
	nr: New Relic Agent object.
	_url: Request URL.
	msg: A message of type roUrlEvent.
	
Return:
	Nothing.
		
Example:

	msg = wait(5000, m.port)
	if type(msg) = "roUrlEvent" then
		nrSendHttpResponse(m.nr, _url, msg)
	end if
```

**nrSetHarvestTime**

```
nrSetHarvestTime(nr as Object, time as Integer) as Void

Description:
	Set harvest time, the time the events are buffered before being sent to Insights.

Arguments:
	nr: New Relic Agent object.
	time: Time in seconds.
	
Return:
	Nothing.
		
Example:

	nrSetHarvestTime(m.nr, 60)
```

**nrForceHarvest**

```
nrForceHarvest(nr as Object) as Void

Description:
	Do harvest immediately. It doesn't reset the harvest timer.

Arguments:
	nr: New Relic Agent object.
	
Return:
	Nothing.
		
Example:

	nrForceHarvest(m.nr)
```

<a name="data-model"/>

### Data Model

The agent generates two different event types: `RokuSystem` and `RokuVideo`.

<a name="roku-system"/>

#### 1. RokuSystem

This event groups all actions related to system tracking.

#### 1.1 Actions

| Action Name | Description |
|---|---|
| `BANDWIDTH_MINUTE` | Report the bandwidth every minute. |
| `HTTP_CONNECT` | An HTTP request, generated by roSystemLog. |
| `HTTP_COMPLETE` | An HTTP response, generated by roSystemLog. |
| `HTTP_ERROR` | An HTTP error, generated by roSystemLog. |
| `HTTP_REQUEST` | An HTTP request. Generated by nrSendHttpRequest function. |
| `HTTP_RESPONSE` | An HTTP response. Generated by nrSendHttpResponse function. |
| `APP_STARTED` | The app did start. Generated by nrAppStarted function. |
| `SCENE_LOADED` | A scene did load. Generated by nrSceneLoaded function. |

#### 1.2 Attributes

There is a set of attributes common to all actions sent over a `RokuSystem` and others are specific to a certain action.

#### 1.2.1 Common Attributes

| Attribute Name | Description |
|---|---|
| `newRelicAgent` | Always “RokuAgent”. |
| `newRelicVersion` | Agent’s version. |
| `sessionId` | Session ID, a hash that is generated every time the Roku app starts. |
| `hdmiIsConnected` | Boolean. HDMI is connected or not. |
| `hdmiHdcpVersion` | HDCP version. |
| `uuid` | Roku Device UUID. |
| `device` | Roku device name. |
| `deviceGroup` | Always “Roku”. |
| `deviceManufacturer` | Always “Roku”. |
| `deviceModel` | Roku model. |
| `deviceType` | Roku model type. |
| `osName` | Always “RokuOS”. |
| `osVersion` | Firmware version. |
| `countryCode` | Country from where the current user is connected. |
| `timeZone` | Current user’s timezone. |
| `locale` | Current user’s locale. |
| `memoryLevel` | Device memory level. |
| `connectionType` | Network connection type (WiFi, etc). |
| `displayType` | Type of display, screen, TV, etc. |
| `displayMode` | Display mode. |
| `displayAspectRatio` | Aspect ratio. |
| `videoMode` | Video mode. |
| `graphicsPlatform` | Graphics platform (OpenGL, etc). |
| `timeSinceLastKeyPress` | Time since last keypress in the remote. Milliseconds. |
| `appId` | Application ID. |
| `appVersion` | Application version. |
| `appName` | Application name. |
| `appDevId` | Developer ID. |
| `appBuild` | Application build number. |
| `timeSinceLoad` | Time since NewRelic function call. Seconds. |
| `uptime` | Uptime of the system since the last reboot. Seconds. |

#### 1.2.2 Action Specific Attributes

| Attribute Name | Description | Actions |
|---|---|---|
| `httpCode` | Response code. | `HTTP_COMPLETE`, `HTTP_CONNECT`, `HTTP_ERROR`, `HTTP_RESPONSE` |
| `method` | HTTP method. | `HTTP_COMPLETE`, `HTTP_CONNECT`, `HTTP_ERROR`, `HTTP_REQUEST ` | 
| `origUrl` | Original URL of request. | `HTTP_COMPLETE`, `HTTP_CONNECT`, `HTTP_ERROR`, `HTTP_REQUEST`, `HTTP_RESPONSE` |
| `status` | Current request status. | `HTTP_COMPLETE`, `HTTP_CONNECT`, `HTTP_ERROR` |
| `targetIp` | Target IP address of request. | `HTTP_COMPLETE`, `HTTP_CONNECT`, `HTTP_ERROR` |
| `url` | Actual URL of request. | `HTTP_COMPLETE`, `HTTP_CONNECT`, `HTTP_ERROR` |
| `counter` | Number of actual network events grouped in. | `HTTP_COMPLETE`, `HTTP_CONNECT` |
| `bytesDownloaded` | Number of bytes downloaded. Summation if grouped. | `HTTP_COMPLETE` |
| `bytesUploaded` | Number of bytes uploaded. Summation if grouped. | `HTTP_COMPLETE` |
| `connectTime` | Total connection time. Average if grouped. | `HTTP_COMPLETE` |
| `contentType` | Mime type of response body. | `HTTP_COMPLETE` |
| `dnsLookupTime` | DNS lookup time. Average if grouped. | `HTTP_COMPLETE` |
| `downloadSpeed` | Download speed. Average if grouped. | `HTTP_COMPLETE` |
| `firstByteTime` | Time elapsed until the first bytes arrived. Average if grouped. | `HTTP_COMPLETE` |
| `transferTime` | Total transfer time. Average if grouped. | `HTTP_COMPLETE` |
| `uploadSpeed` | Upload speed. Average if grouped. | `HTTP_COMPLETE` |
| `bandwidth` | Bandwidth. | `BANDWIDTH_MINUTE` |
| `lastExitOrTerminationReason` | The reason for the last app exit / termination. | `APP_STARTED` |
| `splashTime` | The splash time in ms. | `APP_STARTED` |
| `instantOnRunMode` | Value of `instant_on_run_mode` property sent to Main. | `APP_STARTED` |
| `launchSource ` | Value of `source` property sent to Main. | `APP_STARTED` |
| `httpResult` | Request final status. | `HTTP_RESPONSE` |
| `http*` | Multiple attributes. All the header keys. | `HTTP_RESPONSE` |
| `transferIdentity` | HTTP request identificator. | `HTTP_REQUEST`, `HTTP_RESPONSE` |
| `sceneName` | Identifier of the scene. | `SCENE_LOADED` |

<a name="roku-video"/>

#### 2. RokuVideo

This event groups all actions related to video tracking.

#### 2.1 Actions


| Action Name | Description |
|---|---|
| `PLAYER_READY` | Player is ready to start working. It happens when the video agent is started. |
| `CONTENT_REQUEST` | “Play” button pressed or autoplay activated. |
| `CONTENT_START` | Video just started playing. |
| `CONTENT_END` | Video ended playing. |
| `CONTENT_PAUSE` | Video paused. |
| `CONTENT_RESUME` | Video resumed. |
| `CONTENT_BUFFER_START` | Video started buffering. |
| `CONTENT_BUFFER_END` | Video ended buffering. |
| `CONTENT_ERROR` | Video error happened. |
| `CONTENT_HEARTBEAT` | Sent every 30 seconds between video start and video end. |

#### 2.2 Attributes

There is a set of attributes common to all actions sent over a `RokuVideo` and others are specific to a certain action.

#### 2.2.1 Common Attributes

For video events, the common attributes include all `RokuSystem` common attributes (1.2.1) plus the video event ones. Here we will describe only the video common attributes.

| Attribute Name | Description |
|---|---|
| `contentDuration` | Total video duration in milliseconds. |
| `contentPlayhead` | Current video position in milliseconds. |
| `contentIsMuted` | Video is muted or not. |
| `contentSrc` | Video URL. |
| `contentId` | Content ID, a CRC32 of contentSrc. |
| `contentBitrate` | Video manifest bitrate. |
| `contentMeasuredBitrate` | Video measured bitrate. |
| `contentSegmentBitrate` | In case of segmented video sources (HLS, DASH), the current segment’s bitrate. |
| `playerName` | Always “RokuVideoPlayer”. |
| `playerVersion` | Current firmware version. |
| `sessionDuration` | Time since the session started. |
| `viewId` | sessionId + “-“ + video counter. |
| `viewSession` | Copy of sessionId. |
| `trackerName` | Always “rokutracker”. |
| `trackerVersion` | Agent version. |
| `numberOfVideos` | Number of videos played. |
| `numberOfErrors` | Number of errors happened. |
| `timeSinceLastHeartbeat` | Time since last heartbeat, in milliseconds. |
| `timeSinceRequested` | Time since the video requested, in milliseconds. |
| `timeSinceStarted` | Time since the video started, in milliseconds. |
| `timeSinceTrackerReady` | Time since `PLAYER_READY`, in milliseconds. |
| `totalPlaytime` | Total time the user spend seeing the video. |
| `playtimeSinceLastEvent` | Total time the user spend seeing the video since last video event. |
| `timeToStartStreaming` | The time in milliseconds from playback being started until the video actually began playing. |
| `isPlaylist` | Content is a playlist. Boolean. |
| `videoFormat` | Video format, a mime type. |

#### 2.2.2 Action Specific Attributes

| Attribute | Name Description | Actions |
|---|---|---|
| `timeSinceBufferBegin` | Time since video last video buffering began, in milliseconds. | `CONTENT_BUFFER_END` |
| `timeSincePaused` | Time since the video was paused, in milliseconds. | `CONTENT_RESUME` |
| `errorMessage` | Descriptive error message. | `CONTENT_ERROR` |
| `errorCode` | Numeric error code. | `CONTENT_ERROR` |
| `errorStr` | Detailed error message. | `CONTENT_ERROR` |
| `errorClipId` | Property `clip_id` from Video object errorInfo. | `CONTENT_ERROR` |
| `errorIgnored` | Property `ignored` from Video object errorInfo. | `CONTENT_ERROR` |
| `errorSource` | Property `source` from Video object errorInfo. | `CONTENT_ERROR` |
| `errorCategory` | Property `category` from Video object errorInfo. | `CONTENT_ERROR` |
| `errorInfoCode` | Property `error_code` from Video object errorInfo. | `CONTENT_ERROR` |
| `errorDebugMsg` | Property `dbgmsg` from Video object errorInfo. | `CONTENT_ERROR` |
| `errorAttributes` | Property `error_attributes` from Video object errorInfo. | `CONTENT_ERROR` |
| `isInitialBuffering` | Is the initial buffering event, and not a rebuffering. In playlists it only happens at the beginning, and not on every video. | `CONTENT_BUFFER_*` |

<a name="open-source"/>

# Open source license

This project is distributed under the [Apache 2 license](LICENSE).

<a name="support"/>

# Support

New Relic has open-sourced this project. This project is provided AS-IS WITHOUT WARRANTY OR DEDICATED SUPPORT. Issues and contributions should be reported to the project here on GitHub.

We encourage you to bring your experiences and questions to the [Explorers Hub](https://discuss.newrelic.com) where our community members collaborate on solutions and new ideas.

## Community

New Relic hosts and moderates an online forum where customers can interact with New Relic employees as well as other customers to get help and share best practices. Like all official New Relic open source projects, there's a related Community topic in the New Relic Explorers Hub. You can find this project's topic/threads here:

https://discuss.newrelic.com/t/new-relic-open-source-roku-agent/97802

## Issues / enhancement requests

Issues and enhancement requests can be submitted in the [Issues tab of this repository](https://github.com/newrelic/video-agent-roku/issues). Please search for and review the existing open issues before submitting a new issue.

<a name="contributing"/>

# Contributing

Contributions are encouraged! If you submit an enhancement request, we'll invite you to contribute the change yourself. Please review our [Contributors Guide](CONTRIBUTING.md).

Keep in mind that when you submit your pull request, you'll need to sign the CLA via the click-through using CLA-Assistant. If you'd like to execute our corporate CLA, or if you have any questions, please drop us an email at opensource+videoagent@newrelic.com.
