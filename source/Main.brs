'NR Video Agent Example - Main'

sub RunUserInterface(args)
    if args.RunTests = "true" and type(TestRunner) = "Function" then
        print "Run tests"
        Runner = TestRunner()

        Runner.SetFunctions([
            TestSuite__Main
            TestSuite__Logs
            TestSuite__Metrics
        ])

        Runner.Logger.SetVerbosity(3)
        Runner.Logger.SetEcho(false)
        Runner.Logger.SetJUnit(false)
        Runner.SetFailFast(true)
        
        Runner.Run()
    else
        Main(args)
    end if
end sub

sub Main(aa as Object)
    screen = CreateObject("roSGScreen")
    m.port = CreateObject("roMessagePort")
    screen.setMessagePort(m.port)
    
    scene = screen.CreateScene("VideoScene")
    screen.show()

    'Test harness launch params (ECP: /launch/dev?scenario=..&src=..&logLevel=..&mtUrl=..&seekEndAfter=..&flood=..)
    scenario = "unnamed"
    if aa.scenario <> invalid and aa.scenario <> "" then scenario = aa.scenario
    source = "single"
    'ECP overwrites a launch param named "source" with "external-control", so the harness uses "src"
    if aa.src <> invalid and aa.src <> "" then source = LCase(aa.src)
    mtUrl = ""
    if aa.mtUrl <> invalid then mtUrl = aa.mtUrl
    runSeconds = 0
    if aa.runSeconds <> invalid then runSeconds = Val(aa.runSeconds)
    seekEndAfter = 0
    if aa.seekEndAfter <> invalid then seekEndAfter = Val(aa.seekEndAfter)
    'keys=<seconds>:<key>;<seconds>:<key> simulates remote presses (ECP keypress is blocked in Limited mode)
    keyList = []
    if aa.keys <> invalid and aa.keys <> ""
        for each item in aa.keys.Split(";")
            parts = item.Split(":")
            if parts.Count() = 2 then keyList.Push({ t: Val(parts[0]), key: parts[1] })
        end for
    end if
    keyIdx = 0
    'mute=false turns the video audio back on (muted by default so test runs are silent)
    muteVideo = true
    if aa.mute <> invalid and LCase(aa.mute) = "false" then muteVideo = false
    videoMuted = false
    flood = ""
    if aa.flood <> invalid then flood = LCase(aa.flood)
    'activeLogs: false|ERROR|WARNING|INFO|true (ECP delivers strings)
    logLevel = "true"
    if aa.logLevel <> invalid and aa.logLevel <> "" then logLevel = aa.logLevel
    activeLogs = logLevel
    if LCase(logLevel) = "true" then activeLogs = true
    if LCase(logLevel) = "false" then activeLogs = false
    print "[RUN-START] scenario=" + scenario + " source=" + source + " logLevel=" + logLevel
    'Share the params with the scene
    screen.getGlobalNode().addFields({ source: source, mtUrl: mtUrl })
    
    'Init New Relic Agent (FILL YOUR CREDENTIALS, ACCOUNT_ID, API_KEY, APP_NAME and APP_TOKEN)
    'Enable QOE tracking (default): true
    m.nr = NewRelic("YOUR_ACCOUNT_ID", "YOUR_NR_API_KEY", "roku-release/12OCT", "YOUR_NR_APP_TOKEN", "staging", activeLogs)
    
    'Set custom harvest time
    harvestTime = 10
    'Flood scenario: one long window so events pile up in the buffer
    if flood = "events" then harvestTime = 60
    nrSetHarvestTime(m.nr, harvestTime)
    'Tag every event with the run name
    nrSetCustomAttribute(m.nr, "scenarioId", scenario)
    'Enable QOE tracking via runtime API
    nrActivateQoeTracking(m.nr)
    'Set custom QoE aggregate interval multiplier (default is 1, set to 2 to aggregate QoE data in 20s intervals instead of 10s)
    nrSetQoeAggregateIntervalMultiplier(m.nr, 2 )
    'Version 3.0.0 (or above) disables HttpEvents by default
    nrEnableHttpEvents(m.nr)
    'Send APP_STARTED event
    nrAppStarted(m.nr, aa)
    'Send a custom system
    nrSendSystemEvent(m.nr, "ConnectedDeviceSystem","TEST_ACTION")
    
    'Define multiple domain substitutions
    nrAddDomainSubstitution(m.nr, "^www\.google\.com$", "Google COM")
    nrAddDomainSubstitution(m.nr, "^www\.google\.cat$", "Google CAT")
    nrAddDomainSubstitution(m.nr, "^www\.google\.us$", "Google US")
    nrAddDomainSubstitution(m.nr, "^google\.com$", "Google ERROR")
    nrAddDomainSubstitution(m.nr, "^.+\.googleapis\.com$", "Google APIs")
    nrAddDomainSubstitution(m.nr, "^.+\.akamaihd\.net$", "Akamai")
    
    'Pass NewRelicAgent object to scene
    scene.setField("nr", m.nr)
    'Observe scene field "moteButton" to capture "back" button and abort the execution
    scene.observeField("moteButton", m.port)
    
    'Activate system tracking
    m.syslog = NewRelicSystemStart(m.port)

    runSearchTask("hello")

    clock = CreateObject("roTimespan")
    maxSeconds = 160
    if flood = "events" then maxSeconds = 300
    if runSeconds > 0 then maxSeconds = runSeconds
    floodSent = 0
    playClock = invalid
    seeked = false
    ended = false
    endedAt = 0
    flush1 = false
    flush2 = false
    
    while(true)
        msg = wait(500, m.port)

        'Harness timers, driven by the 500ms wait timeout
        elapsed = clock.TotalMilliseconds() / 1000
        video = scene.findNode("myVideo")
        if not ended
            if muteVideo and not videoMuted and video <> invalid
                video.mute = true
                videoMuted = true
                print "[HARNESS] video muted"
            end if
            if seekEndAfter > 0 and not seeked and video <> invalid
                if video.state = "playing" and playClock = invalid then playClock = CreateObject("roTimespan")
                if playClock <> invalid and playClock.TotalMilliseconds() / 1000 >= seekEndAfter and video.duration > 15
                    print "[HARNESS] seek to end-15 (duration=" + Str(video.duration) + ")"
                    video.seek = video.duration - 15
                    seeked = true
                end if
            end if
            if flood = "events" and elapsed >= 20 and floodSent < 460
                'About 12 events per 500ms tick = 460 events in ~20s
                for i = 1 to 12
                    if floodSent < 460
                        floodSent = floodSent + 1
                        nrSendCustomEvent(m.nr, "FloodEvent", { floodIndex: floodSent })
                    end if
                end for
            end if
            if keyIdx < keyList.Count()
                if elapsed >= keyList[keyIdx].t
                    print "[HARNESS-KEY] " + keyList[keyIdx].key + " at " + Str(elapsed).Trim()
                    scene.moteButton = "HARNESS:" + keyList[keyIdx].key
                    keyIdx = keyIdx + 1
                end if
            end if
            if elapsed >= maxSeconds
                ended = true
                endedAt = elapsed
                if video <> invalid then video.control = "stop"
                print "[RUN-END] " + scenario
            end if
        else
            'Harvest is clamped to >= 60s, so flush the tail of the run explicitly
            if not flush1 and elapsed >= endedAt + 3
                flush1 = true
                nrForceHarvest(m.nr)
                print "[RUN-FLUSH] 1 " + scenario
            end if
            if not flush2 and elapsed >= endedAt + 8
                flush2 = true
                nrForceHarvest(m.nr)
                print "[RUN-FLUSH] 2 " + scenario
            end if
        end if
        if msg = invalid then continue while
        
        if nrProcessMessage(m.nr, msg) = false
            'Is not a system message captured by New Relic Agent
            print "Msg = ", msg
            
            if type(msg) = "roSGNodeEvent"
                if msg.getField() = "moteButton"
                    print "moteButton, data = ", msg.getData()
                    if msg.getData() = "back"
                        'Force the view-end QoE flush before exit so the final
                        'QOE_AGGREGATE is emitted (otherwise Back skips state="finished"
                        'and nrSendEnd never fires).
                        m.nr.callFunc("nrSendEnd")
                        exit while
                    end if
                    if msg.getData() = "OK"
                        'force crash
                        print "Crash!"
                        x = invalid
                        x.anyFoo()
                    end if
                end if
            end if
        end if
    end while
end sub

'Test task to show how to generate http events
function runSearchTask(search as String)
    task = createObject("roSGNode", "SearchTask")
    task.setField("nr", m.nr)
    task.setField("searchString", search)
    task.control = "RUN"
end function
