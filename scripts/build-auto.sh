#!/bin/bash

cp -f ~/.gitconfig.bak.http ~/.gitconfig

# Get script dir. Copy pasted from internet.
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

cd "$SCRIPT_DIR"
cd ../
source etc/config.sh
if [ $? -ne 0 ]; then echo failed to source config; exit 1 ; fi
cd -

if ls $LOCK_FILE; then
        echo build-auto is already running
        exit 1
fi
echo $$ > $LOCK_FILE

echo running - `date` >> $LOG_ROOT/build-auto.log

cd $TEST_UPDATES_ROOT

for i in axion crDroidAndroid-14 crDroidAndroid-15 lineage-21 lineage-20 lineage-22 RisingOS calyx ; do
	cd $TEST_UPDATES_ROOT
	if ls $REMOTE_BUSY_LOCK ; then echo "skipping $i" ; continue ; fi
	bash $i.sh
	if [ $? -eq 0 ]; then
		echo queue remote
		if ! crave list | grep -i running; then
			touch $REMOTE_BUSY_LOCK
			echo $i > $REMOTE_BUSY_LOCK
			cd $CRAVE_ROOT/$i
			if echo $i | grep -iE "risingos"; then
				screen -dmS build-remote bash begin.sh DO_GAPPS_BUILD
			else
				screen -dmS build-remote bash begin.sh
			fi
			ls $CRAVE_ROOT/$i
			cd -
		fi 
	fi
done	

rm $LOCK_FILE

exit 0
