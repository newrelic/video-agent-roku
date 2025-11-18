#!/bin/sh

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
    echo
    echo "Usage: $0 Roku_IP [dev_password]"
    echo 
    echo "       If 'dev_password' is provided, it will compile and deploy before running tests."
    echo
    echo "       Test results are automatically captured and displayed!"
    echo
    exit 1
fi

ROKU_IP=$1

if [ $# -eq 2 ]; then
    echo "=========================================="
    echo "DEPLOYING TO ROKU"
    echo "=========================================="
    ./deploy.sh $1 $2
    # Roku needs some time between deploy and run tests or will ignore the later
    sleep 2
    echo
fi

echo "=========================================="
echo "LAUNCHING TESTS ON ROKU"
echo "=========================================="
curl -s -d '' "http://$ROKU_IP:8060/launch/dev?RunTests=true"
echo "Tests launched successfully"
echo

# Wait a moment for tests to start
sleep 1

# Now capture results
echo "=========================================="
echo "CAPTURING TEST RESULTS"
echo "=========================================="
echo "Showing only test output (full log saved to file)..."
echo "Press Ctrl+C to stop early"
echo

OUTPUT_FILE="/tmp/roku_test_output_$(date +%s).txt"

# Capture output with timeout and show test suite summaries
if command -v nc > /dev/null 2>&1; then
    # Capture all output to file and filter for test framework output to screen
    timeout 120 nc $ROKU_IP 8085 2>&1 | tee "$OUTPUT_FILE" | grep -E "^===|^\*\*\*"
elif command -v telnet > /dev/null 2>&1; then
    (sleep 120; echo "quit") | telnet $ROKU_IP 8085 2>&1 | tee "$OUTPUT_FILE" | grep -E "^===|^\*\*\*"
else
    echo "ERROR: Neither 'nc' nor 'telnet' available"
    echo "Please manually connect: telnet $ROKU_IP 8085"
    exit 1
fi

# Parse and display summary
echo
echo "=========================================="
echo "TEST SUMMARY"
echo "=========================================="

# Extract final test results (lines starting with ***)
grep "^\*\*\*.*Total" "$OUTPUT_FILE" 2>/dev/null

echo
echo "Full output saved to: $OUTPUT_FILE"
echo "=========================================="

# Simple check: look for "Failed = 0" or "Failed = X"
if grep -q "Failed.*=.*0" "$OUTPUT_FILE" 2>/dev/null; then
    echo "✅ ALL TESTS PASSED!"
    exit 0
elif grep -q "Failed.*=" "$OUTPUT_FILE" 2>/dev/null; then
    failed_count=$(grep "Failed.*=" "$OUTPUT_FILE" | tail -1 | grep -o "Failed.*=.*[0-9]*" | grep -o "[0-9]*$" | head -1)
    echo "❌ $failed_count TEST(S) FAILED"
    
    # Show which tests failed
    echo
    echo "Failed test details:"
    grep -B2 "Result:.*Fail" "$OUTPUT_FILE" | grep "Start.*test:" | sed 's/---//g'
    exit 1
else
    echo "⚠️  No test results found. Check output file:"
    echo "   cat $OUTPUT_FILE | tail -50"
    exit 2
fi
