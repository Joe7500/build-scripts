#!/bin/bash

# Waits to start job, checking for locks and crave list.

SECONDS=0

source ../../etc/config.sh

if ! ls .repo ; then bash repo-init.sh ; fi

while true; do
   # 3 days
   if [ $SECONDS -gt 259200 ]; then
      exit 1
   fi
   # 60 to 90 minutes
   sleep `shuf -n 1 -i 3600-5400`
   if ls $LOCK_FILE; then
        echo locked
	continue
   fi

   if ls $REMOTE_BUSY_LOCK; then
	echo remote locked
	continue
   fi

   CRAVE_LIST=`crave list`

   if ! echo "$CRAVE_LIST" | grep "android.googlesource.com/platform/manifest" ; then
	echo -e "\\a" ; sleep 1 ; echo -e "\\a";echo -e "\\a" ; sleep 1 ; echo -e "\\a"
	echo crave list not found. trying again later
        continue
   else
	echo crave list found.
   fi

   if echo "$CRAVE_LIST" | grep queued ; then
	echo already queued on crave. locking
        touch $REMOTE_BUSY_LOCK
        continue
   else
	echo not queued on crave
   fi

   if echo "$CRAVE_LIST" | grep running ; then
        echo already running on crave. locking
        touch $REMOTE_BUSY_LOCK
        continue
   else
        echo not running on crave
   fi

   echo no lock found. starting
   touch $REMOTE_BUSY_LOCK
   screen -dmS begin-wait bash begin.sh
   echo -e "\\a" ; sleep 1 ; echo -e "\\a";echo -e "\\a" ; sleep 1 ; echo -e "\\a"
   exit 0
done

