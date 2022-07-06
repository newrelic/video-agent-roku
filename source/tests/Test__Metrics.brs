Function TestSuite__Metrics() as Object

    ' Inherite your test suite from BaseTestSuite
    this = BaseTestSuite()

    ' Test suite name for metric statistics
    this.Name = "MetricsTestSuite"

    this.SetUp = MetricsTestSuite__SetUp
    this.TearDown = MetricsTestSuite__TearDown

    ' Add tests to suite's tests collection
    this.addTest("CustomMetrics", TestCase__Metrics_CustomMetrics)

    return this
End Function

Sub MetricsTestSuite__SetUp()
    print "Metrics SetUp"
    ' Setup New Relic Agent
    if m.nr = invalid
        m.nr = NewRelic("ACCOUNT_ID", "API_KEY", "US", true)
    end if
    ' Disable harvest timer
    nrHarvestTimerMetrics = m.nr.findNode("nrHarvestTimerMetrics")
    nrHarvestTimerMetrics.control = "stop"
End Sub

Sub MetricsTestSuite__TearDown()
    print "Metrics TearDown"
End Sub

Function TestCase__Metrics_CustomMetrics() as String
    print "Checking custom metrics..."
    
    nrSendMetric(m.nr, "test", 11.1, {"one": 1})
    nrSendCountMetric(m.nr, "testCount", 99.9, 1500)
    nrSendSummaryMetric(m.nr, "testSummary", 2000, 5, 1000, 100, 200)

    metrics = m.nr.callFunc("nrExtractAllSamples", "metric")
    return multiAssert([
        m.assertArrayCount(metrics, 3)
        'First metric
        m.assertEqual(metrics[0].name, "test")
        m.assertEqual(metrics[0].type, "gauge")
        m.assertEqual(metrics[0].value, 11.1)
        m.assertNotInvalid(metrics[0].attributes)
        m.assertEqual(metrics[0].attributes["one"], 1)
        'Second metric
        m.assertEqual(metrics[1].name, "testCount")
        m.assertEqual(metrics[1].type, "count")
        m.assertEqual(metrics[1].value, 99.9)
        m.assertEqual(metrics[1]["interval.ms"], 1500)
        m.assertInvalid(metrics[1].attributes)
        'Third metric
        m.assertEqual(metrics[2].name, "testSummary")
        m.assertEqual(metrics[2].type, "summary")
        m.assertEqual(metrics[2]["interval.ms"], 2000)
        m.assertInvalid(metrics[2].attributes)
        m.assertNotInvalid(metrics[2].value)
        m.assertEqual(metrics[2].value.count, 5)
        m.assertEqual(metrics[2].value.sum, 1000)
        m.assertEqual(metrics[2].value.min, 100)
        m.assertEqual(metrics[2].value.max, 200)
    ])
End Function
