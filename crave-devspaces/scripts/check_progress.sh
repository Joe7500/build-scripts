#!/bin/bash

SECONDS=0

export TZ=Africa/Harare

IFS=$'\n'

# Parse command line
# eg. JJ_SPEC:1234 lineage-22 GAPPS_BUILD
JJ_SPEC="$1"
PACKAGE_NAME="$2"

source ../../etc/config.sh
source ../../etc/secrets/telegram.sh
source ../../etc/secrets/ntfy.sh

set -v

echo $JJ_SPEC

FAILED=0

while true; do
   MESSAGES=$(curl -s "$NTFY_URL/json?poll=1" | jq | grep '"message":' | grep "crave\.io" | grep -- "$JJ_SPEC")
   if echo "$MESSAGES" | grep -- "$JJ_SPEC" | grep queued; then
      echo job is queued
      sleep 5
      break
   fi
   sleep 300
   if [ $SECONDS -gt 86400 ]; then exit 1; fi
done

while true; do
   echo checking.
   MESSAGES=$(curl -s "$NTFY_URL/json?poll=1" | jq | grep '"message":' | grep "crave\.io" | grep -- "$JJ_SPEC")
   if echo "$MESSAGES" | grep -- "$JJ_SPEC" | grep " started"; then
      echo job is started
   fi
   if echo "$MESSAGES" | grep -- "$JJ_SPEC" | grep " failed"; then
      echo job is failed
      FAILED=1
      break
   fi
   if echo "$MESSAGES" | grep -- "$JJ_SPEC" | grep " softfailed"; then
      echo job is softfailed
      FAILED=1
      break
   fi
   if echo "$MESSAGES" | grep -- "$JJ_SPEC" | grep completed; then
      echo job is completed
      TIME_TAKEN=$(printf '%dh:%dm:%ds\n' $((SECONDS / 3600)) $((SECONDS % 3600 / 60)) $((SECONDS % 60)))
      curl -s -X POST $URL -d chat_id=$ID -d text="Build $PACKAGE_NAME on crave.io total time taken: $TIME_TAKEN. $(date). $JJ_SPEC "
      curl -s -d "Build $PACKAGE_NAME on crave.io total time taken: $TIME_TAKEN. $(date). $JJ_SPEC " $NTFY_URL
      source ../../etc/config.sh
      cd $TEST_UPDATES_ROOT/
      bash $PACKAGE_NAME.sh --update
      cd -
      # Do further stuff here
      DL_URL=$(curl -s "$NTFY_URL/json?poll=1" | jq | grep -- "$JJ_SPEC" | grep -Po '(https://.*/.* )' | cut -d" " -f 1)
      curl -s -X POST $URL -d chat_id="$ALT_ID" -d text="$DL_URL"
      FILENAME=$(curl -s "$NTFY_URL/json?poll=1" | jq | grep -- "$JJ_SPEC" | grep '"message":' | grep pixeldrain.com | tail -1 | awk '{print $3}')
      echo $FILENAME

      rm -f $REMOTE_BUSY_LOCK
      break
   fi
   echo "sleeping"
   sleep 600
   if [ $SECONDS -gt 86400 ]; then
      exit 1
   fi
done

JJ_SPEC="JJ_SPEC:`date | md5sum | cut -d " " -f 1`"
WAIT_FOR_GAPPS_TO_START=1
while true; do
   if [ $FAILED -eq 1 ]; then
      echo job failed
      break
   fi
   if ! echo "$@" | grep GAPPS_BUILD; then
      echo not GAPPS build
      break
   fi
   touch $REMOTE_BUSY_LOCK
   echo checking gapps build.
   if [ $WAIT_FOR_GAPPS_TO_START -eq 1 ]; then
      echo waiting for gapps build to start
      sleep 1800
      WAIT_FOR_GAPPS_TO_START=0
   fi
   MESSAGES=$(curl -s "$NTFY_URL/json?poll=1" | jq | grep '"message":' | grep "crave\.io" | grep -- "$JJ_SPEC")
   if ! echo "$MESSAGES" | grep -- "$JJ_SPEC" | grep -iE " started| queued"; then
      if ! echo $GAPPS_BUILD_STARTED | grep started; then
         echo job not queued or started. trying to start now.
         screen -dmS build-remote bash begin.sh --resume START_GAPPS_BUILD $JJ_SPEC
         curl -s -d "Build $PACKAGE_NAME on crave.io queued. - GAPPS - $(date). $JJ_SPEC " $NTFY_URL
         curl -s -X POST $URL -d chat_id=$ID -d text="Build $PACKAGE_NAME on crave.io queued. - GAPPS - $(date). $JJ_SPEC " 
         GAPPS_BUILD_STARTED=started
      fi
   fi
   if echo "$MESSAGES" | grep -- "$JJ_SPEC" | grep " started" ; then
      echo job is started
   fi
   if echo "$MESSAGES" | grep -- "$JJ_SPEC" | grep " failed" ; then
      echo job is failed
      FAILED=1
      break
   fi
   if echo "$MESSAGES" | grep -- "$JJ_SPEC" | grep " softfailed" ; then
      echo job is softfailed
      FAILED=1
      break
   fi
   if echo "$MESSAGES" | grep -- "$JJ_SPEC" | grep "completed" ; then
      echo job is completed
      TIME_TAKEN=$(printf '%dh:%dm:%ds\n' $((SECONDS / 3600)) $((SECONDS % 3600 / 60)) $((SECONDS % 60)))
      curl -s -X POST $URL -d chat_id=$ID -d text="Build $PACKAGE_NAME on crave.io total time taken: $TIME_TAKEN. $(date). $JJ_SPEC "
      curl -s -d "Build $PACKAGE_NAME on crave.io total time taken: $TIME_TAKEN. $(date). $JJ_SPEC " $NTFY_URL
      source ../../etc/config.sh
      cd $TEST_UPDATES_ROOT/
      bash $PACKAGE_NAME.sh --update
      cd -
      # Do further stuff here
      DL_URL=$(curl -s "$NTFY_URL/json?poll=1" | jq | grep -- "$JJ_SPEC" | grep -Po '(https://.*/.* )' | cut -d" " -f 1)
      curl -s -X POST $URL -d chat_id="$ALT_ID" -d text="$DL_URL"

      rm -f $REMOTE_BUSY_LOCK
      break
   fi
   echo "sleeping"
   sleep 1800
   if [ $SECONDS -gt 86400 ]; then
      exit 1
   fi
done

if [ $FAILED -eq 1 ]; then
   echo job failed
   sleep 86400
   exit 1
fi


sleep 3600
cd $SCRIPT_ROOT/
bash build-auto.sh
cd -

sleep 86400

exit 0
