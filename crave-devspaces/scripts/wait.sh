
source ../../etc/config.sh

if ! ls .repo ; then bash repo-init.sh ; fi

while true; do
   sleep `shuf -n 1 -i 400-900`
#   sleep 20
#   sleep 5
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

