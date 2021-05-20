Function TestSuite__Main() as Object

    ' Inherite your test suite from BaseTestSuite
    this = BaseTestSuite()

    ' Test suite name for log statistics
    this.Name = "MainTestSuite"

    this.SetUp = MainTestSuite__SetUp
    this.TearDown = MainTestSuite__TearDown

    ' Add tests to suite's tests collection
    this.addTest("CustomEvents", TestCase__Main_CustomEvents)

    return this
End Function

Function multiAssert(arr as Object) as String
    for each assert in arr
        if assert <> "" return assert
    end for
    return ""
End Function

Sub MainTestSuite__SetUp()
    print "SetUp"

    ' Setup New Relic Agent
    m.nr = NewRelic("ACCOUNT_ID", "API_KEY", true)
    ' Disable harvest timer
    nrHarvestTimer = m.nr.findNode("nrHarvestTimer")
    nrHarvestTimer.control = "stop"
End Sub

Sub MainTestSuite__TearDown()
    print "TearDown"
End Sub

Function TestCase__Main_CustomEvents() as String
    print "Checking custom events..."
    
    nrSendSystemEvent(m.nr, "TEST_SYSTEM_EVENT")
    events = m.nr.callFunc("nrExtractAllEvents")

    x = m.assertArrayCount(events, 1)
    if x <> "" then return x

    ev = events[0]
    
    return multiAssert([
        m.assertEqual(ev.actionName, "TEST_SYSTEM_EVENT")
        m.assertNotInvalid(ev.timeSinceLoad)
        m.assertEqual(ev.timeSinceLoad, 0)
    ])
End Function
