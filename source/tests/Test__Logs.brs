Function TestSuite__Logs() as Object

    ' Inherite your test suite from BaseTestSuite
    this = BaseTestSuite()

    ' Test suite name for log statistics
    this.Name = "LogsTestSuite"

    this.SetUp = LogsTestSuite__SetUp
    this.TearDown = LogsTestSuite__TearDown

    ' Add tests to suite's tests collection
    this.addTest("CustomLogs", TestCase__Logs_CustomLogs)

    return this
End Function

Sub LogsTestSuite__SetUp()
    print "Logs SetUp"
    ' Setup New Relic Agent
    if m.nr = invalid
        m.nr = NewRelic("ACCOUNT_ID", "API_KEY", "US", true)
    end if
    ' Disable harvest timer
    nrHarvestTimerLogs = m.nr.findNode("nrHarvestTimerLogs")
    nrHarvestTimerLogs.control = "stop"
End Sub

Sub LogsTestSuite__TearDown()
    print "Logs TearDown"
End Sub

Function TestCase__Logs_CustomLogs() as String
    print "Checking custom logs..."
    
    nrSendLog(m.nr, "This is a log", "test", {"one": 1, "name": "Andreu"})
    logs = m.nr.callFunc("nrExtractAllSamples", "log")
    return multiAssert([
        m.assertArrayCount(logs, 1)
        m.assertEqual(logs[0].message, "This is a log")
        m.assertEqual(logs[0].logtype, "test")
        m.assertEqual(logs[0].one, 1)
        m.assertEqual(logs[0].name, "Andreu")
    ])
End Function
