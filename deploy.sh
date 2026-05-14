#!/bin/bash

if [ $# -ne 2 ]; then
    echo "Usage: $0 Roku_IP dev_password"
    exit 1
fi

ROKU_DEV_TARGET=$1

# Timestamp used for both the log filename and its contents
TIMESTAMP=$(date "+%Y-%m-%d_%H-%M-%S")
LOG_DIR="$(dirname "$0")/deploys"
LOG_FILE="$LOG_DIR/$TIMESTAMP.txt"

mkdir -p "$LOG_DIR"

# wake up/interrupt Roku - workaround for fw5.4 crash
curl -sS -d '' http://$ROKU_DEV_TARGET:8060/keypress/Home
curl -sS -d '' http://$ROKU_DEV_TARGET:8060/keypress/Home

# build. zip _must_ change for Roku to accept re-deploy (grr!)
cd -- "$(dirname "$0")"
touch timestamp
zip -FS -9 -r out/bundle * -x run extras "*.log" "*.md" ".git/*" ".DS_Store" "out/*" "deploys/*"

# deploy
DEPLOY_RESULT=$(curl -f -sS --user rokudev:$2 --anyauth -F "mysubmit=Install" -F "archive=@out/bundle.zip" -F "passwd=" http://$ROKU_DEV_TARGET/plugin_install \
| python3 -c 'import sys, re; print("\n".join(re.findall("<font color=\"red\">(.*?)</font>", sys.stdin.read(), re.DOTALL)))')

DEPLOY_STATUS=$?

echo "$DEPLOY_RESULT"

# Write deploy log header
{
    echo "Deploy Log"
    echo "=========="
    echo "Timestamp : $TIMESTAMP"
    echo "Target IP : $ROKU_DEV_TARGET"
    echo "Bundle    : out/bundle.zip"
    if [ $DEPLOY_STATUS -eq 0 ]; then
        echo "Status    : SUCCESS"
    else
        echo "Status    : FAILED (exit $DEPLOY_STATUS)"
    fi
    if [ -n "$DEPLOY_RESULT" ]; then
        echo ""
        echo "Installer Output:"
        echo "$DEPLOY_RESULT"
    fi
    echo ""
    echo "--- Telnet Debug Output ($ROKU_DEV_TARGET:8085) ---"
} > "$LOG_FILE"

rm timestamp

echo "Deploy log written to: deploys/$TIMESTAMP.txt"

# Stream telnet output to screen AND append to the log file continuously.
# Press Ctrl+C to stop capturing.
APP_START_MARKER="------ Running dev 'NR Video Agent' runuserinterface ------"

echo ""
echo "Streaming telnet debug output from $ROKU_DEV_TARGET:8085"
echo "Filtering stale telnet output until current app session starts"
echo "Press Ctrl+C to stop."
echo ""

nc "$ROKU_DEV_TARGET" 8085 \
| awk -v marker="$APP_START_MARKER" '
    found { print; fflush(); next }
    index($0, marker) { found = 1; print; fflush() }
' \
| tee -a "$LOG_FILE"
