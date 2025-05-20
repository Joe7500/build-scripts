#!/bin/bash

SECONDS=0

IFS=$'\n'
JJ_SPEC="$1"
PACKAGE_NAME="$2"

source ../../etc/config.sh
source ../../etc/secrets/telegram.sh
source ../../etc/secrets/ntfy.sh

set -v

while true; do
	MESSAGES=`curl -s "$NTFY_URL/json?poll=1" | jq | grep '"message":' | grep "crave\.io" | grep -- "$JJ_SPEC"`
	if echo $MESSAGES | grep -- "$JJ_SPEC" | grep queued ; then
		echo job is queued
		sleep 5
		break	
	fi
	sleep 300
	if [ $SECONDS -gt 86400 ]; then exit 1 ; fi
done

while true; do
	echo checking.
        MESSAGES=`curl -s "$NTFY_URL/json?poll=1" | jq | grep '"message":' | grep "crave\.io" | grep -- "$JJ_SPEC"` 
	if echo $MESSAGES | grep -- "$JJ_SPEC" | grep " started" ; then
                echo job is started
        fi
        if echo $MESSAGES | grep -- "$JJ_SPEC" | grep " failed" ; then
                echo job is failed
		rm -f $REMOTE_BUSY_LOCK
		break
        fi
        if echo $MESSAGES | grep -- "$JJ_SPEC" | grep " softfailed" ; then
                echo job is softfailed
		rm -f $REMOTE_BUSY_LOCK
		break
        fi
        if echo $MESSAGES | grep -- "$JJ_SPEC" | grep completed ; then
                echo job is completed
		TIME_TAKEN=`printf '%dh:%dm:%ds\n' $((SECONDS/3600)) $((SECONDS%3600/60)) $((SECONDS%60))`
		curl -s -X POST $URL -d chat_id=$ID -d text="Build $PACKAGE_NAME on crave.io total time taken: $TIME_TAKEN. `env TZ=Africa/Harare date`. $JJ_SPEC "
		curl -s -d "Build $PACKAGE_NAME on crave.io total time taken: $TIME_TAKEN. `env TZ=Africa/Harare date`. $JJ_SPEC " $NTFY_URL
		source ../../etc/config.sh
	        cd $TEST_UPDATES_ROOT/
		bash $PACKAGE_NAME.sh --update
		cd -
		# Do further stuff here
		
		rm -rf .repo
        	rm -f $REMOTE_BUSY_LOCK
                break
        fi
	echo "sleeping"
        sleep 600
        if [ $SECONDS -gt 86400 ]; then
                exit 1
        fi
done

rm -rf .repo
sleep 86400

exit 0
