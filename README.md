[![Community Project header](https://github.com/newrelic/open-source-office/raw/master/examples/categories/images/Community_Project.png)](https://github.com/newrelic/open-source-office/blob/master/examples/categories/index.md#community-project)

# New Relic Roku Agent

The New Relic Roku Agent tracks the behavior of a Roku App. It contains two parts, one to monitor general system level events and one to monitor video related events, for apps that use a video player.

Internally, it uses the Event API to send events using the REST interface. It sends five types of events: 
- ConnectedDeviceSystem for system events
- VideoAction for video events. 
- VideoErrorAction for errors.
- VideoAdAction for ads.
- VideoCustomAction for custom actions.
After the agent has sent some data it will be accessible in NR One Dashboards with a simple NRQL request like:

```
SELECT * FROM ConnectedDeviceSystem, VideoAction, VideoErrorAction, VideoAdAction, VideoCustomAction
```
Will result in something like the following: 

![image](https://user-images.githubusercontent.com/8813505/77453470-b2942d00-6dcd-11ea-9d5b-e48b5ae3c9c6.png)

## On This Page
  * [Requirements](#requirements)  
  * [Installation](#installation)  
  * [Usage](#usage)  
  * [Agent API](#api)  
  * [Data Model](#data-model)
  * [Ad Tracking](#ad-track)
  * [Testing](#testing)
  * [Open Source License](#open-source)  
  * [Support](#support)  
  * [Contributing](#contributing)  

<a name="requirements"></a>

### Requirements

To initialize the agent you need an [ACCOUNT ID](https://docs.newrelic.com/docs/accounts/accounts-billing/account-structure/account-id/) and a [LICENSE KEY](https://docs.newrelic.com/docs/apis/intro-apis/new-relic-api-keys/#license-key). 

To configure the agent to use the staging endpoint, you need to modify the `main.brs` file. Specifically, you should replace config value from `US` to `staging`.

<a name="installation"></a>

### Installation

1. Download the [Roku Video Agent](https://github.com/newrelic/video-agent-roku/releases/latest) and unzip it. Inside the package you will find the following file structure:

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

<a name="usage"></a>

### Usage

To enable automatic event capture perform the following steps which are detailed below.

1. Call `NewRelic` from Main subroutine and store the returned object.
2. Right after that, call `nrAppStarted` (optional but recommended).
3. Call `NewRelicSystemStart` and `NewRelicVideoStart` to start capturing events for system and video (both optional).
4. Inside the main wait loop, call `nrProcessMessage` (only mandatory to capture system events, otherwise not necessary).

#### Example

> Note: For a more complete example, please refer to the sample app included in the present repository. Specifically files Main.brs and files inside components directory.

*Main.brs*

```brightscript
sub Main(aa as Object)
	screen = CreateObject("roSGScreen")
	m.port = CreateObject("roMessagePort")
	screen.setMessagePort(m.port)

	'Create the main scene that contains a video player
	scene = screen.CreateScene("VideoScene")
	screen.show()
	    
	'Init New Relic Agent
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

```xml
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

```brightscript
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
<a name="api"></a>

### Agent API

To interact with the New Relic Agent it provides a set of functions that wrap internal behaviours. All wrappers are implemented inside NewRelicAgent.brs and all include inline documentation.

**NewRelic**

```
NewRelic(account as String, apikey as String, region = "US" as String, activeLogs = false as Boolean) as Object

Description:
	Build a New Relic Agent object.

Arguments:
	account: New Relic account number.
	apikey: API key.
	region: (optional) New Relic API region, EU or US. Default US.
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

**NewRelicVideoStop**

```
NewRelicVideoStop(nr as Object) as Void

Description:
	Stop video logging.

Arguments:
	nr: New Relic Agent object.
	
Return:
	Nothing.
	
Example:

	NewRelicVideoStop(m.nr)
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
	Send an APP_STARTED event of type ConnectedDeviceSystem.

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
	Send a SCENE_LOADED event of type ConnectedDeviceSystem.

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
	Send a system event, type ConnectedDeviceSystem.

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
	Send a video event, type VideoAction.

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
	Send an HTTP_REQUEST event of type ConnectedDeviceSystem.

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
	Send an HTTP_RESPONSE event of type ConnectedDeviceSystem.

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

**nrEnableHttpEvents**

```
function nrEnableHttpEvents(nr as Object) as Void

Description:
	Enable HTTP_CONNECT/HTTP_COMPLETE events.

Arguments:
	nr: New Relic Agent object.
	
Return:
	Nothing.
		
Example:

	nrEnableHttpEvents(nr)
```

**nrDisableHttpEvents**

```
function nrDisableHttpEvents(nr as Object) as Void

Description:
	Disable HTTP_CONNECT/HTTP_COMPLETE events.

Arguments:
	nr: New Relic Agent object.
	
Return:
	Nothing.
		
Example:

	nrDisableHttpEvents(nr)
```

**nrSetHarvestTime**

```
nrSetHarvestTime(nr as Object, time as Integer) as Void

Description:
	Set harvest time, the time the samples are buffered before being sent to New Relic for both Events and Logs. Min value is 60.

Arguments:
	nr: New Relic Agent object.
	time: Time in seconds.
	
Return:
	Nothing.
		
Example:

	nrSetHarvestTime(m.nr, 60)
```

**nrSetHarvestTimeEvents**

```
nrSetHarvestTimeEvents(nr as Object, time as Integer) as Void

Description:
	Set harvest time for Events, the time the events are buffered before being sent to New Relic. Min value is 60.

Arguments:
	nr: New Relic Agent object.
	time: Time in seconds.
	
Return:
	Nothing.
		
Example:

	nrSetHarvestTimeEvents(m.nr, 60)
```

**nrSetHarvestTimeLogs**

```
nrSetHarvestTimeLogs(nr as Object, time as Integer) as Void

Description:
	Set harvest time for Logs, the time the logs are buffered before being sent to New Relic. Min value is 60.

Arguments:
	nr: New Relic Agent object.
	time: Time in seconds.
	
Return:
	Nothing.
		
Example:

	nrSetHarvestTimeLogs(m.nr, 60)
```

**nrSetHarvestTimeMetrics**

```
nrSetHarvestTimeMetrics(nr as Object, time as Integer) as Void

Description:
	Set harvest time for Metrics, the time the metrics are buffered before being sent to New Relic. Min value is 60.

Arguments:
	nr: New Relic Agent object.
	time: Time in seconds.
	
Return:
	Nothing.
		
Example:

	nrSetHarvestTimeMetrics(m.nr, 60)
```

**nrForceHarvest**

```
nrForceHarvest(nr as Object) as Void

Description:
	Do harvest events and logs immediately. It doesn't reset the harvest timer.

Arguments:
	nr: New Relic Agent object.
	
Return:
	Nothing.
		
Example:

	nrForceHarvest(m.nr)
```

**nrForceHarvestEvents**

```
nrForceHarvestEvents(nr as Object) as Void

Description:
	Do harvest events immediately. It doesn't reset the harvest timer.

Arguments:
	nr: New Relic Agent object.
	
Return:
	Nothing.
		
Example:

	nrForceHarvestEvents(m.nr)
```

**nrForceHarvestLogs**

```
nrForceHarvestLogs(nr as Object) as Void

Description:
	Do harvest logs immediately. It doesn't reset the harvest timer.

Arguments:
	nr: New Relic Agent object.
	
Return:
	Nothing.
		
Example:

	nrForceHarvestLogs(m.nr)
```

**nrUpdateConfig**

```
nrUpdateConfig(nr as Object, config as Object) as Void

Description:
	Updates configuration, such as network proxy URL.

Arguments:
	nr: New Relic Agent object
	config: configuration object

Return:
	Nothing

Example:
	config = { proxyUrl: "http://example.com:8888/;" }
	nrUpdateConfig(m.nr, config)
```

**nrAddDomainSubstitution**

```
nrAddDomainSubstitution(nr as object, pattern as String, subs as String) as Void

Description:
	Add a matching pattern for the domain attribute and substitute it by another string.
	Every time an event or metric is generated with a domain attribute, tha agent will check if it matches a regex and will apply the specified substitution. If no pattern is set, it will use the URL domain unchanged.
	It applies to all events and metrics containing the "domain" attribute.

Arguments:
	nr: New Relic Agent object
	pattern: Regex pattern.
	subs: Substitution string.

Return:
	Nothing

Example:
	nrAddDomainSubstitution(nr, "^.+\.my\.domain\.com$", "mydomain.com")
```

**nrDelDomainSubstitution**

```
nrDelDomainSubstitution(nr as object, pattern as String) as Void

Description:
	Delete a matching pattern created with `nrAddDomainSubstitution`.

Arguments:
	nr: New Relic Agent object
	pattern: Regex pattern.

Return:
	Nothing

Example:
	nrDelDomainSubstitution(nr, "^.+\.my\.domain\.com$")
```

**nrSendLog**
```
nrSendLog(nr as Object, message as String, logtype as String, fields = invalid as Object) as Void

Description:
	Record a log using the New Relic Log API.

Arguments:
	nr: New Relic Agent object
	message: Log message.
	logtype: Log type.
	fields: (optional) Additonal fields to be included in the log.

Return:
	Nothing

Example:
	nrSendLog(m.nr, "This is a log", "console", {"key": "value"})
```

**nrSendMetric**
```
function nrSendMetric(nr as Object, name as String, value as dynamic, attr = invalid as Object) as Void

Description:
	Record a gauge metric. Represents a value that can increase or decrease with time.

Arguments:
	nr: New Relic Agent object.
	name: Metric name
	value: Metric value. Number.
	attr: (optional) Metric attributes.

Return:
	Nothing

Example:
	nrSendMetric(m.nr, "test", 11.1, {"one": 1})
```

**nrSendCountMetric**
```
function nrSendCountMetric(nr as Object, name as String, value as dynamic, interval as Integer, attr = invalid as Object) as Void

Description:
	Record a count metric. Measures the number of occurences of an event during a time interval.

Arguments:
	nr: New Relic Agent object.
	name: Metric name
	value: Metric value. Number.
	interval: Metric time interval in milliseconds.
	attr: (optional) Metric attributes.

Return:
	Nothing
	
Example:
	nrSendCountMetric(m.nr, "test", 250, 1500, {"one": 1})
```

**nrSendSummaryMetric**
```
function nrSendSummaryMetric(nr as Object, name as String, interval as Integer, counter as dynamic, m_sum as dynamic, m_min as dynamic, m_max as dynamic, attr = invalid as Object) as Void

Description:
	Record a summary metric. Used to report pre-aggregated data, or information on aggregated discrete events.

Arguments:
	nr: New Relic Agent object.
	name: Metric name
	interval: Metric time interval in milliseconds.
	count: Metric count.
	m_sum: Metric value summation.
	m_min: Metric minimum value.
	m_max: Metric maximum value.
	attr: (optional) Metric attributes.

Return:
	Nothing.

Example:
	nrSendSummaryMetric(m.nr, "test", 2000, 5, 1000, 100, 200)
```

**nrSetUserId**

```
nrSetUserId(userId as String) as Void

Description:
	Sets userId.

Arguments:
	nr: New Relic Agent object.
	userId: attribute
	
Return:
	Nothing.
		
Example:
	nrSetUserId(m.nr, "TEST_USER")
```

<a name="data-model"></a>
### Data Model
To understand which actions and attributes are captured and emitted by the Dash Player under different event types, see [DataModel.md](./DATAMODEL.md).

<a name="ad-track"></a>
### Ad Tracking

The Roku Video Agent also provides Ad events monitoring. Currently we support two different Ad APIs: [Roku Advertising Framework (RAF)](https://developer.roku.com/en-gb/docs/developer-program/advertising/roku-advertising-framework.md) and [Google IMA](https://developers.google.com/interactive-media-ads/docs/sdks/roku).

#### Installation

For RAF there is no additional steps required, because the tracker is integrated inside the NRAgent, but for IMA, the following files must be included in the project:

```
components/NewRelicAgent/trackers
	IMATracker.brs
	IMATracker.xml
source/
	IMATrackerInterface.brs
```

#### RAF Usage

First we have to pass the NRAgent object (created with the call to `NewRelic(accountId, apiKey)`) to the Ads Task. This can be achieved using a field. Once done, inside the Ads Task we must do:

```brightscript
adIface = Roku_Ads()

' Ad Iface setup code...

logFunc = Function(obj = Invalid as Dynamic, evtType = invalid as Dynamic, ctx = invalid as Dynamic)
    'Call RAF tracker, passing the event and context
    nrTrackRAF(obj, evtType, ctx)
End Function

' m.top.nr is the reference to the field where we have the NRAgent object
adIface.setTrackingCallback(logFunc, m.top.nr)
```

For a complete usage example, checkout files `VideoScene.brs` (function `setupVideoWithAds()`) and `AdsTask.brs` in the present repo.

#### IMA Usage

First we have to create the IMA Tracker object:

```brightscript
tracker = IMATracker(m.nr)
```

Where `m.nr` is the NRAgent object.

Then we need to pass the tracker object to the IMA SDK Task, using a field. And include the script `IMATrackerInterface.brs` in the task XML.

Once done, inside the task we must do:

```brightscript
m.player.adBreakStarted = Function(adBreakInfo as Object)
	'Ad break start code...
	    
	'Send AD_BREAK_START
	nrSendIMAAdBreakStart(m.top.tracker, adBreakInfo)
End Function
m.player.adBreakEnded = Function(adBreakInfo as Object)
	'Ad break end code...
    
    'Send AD_BREAK_END
    nrSendIMAAdBreakEnd(m.top.tracker, adBreakInfo)
End Function

'...

m.streamManager.addEventListener(m.sdk.AdEvent.START, startCallback)
m.streamManager.addEventListener(m.sdk.AdEvent.FIRST_QUARTILE, firstQuartileCallback)
m.streamManager.addEventListener(m.sdk.AdEvent.MIDPOINT, midpointCallback)
m.streamManager.addEventListener(m.sdk.AdEvent.THIRD_QUARTILE, thirdQuartileCallback)
m.streamManager.addEventListener(m.sdk.AdEvent.COMPLETE, completeCallback)

Function startCallback(ad as Object) as Void
	'Send AD_START
	nrSendIMAAdStart(m.top.tracker, ad)
End Function

Function firstQuartileCallback(ad as Object) as Void
	'Send AD_QUARTILE (first)
	nrSendIMAAdFirstQuartile(m.top.tracker, ad)
End Function

Function midpointCallback(ad as Object) as Void
	'Send AD_QUARTILE (midpoint)
	nrSendIMAAdMidpoint(m.top.tracker, ad)
End Function

Function thirdQuartileCallback(ad as Object) as Void
	'Send AD_QUARTILE (third)
	nrSendIMAAdThirdQuartile(m.top.tracker, ad)
End Function

Function completeCallback(ad as Object) as Void
	'Send AD_END
	nrSendIMAAdEnd(m.top.tracker, ad)
End Function
```

Where `m.top.tracker` is the tracker object passed to the task.

For a complete usage example, checkout files `VideoScene.brs` (function `setupVideoWithIMA()`) and `imasdk.brs` in the present repo.

### Testing

To run the unit tests, first copy the file `UnitTestFramework.brs` from [unit-testing-framework](https://github.com/rokudev/unit-testing-framework) to `source/testFramework/`. Then install the demo channel provided in the present repo and from a terminal run:

```bash
./test.sh ROKU_IP
```

Where `ROKU_IP` is the address of the Roku device where the channel is installed. Connect to the debug terminal (port 8085) to see test results. You can also provide the dev password as a second argument if you want to compile and deploy before running tests.

### Debugging
Network proxying is supported using URL re-write (see [App Level Proxying](https://rokulikeahurricane.io/proxying_network_requests)). To send all network requests via a proxy call `nrUpdateConfig()` function with the `proxyUrl` parameter object property. Be sure to specify the same URL delimiter as your proxy re-write rule.

<a name="open-source"></a>

# Open source license

This project is distributed under the [Apache 2 license](LICENSE).

<a name="support"></a>

# Support

New Relic has open-sourced this project. This project is provided AS-IS WITHOUT WARRANTY OR DEDICATED SUPPORT. Issues and contributions should be reported to the project here on GitHub.

We encourage you to bring your experiences and questions to the [Explorers Hub](https://discuss.newrelic.com) where our community members collaborate on solutions and new ideas.

## Community

New Relic hosts and moderates an online forum where customers can interact with New Relic employees as well as other customers to get help and share best practices. Like all official New Relic open source projects, there's a related Community topic in the New Relic Explorers Hub. You can find this project's topic/threads here:

https://discuss.newrelic.com/t/new-relic-open-source-roku-agent/97802

## Issues / enhancement requests

Issues and enhancement requests can be submitted in the [Issues tab of this repository](https://github.com/newrelic/video-agent-roku/issues). Please search for and review the existing open issues before submitting a new issue.

<a name="contributing"></a>

# Contributing

Contributions are encouraged! If you submit an enhancement request, we'll invite you to contribute the change yourself. Please review our [Contributors Guide](CONTRIBUTING.md).

Keep in mind that when you submit your pull request, you'll need to sign the CLA via the click-through using CLA-Assistant. If you'd like to execute our corporate CLA, or if you have any questions, please drop us an email at opensource+videoagent@newrelic.com.
