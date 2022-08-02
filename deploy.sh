#!/bin/bash

if [ $# -ne 2 ]; then
    echo "Usage: $0 Roku_IP dev_password"
    exit 1
fi

ROKU_DEV_TARGET=$1   # put YOUR roku IP here

# wake up/interrupt Roku - workaround for fw5.4 crash
curl -sS -d '' http://$ROKU_DEV_TARGET:8060/keypress/Home
curl -sS -d '' http://$ROKU_DEV_TARGET:8060/keypress/Home

# build. zip _must_ change for Roku to accept re-deploy (grr!)
cd -- "$(dirname "$0")"
touch timestamp
zip -FS -9 -r out/bundle * -x run extras

# deploy
curl -f -sS --user rokudev:$2 --anyauth -F "mysubmit=Install" -F "archive=@out/bundle.zip" -F "passwd=" http://$ROKU_DEV_TARGET/plugin_install  \
| python3 -c 'import sys, re; print("\n".join(re.findall("<font color=\"red\">(.*?)</font>", sys.stdin.read(), re.DOTALL)))'

rm timestamp
