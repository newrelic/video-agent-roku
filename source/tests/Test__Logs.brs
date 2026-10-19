Function TestSuite__Logs() as Object

    ' Inherite your test suite from BaseTestSuite
    this = BaseTestSuite()

    ' Test suite name for log statistics
    this.Name = "LogsTestSuite"

    this.SetUp = LogsTestSuite__SetUp
    this.TearDown = LogsTestSuite__TearDown

    ' Add tests to suite's tests collection
    this.addTest("CustomLogs", TestCase__Logs_CustomLogs)
    this.addTest("DroppedSamplesCounted", TestCase__Logs_DroppedSamplesCounted)
    this.addTest("LoggingLevel", TestCase__Logs_LoggingLevel)
    this.addTest("FillThresholdsDoNotDropSamples", TestCase__Logs_FillThresholdsDoNotDropSamples)

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

Function TestCase__Logs_DroppedSamplesCounted() as String
    print "Checking dropped sample counter..."

    m.nr.callFunc("nrExtractAllSamples", "log")
    before = m.nr.callFunc("nrGetDroppedSamplesCount", "log")
    ' Default log reservoir holds 400 samples, so the last 10 must be overwritten or discarded.
    for i = 1 to 410
        nrSendLog(m.nr, "overflow " + Str(i).Trim(), "test", {})
    end for
    dropped = m.nr.callFunc("nrGetDroppedSamplesCount", "log") - before
    logs = m.nr.callFunc("nrExtractAllSamples", "log")
    return multiAssert([
        m.assertArrayCount(logs, 400)
        m.assertEqual(dropped, 10)
        m.assertEqual(m.nr.callFunc("nrGetDroppedSamplesCount", "bogus"), 0)
    ])
End Function

Function TestCase__Logs_LoggingLevel() as String
    print "Checking activeLogs levels..."

    m.nr.callFunc("nrActivateLogging", true)
    asTrue = [m.nr.callFunc("nrCheckLoggingState"), m.nr.callFunc("nrGetLoggingLevel")]
    m.nr.callFunc("nrActivateLogging", "error")
    asError = [m.nr.callFunc("nrCheckLoggingState"), m.nr.callFunc("nrGetLoggingLevel")]
    m.nr.callFunc("nrActivateLogging", "verbose")
    asInvalid = m.nr.callFunc("nrCheckLoggingState")
    m.nr.callFunc("nrActivateLogging", false)
    asFalse = m.nr.callFunc("nrCheckLoggingState")
    m.nr.callFunc("nrActivateLogging", true)
    return multiAssert([
        m.assertTrue(asTrue[0])
        m.assertEqual(asTrue[1], "INFO")
        m.assertTrue(asError[0])
        m.assertEqual(asError[1], "ERROR")
        m.assertFalse(asInvalid)
        m.assertFalse(asFalse)
    ])
End Function

Function TestCase__Logs_FillThresholdsDoNotDropSamples() as String
    print "Checking fill thresholds keep every sample below capacity..."

    m.nr.callFunc("nrExtractAllSamples", "log")
    before = m.nr.callFunc("nrGetDroppedSamplesCount", "log")
    ' 380 of 400 crosses both the 85% and 90% marks without filling the buffer.
    for i = 1 to 380
        nrSendLog(m.nr, "fill " + Str(i).Trim(), "test", {})
    end for
    dropped = m.nr.callFunc("nrGetDroppedSamplesCount", "log") - before
    logs = m.nr.callFunc("nrExtractAllSamples", "log")
    return multiAssert([
        m.assertArrayCount(logs, 380)
        m.assertEqual(dropped, 0)
    ])
End Function
