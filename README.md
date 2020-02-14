# New Relic Roku Agent

The New Relic Roku Agent tracks the behavior of a Roku App. It contains two parts, one to monitor general system level events (essentially networking) and one to monitor video related events (for apps that use a video player).  The events and attributes captured by the New Relic Roku Agent can be viewed here.

Internally, it uses the Insights API to send events using the REST interface. It sends two types of events: RokuSystem for system events and RokuVideo for video events. After the agent has sent some data you will be able to see it in Insights with a simple NRQL request like:

```
SELECT * from RokuSystem, RokuVideo
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
	m.syslog = NewRelicSystemStart(m.nr, m.port)
    
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