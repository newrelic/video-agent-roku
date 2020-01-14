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
components/
	NRTask.xml
source/newrelic/
	NRAgent.brs
	NRUtils.brs
```

2. Open your Roku app project’s directory and copy the “NRTask.xml” to “components” folder and “newrelic” folder to “source” folder.

### Usage

To enable automatic event capture perform the following steps which are detailed below.

1. Add NewRelicInit() with arguments to sub Main()
2. Add a waitFunction in place of the wait event loop
3. Add two `<script>` tags to each Scene component XML
4. Add calls to sub Init() to capture system and video events and attributes

#### 1) Adding NewRelicInit() with arguments to sub Main()
	
	
Inside the “sub Main()” add the following code at the end in place fo the wait event loop :

```
NewRelicInit(“ACCOUNT ID“, “API KEY“, screen)
```

#### 2) Adding a waitFunction in place of the wait event loop
		
After the screen and port initialization. Add this:

```
waitFunction = Function(msg as Object)
	print "msg = " msg
	return true
end function
    
NewRelicWait(m.port, waitFunction)
```

After that, the Main function should look like:

```
sub Main()
	print "Main"

	'The screen and port must be initialized before starting the NewRelic agent
	screen = CreateObject("roSGScreen")
	m.port = CreateObject("roMessagePort")
	screen.setMessagePort(m.port)
    
	NewRelicInit(“ACCOUNT ID“, “API KEY“, screen)
	‘To activate New Relic Agent logs
	nrActivateLogging(true)

	‘Init the first scene
	scene = screen.CreateScene("NRVideoAgentExample")
	screen.show()
    
	waitFunction = Function(msg as Object)
		print "msg = " msg
		return true
	end function
    
	NewRelicWait(m.port, waitFunction)
end sub
```

#### 3) Adding two `<script>` tags to each Scene component XML

Add the following code to any Scene component XML you have in your app:

```
<!-- Setup New Relic Agent -->
<script type="text/brightscript" uri="pkg:/source/newrelic/NRUtils.brs"/>
<script type="text/brightscript" uri="pkg:/source/newrelic/NRAgent.brs"/>
```

#### 4) Adding calls to sub Init() to capture system and video events and attributes

And the following code inside the “sub init()”:

```
 'Start New Relic agents
 NewRelicStart()
 NewRelicVideoStart(video)
```

Where `video` is the Video node.

#### (Optional) Enabling only system or video event capture

Calling NewRelicStart() and NewRelicVideoStart(video) activates event capture for system and video respectively. The agent permits to capture only one type of event, if desired or necessary (e.g. when using an Insights Free account).  

To disable video events and capture only system events, simply omit the call to the NewRelicVideoStart function. 

To capture video events only and not the system events, follow the Usage steps above but do not call the NewRelicWait function. Instead implement your own event loop, like this:

```
sub Main()
    print "Main"

    'The screen and port must be initialized before starting the NewRelic agent
    screen = CreateObject("roSGScreen")
    m.port = CreateObject("roMessagePort")
    screen.setMessagePort(m.port)
    
    NewRelicInit(“ACCOUNT ID“, “API KEY“, screen)
    ‘To activate New Relic Agent logs
    nrActivateLogging(true)

    ‘Init the first scene
    scene = screen.CreateScene("NRVideoAgentExample")
    screen.show()
    
    while(true)
        msg = wait(0, m.port)
        ‘capture any event you need…
    end while
end sub
```
