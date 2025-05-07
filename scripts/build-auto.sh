#!/bin/bash

# Get script dir. Copy pasted from internet.
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

cd "$SCRIPT_DIR"
cd ../
source etc/config.sh
if [ $? -ne 0 ]; then echo failed to source config; exit 1 ; fi
cd -

if [ -f $LOCK_FILE ]; then
        if [ $? -eq 0 ]; then
                echo build-auto is already running
                exit 1
        fi
fi
echo $$ > $LOCK_FILE

echo running - `date` >> $LOG_ROOT/build-auto.log

cd $TEST_UPDATES_ROOT

for i in crDroidAndroid-14 crDroidAndroid-15 lineage-21 lineage-20 lineage-22 RisingOS ; do
	cd $TEST_UPDATES_ROOT
	if ls $REMOTE_BUSY_LOCK  ; then echo "skipping $i" ; continue ; fi
	bash $i.sh
	if [ $? -eq 0 ]; then
		if ! ls $REMOTE_BUSY_LOCK; then
			echo queue remote
			touch $REMOTE_BUSY_LOCK
			echo $i > $REMOTE_BUSY_LOCK
			cd $CRAVE_ROOT/$i
			screen -dmS build-remote bash begin.sh
			#bash begin.sh
			ls $CRAVE_ROOT/$i
			cd - 
		else
			ls $CRAVE_ROOT/$i
			break
		fi
	fi
done	

rm $LOCK_FILE

exit 0
