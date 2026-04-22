Function TestSuite__Obfuscation() as Object

    this = BaseTestSuite()
    this.Name = "ObfuscationTestSuite"

    this.SetUp = ObfuscationTestSuite__SetUp
    this.TearDown = ObfuscationTestSuite__TearDown

    ' --- Happy path ---
    this.addTest("NoRulesConfigured",          TestCase__Obfuscation_NoRulesConfigured)
    this.addTest("BasicMasking",               TestCase__Obfuscation_BasicMasking)
    this.addTest("MultipleRules",              TestCase__Obfuscation_MultipleRules)
    this.addTest("RulesAppliedInOrder",        TestCase__Obfuscation_RulesAppliedInOrder)
    this.addTest("NonStringValuesUnchanged",   TestCase__Obfuscation_NonStringValuesUnchanged)
    this.addTest("NoMatch",                    TestCase__Obfuscation_NoMatch)
    this.addTest("EmptyReplacement",           TestCase__Obfuscation_EmptyReplacement)
    this.addTest("HttpsUrlMasking",            TestCase__Obfuscation_HttpsUrlMasking)
    this.addTest("PartialMatch",               TestCase__Obfuscation_PartialMatch)
    this.addTest("ClearRules",                 TestCase__Obfuscation_ClearRules)

    ' --- Validation / rejection at registration time ---
    this.addTest("InvalidRegexRejected",        TestCase__Obfuscation_InvalidRegexRejected)
    this.addTest("EmptyRegexRejected",          TestCase__Obfuscation_EmptyRegexRejected)
    this.addTest("MissingReplacementRejected",  TestCase__Obfuscation_MissingReplacementRejected)
    this.addTest("RuleNotObjectRejected",       TestCase__Obfuscation_RuleNotObjectRejected)
    this.addTest("RulesNotArrayRejected",       TestCase__Obfuscation_RulesNotArrayRejected)
    this.addTest("NonStringRegexRejected",      TestCase__Obfuscation_NonStringRegexRejected)

    return this
End Function

'================================================================
' SetUp / TearDown
'================================================================

Sub ObfuscationTestSuite__SetUp()
    print "Obfuscation SetUp"
    if m.nr = invalid
        m.nr = NewRelic("ACCOUNT_ID", "API_KEY", "APP_NAME", "APP_TOKEN", "US", true)
    end if
    ' Stop harvest timer so events stay in the buffer until we extract them
    nrHarvestTimerEvents = m.nr.findNode("nrHarvestTimerEvents")
    nrHarvestTimerEvents.control = "stop"
    ' Clear any rules left by a previous test
    nrSetObfuscationRules(m.nr, [])
    ' Drain any events left in the buffer
    m.nr.callFunc("nrExtractAllSamples", "event")
End Sub

Sub ObfuscationTestSuite__TearDown()
    print "Obfuscation TearDown"
    nrSetObfuscationRules(m.nr, [])
End Sub

'================================================================
' Helper — record a crafted event and return the buffered copy
'================================================================

Function ObfuscationSuite__FireAndExtract(mm as Object, attrs as Object) as Object
    event = { "eventType": "TestAction", "actionName": "TEST_OBFUSCATION" }
    if attrs <> invalid then event.Append(attrs)
    mm.nr.callFunc("nrRecordEvent", event)
    events = mm.nr.callFunc("nrExtractAllSamples", "event")
    if events.Count() = 0 then return invalid
    return events[0]
End Function

'================================================================
' Happy path tests
'================================================================

' 1. No rules — event passes through completely unchanged
Function TestCase__Obfuscation_NoRulesConfigured() as String
    print "Checking no rules configured..."
    ev = ObfuscationSuite__FireAndExtract(m, { "url": "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8" })
    return multiAssert([
        m.assertNotInvalid(ev)
        m.assertEqual(ev.url, "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8")
    ])
End Function

' 2. Single rule replaces the matched portion of a string value
Function TestCase__Obfuscation_BasicMasking() as String
    print "Checking basic masking..."
    nrSetObfuscationRules(m.nr, [
        { regex: "account-[0-9]+", replacement: "ACCOUNT_ID" }
    ])
    ev = ObfuscationSuite__FireAndExtract(m, { "info": "user account-12345 info" })
    return multiAssert([
        m.assertNotInvalid(ev)
        m.assertEqual(ev.info, "user ACCOUNT_ID info")
    ])
