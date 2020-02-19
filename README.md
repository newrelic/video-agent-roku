# New Relic Roku Agent

The New Relic Roku Agent tracks the behavior of a Roku App. It contains two parts, one to monitor general system level events (essentially networking) and one to monitor video related events (for apps that use a video player).  The events and attributes captured by the New Relic Roku Agent can be viewed  [here](https://docs.google.com/document/d/1Yaw6iaC-4PWWepKav3-GO9AnEx1hErC4DKKxIafQxs0/edit?usp=sharing).

Internally, it uses the Insights API to send events using the REST interface. It sends two types of events: RokuSystem for system events and RokuVideo for video events. After the agent has sent some data you will be able to see it in Insights with a simple NRQL request like:

```
SELECT * FROM RokuSystem, RokuVideo
```

### Requirements

Sending both system events and video events requires an Insights Pro subscription.   Insights Free accounts permit only one event type per API key.   If you are using an Insights Free account, you can enable only one type of Roku event capture at a time (system or video).

To initialize the agent you need an ACCOUNT ID and an API KEY. 

The ACCOUNT ID indicates the New Relic account to which you would like to send the Roku data.   For example, https://insights.newrelic.com/accounts/xxx.  Where “xxx” is the Account ID.

To register the API Key, follow the instructions found [here](https://docs.newrelic.com/docs/insights/insights-data-sources/custom-data/send-custom-events-event-api#register).

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

### Usage

To enable automatic event capture perform the following steps which are detailed below.

1. Call `NewRelic` from Main subroutine and store the returned object.
2. Right after that, call `nrAppStarted` (optional but recommended).
3. Call `NewRelicSystemStart` and `NewRelicVideoStart` to start capturing events for system and video (both optional).
4. Inside the main wait loop, call `nrProcessMessage` (only mandatory to capture system events, otherwise not necessary).

#### Example

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

### Interface Functions

To interact with the New Relic Agent it provides a set of functions that wrap internal behaviours. All wrappers are implemented inside NewRelixAgent.brs and all include inline documentation.

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
```

```
NewRelicSystemStart(port as Object) as Object

Description:
	Start system logging.

Arguments:
	port: A message port.
	
Return:
	The roSystemLog object created.
```

```
NewRelicVideoStart(nr as Object, video as Object) as Void

Description:
	Start video logging.

Arguments:
	nr: New Relic Agent object.
	video: A video object.
	
Return:
	Nothing.
```

```
nrProcessMessage(nr as Object, msg as Object) as Boolean

Description:
	Check for a system log message, process it and sends the appropriate event.

Arguments:
	nr: New Relic Agent object.
	msg: A message of type roSystemLogEvent.
	
Return:
	True if msg is a system log message, False otherwise.
```

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
```

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
```

```
nrAppStarted(nr as Object, obj as Object) as Void

Description:
	Send an APP_STARTED event of type RokuSystem.

Arguments:
	nr: New Relic Agent object.
	obj: The object sent as argument of Main subroutine.
	
Return:
	Nothing.
```

```
nrSceneLoaded(nr as Object, sceneName as String) as Void

Description:
	Send a SCENE_LOADED event of type RokuSystem.

Arguments:
	nr: New Relic Agent object.
	sceneName: The scene name.
	
Return:
	Nothing.
```

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
```

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
```

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
```

```
nrSendHttpRequest(nr as Object, urlReq as Object) as Void

Description:
	Send an HTTP_REQUEST event of type RokuSystem.

Arguments:
	nr: New Relic Agent object.
	urlReq: URL request, roUrlTransfer object.
	
Return:
	Nothing.
```

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
```

```
nrSetHarvestTime(nr as Object, time as Integer) as Void

Description:
	Set harvest time, the time the events are buffered before being sent to Insights.

Arguments:
	nr: New Relic Agent object.
	time: Time in seconds.
	
Return:
	Nothing.
```

```
nrForceHarvest(nr as Object) as Void

Description:
	Do harvest immediately. It doesn't reset the harvest timer.

Arguments:
	nr: New Relic Agent object.
	
Return:
	Nothing.
```
