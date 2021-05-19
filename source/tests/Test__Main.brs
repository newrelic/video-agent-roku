' @BeforeAll
sub MainTestSuite__SetUp()
    print "Setup testsuite"
    m.nr = NewRelic("ACCOUNT_ID", "API_KEY", true)
end sub

' @Test
function TestCase_1() as String
    if m.nr <> invalid
        return "Ok"
    else
        return "Not Ok"
    end if
end function

' @AfterAll
sub MainTestSuite__TearDown()
    print "Teardown testsuit"
end sub