End Function

' 3. Multiple rules — each rule applied to every string attribute in order
Function TestCase__Obfuscation_MultipleRules() as String
    print "Checking multiple rules..."
    nrSetObfuscationRules(m.nr, [
        { regex: "account-[0-9]+", replacement: "ACCOUNT_ID" },
        { regex: "token=[^&]+",    replacement: "token=REDACTED" }
    ])
    ev = ObfuscationSuite__FireAndExtract(m, {
        "info": "account-99 with token=secret123&other=val"
    })
    return multiAssert([
        m.assertNotInvalid(ev)
        m.assertEqual(ev.info, "ACCOUNT_ID with token=REDACTED&other=val")
    ])
End Function

' 4. Rules run in order — output of rule N is the input to rule N+1
Function TestCase__Obfuscation_RulesAppliedInOrder() as String
    print "Checking rules applied in order..."
    nrSetObfuscationRules(m.nr, [
        { regex: "secret",  replacement: "MASKED" },
        { regex: "MASKED",  replacement: "DOUBLE_MASKED" }
    ])
    ev = ObfuscationSuite__FireAndExtract(m, { "field": "secret" })
    return multiAssert([
        m.assertNotInvalid(ev)
        m.assertEqual(ev.field, "DOUBLE_MASKED")
    ])
End Function

' 5. Integer and boolean attribute values are never touched
Function TestCase__Obfuscation_NonStringValuesUnchanged() as String
    print "Checking non-string values unchanged..."
    nrSetObfuscationRules(m.nr, [
        { regex: ".*", replacement: "REDACTED" }
    ])
    ev = ObfuscationSuite__FireAndExtract(m, { "numAttr": 42, "boolAttr": true })
    return multiAssert([
        m.assertNotInvalid(ev)
        m.assertEqual(ev.numAttr, 42)
        m.assertEqual(ev.boolAttr, true)
    ])
End Function

' 6. Rule that does not match — string value is left exactly as-is
Function TestCase__Obfuscation_NoMatch() as String
    print "Checking no match leaves value unchanged..."
    nrSetObfuscationRules(m.nr, [
        { regex: "account-[0-9]+", replacement: "ACCOUNT_ID" }
    ])
    ev = ObfuscationSuite__FireAndExtract(m, { "info": "no sensitive data here" })
    return multiAssert([
        m.assertNotInvalid(ev)
        m.assertEqual(ev.info, "no sensitive data here")
    ])
End Function

' 7. Empty replacement string — matched content is deleted from the value
Function TestCase__Obfuscation_EmptyReplacement() as String
    print "Checking empty replacement deletes matched content..."
    nrSetObfuscationRules(m.nr, [
        { regex: "secret", replacement: "" }
    ])
    ev = ObfuscationSuite__FireAndExtract(m, { "field": "mysecretvalue" })
    return multiAssert([
        m.assertNotInvalid(ev)
        m.assertEqual(ev.field, "myvalue")
    ])
End Function

' 8. Full HTTPS URL (including query string) is replaced in one shot
Function TestCase__Obfuscation_HttpsUrlMasking() as String
    print "Checking HTTPS URL masking..."
    nrSetObfuscationRules(m.nr, [
        { regex: "https://.*", replacement: "REDACTED_URL" }
    ])
    ev = ObfuscationSuite__FireAndExtract(m, {
        "contentSrc": "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8?token=abc123&quality=high"
    })
    return multiAssert([
        m.assertNotInvalid(ev)
        m.assertEqual(ev.contentSrc, "REDACTED_URL")
    ])
End Function

' 9. Only the matched portion is replaced; surrounding text is kept intact
Function TestCase__Obfuscation_PartialMatch() as String
    print "Checking partial match preserves surrounding text..."
    nrSetObfuscationRules(m.nr, [
        { regex: "/users/[^/]+", replacement: "/users/USER_ID" }
    ])
    ev = ObfuscationSuite__FireAndExtract(m, {
        "path": "https://api.example.com/users/john.doe/profile"
    })
    return multiAssert([
        m.assertNotInvalid(ev)
        m.assertEqual(ev.path, "https://api.example.com/users/USER_ID/profile")
    ])
