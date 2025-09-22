#!/bin/bash

cp -f ~/.gitconfig.bak.http ~/.gitconfig

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

cd "$SCRIPT_DIR"
cd ../
source etc/config.sh
if [ $? -ne 0 ]; then
   echo failed to source config
   exit 1
fi
cd -

if ls $LOCK_FILE; then
   echo build-auto is already running
   exit 1
fi
if ls $REMOTE_BUSY_LOCK; then
   echo remote build is already running
   exit 1
fi
echo $$ > $LOCK_FILE

echo running - `date` >> $LOG_ROOT/build-auto.log

cd $TEST_UPDATES_ROOT

for i in axion crDroidAndroid-14 crDroidAndroid-15 crDroidAndroid-16 lineage-21 lineage-20 lineage-22 voltage voltage-5; do
   cd $TEST_UPDATES_ROOT
   bash $i.sh
   if [ $? -eq 0 ]; then
      echo queue remote
      if ! crave list | grep -iE 'queued|running'; then
         touch $REMOTE_BUSY_LOCK
         echo $i > $REMOTE_BUSY_LOCK
         cd $CRAVE_ROOT/$i
         screen -dmS build-remote bash begin.sh
         rm $LOCK_FILE
	 exit 0
      else
         echo job already queued or running. abort
         rm $LOCK_FILE
         exit 0
      fi
   fi
done

rm $LOCK_FILE
exit 0


for i in RisingOS_Revived-8 ; do
   cd $TEST_UPDATES_ROOT
   bash $i.sh
   if [ $? -eq 0 ]; then
      echo queue remote
      if ! crave list | grep -iE 'queued|running'; then
         touch $REMOTE_BUSY_LOCK
         echo $i > $REMOTE_BUSY_LOCK
         cd $CRAVE_ROOT/$i
#         screen -dmS build-remote bash begin.sh DO_GAPPS_BUILD
         rm $LOCK_FILE
         exit 0
      else
         rm $LOCK_FILE
         exit 0
      fi
   fi
done

rm $LOCK_FILE

exit 0
