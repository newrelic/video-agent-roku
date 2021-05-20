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

    event = events[0]
    
    x = m.assertEqual(event.actionName, "TEST_SYSTEM_EVENT")
    if x <> "" then return x
    
    x = m.assertNotInvalid(event.timeSinceLoad)
    if x <> "" then return x

    x = m.assertEqual(event.timeSinceLoad, 0)
    if x <> "" then return x
    
    return ""
End Function