End Function

' 10. Clearing rules with [] stops all masking
Function TestCase__Obfuscation_ClearRules() as String
    print "Checking clearing rules stops masking..."
    nrSetObfuscationRules(m.nr, [
        { regex: "account-[0-9]+", replacement: "ACCOUNT_ID" }
    ])
    ' Confirm masking is active before clearing
    ev = ObfuscationSuite__FireAndExtract(m, { "field": "account-99" })
    if ev.field <> "ACCOUNT_ID" then return "Rules were not applied before clearing"

    ' Clear all rules
    nrSetObfuscationRules(m.nr, [])

    ' Confirm value is no longer masked
    ev = ObfuscationSuite__FireAndExtract(m, { "field": "account-99" })
    return multiAssert([
        m.assertNotInvalid(ev)
        m.assertEqual(ev.field, "account-99")
    ])
End Function

'================================================================
' Validation / rejection tests
' All expect: nrSetObfuscationRules rejects the bad input, rules
' remain as [] (from setUp), and sensitive values pass through.
'================================================================

' 11. Malformed regex pattern — entire rule set rejected
Function TestCase__Obfuscation_InvalidRegexRejected() as String
    print "Checking invalid regex pattern rejected at registration..."
    nrSetObfuscationRules(m.nr, [
        { regex: "[unclosed", replacement: "X" }
    ])
    ev = ObfuscationSuite__FireAndExtract(m, { "field": "account-99" })
    return multiAssert([
        m.assertNotInvalid(ev)
        m.assertEqual(ev.field, "account-99")
    ])
End Function

' 12. Empty regex string — rule set rejected
Function TestCase__Obfuscation_EmptyRegexRejected() as String
    print "Checking empty regex string rejected at registration..."
    nrSetObfuscationRules(m.nr, [
        { regex: "", replacement: "X" }
    ])
    ev = ObfuscationSuite__FireAndExtract(m, { "field": "test" })
    return multiAssert([
        m.assertNotInvalid(ev)
        m.assertEqual(ev.field, "test")
    ])
End Function

' 13. Rule is missing the replacement key — rule set rejected
Function TestCase__Obfuscation_MissingReplacementRejected() as String
    print "Checking rule with missing replacement key rejected..."
    nrSetObfuscationRules(m.nr, [
        { regex: "account-[0-9]+" }
    ])
    ev = ObfuscationSuite__FireAndExtract(m, { "field": "account-99" })
    return multiAssert([
        m.assertNotInvalid(ev)
        m.assertEqual(ev.field, "account-99")
    ])
End Function

' 14. A rule is a plain string instead of an object — rule set rejected
Function TestCase__Obfuscation_RuleNotObjectRejected() as String
    print "Checking non-object rule rejected..."
    nrSetObfuscationRules(m.nr, ["not-an-object"])
    ev = ObfuscationSuite__FireAndExtract(m, { "field": "test" })
    return multiAssert([
        m.assertNotInvalid(ev)
        m.assertEqual(ev.field, "test")
    ])
End Function

' 15. Rules argument is an associative array, not an array — rejected
Function TestCase__Obfuscation_RulesNotArrayRejected() as String
    print "Checking non-array rules argument rejected..."
    nrSetObfuscationRules(m.nr, { regex: "account-[0-9]+", replacement: "X" })
    ev = ObfuscationSuite__FireAndExtract(m, { "field": "account-99" })
    return multiAssert([
        m.assertNotInvalid(ev)
        m.assertEqual(ev.field, "account-99")
    ])
End Function

' 16. regex value is an integer instead of a String — rule set rejected
Function TestCase__Obfuscation_NonStringRegexRejected() as String
    print "Checking non-string regex value rejected..."
    nrSetObfuscationRules(m.nr, [
        { regex: 123, replacement: "X" }
    ])
    ev = ObfuscationSuite__FireAndExtract(m, { "field": "123" })
    return multiAssert([
        m.assertNotInvalid(ev)
        m.assertEqual(ev.field, "123")
    ])
End Function
