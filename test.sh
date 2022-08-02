#!/bin/sh

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
    echo
    echo "Usage: $0 Roku_IP [dev_password]"
    echo 
    echo "       If 'dev_password' is provided, it will compile and deploy before running tests."
    echo
    exit 1
fi

if [ $# -eq 2 ]; then
    echo "DEPLOY..."
    echo
    ./deploy.sh $1 $2
    # Roku needs some time between deploy and run tests or will ignore the later
    sleep 2
fi

echo "RUN TESTS..."
echo
curl -d '' "http://$1:8060/launch/dev?RunTests=true"
