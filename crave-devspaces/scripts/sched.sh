#!/bin/bash

if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ] ; then
   echo ""
   echo usage: hour minute dow
   echo ""
   echo hour = 24 hr format
   echo minute = 0-30. sleep interval is up to 15 minutes
   echo dow = day of week. monday = 1 , sunday = 7
   echo ""
   exit 1
fi 

IN_HOUR=$1
IN_MIN=$2
IN_DOW=$3

SECONDS=0

source ../../etc/config.sh

if ! ls .repo ; then bash repo-init.sh ; fi

while true; do
   # 7 days
   if [ $SECONDS -gt 604800 ]; then
      exit 1
   fi
   # 5 to 15 minutes
   sleep `shuf -n 1 -i 300-900`
   if [ `date +%H` -ge $IN_HOUR ] && [ `date +%M` -ge $IN_MIN ] && [ `date +%u` -ge $IN_DOW ] ; then 
      echo sched reached. checking
      # Reset to zero so sched matches always from now.
      IN_MIN=0
      IN_HOUR=0
      IN_DAY=0
   else
      echo sched not reached. waiting
      continue
   fi
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

