#!/bin/bash

SOURCEDIR=$1

export BASE_ROOT=/home/user/hdd1/android-builds/
source $BASE_ROOT/etc/config.sh

START_TIME=$(date +%s)

echo $SOURCEDIR

cd /home/user/ssd1/build/

echo cleaning
rm -rf ab
mkdir ab
cd ab

ln -s $SOURCEDIR/.repo .repo
ln -s $SOURCEDIR/.backup .backup

cp .backup/repo-sync.sh .
cp .backup/resync.sh .
cp .backup/restore.sh .
bash ./restore.sh

bash $SCRIPT_ROOT/resync.sh
repo sync -l -j 2
bash repo-sync.sh
if [ $? -ne 0 ]; then echo failed to sync $SOURCEDIR ; exit 1; fi

cd /home/user/
cd /home/user/ssd1/build/ab/

bash './builder.sh'
if [ $? -eq 0 ]; then
	bash backup.sh
	source config-rom.sh
	cd $TEST_UPDATES_ROOT
	bash $PACKAGE_NAME.sh --update
	cd -
	rm $BASE_ROOT/var/lock/local/local_busy.lock
else
	echo failed to build $SOURCEDIR
	/home/user/bin/telegram-message.sh "Build failed in `date -d@$TOTAL_TIME -u +%H:%M:%S` $SOURCEDIR"
	exit 1
fi

END_TIME=$(date +%s)
TOTAL_TIME=$(($END_TIME - $START_TIME))
echo "Build completed in `date -d@$TOTAL_TIME -u +%H:%M:%S`"
/home/user/bin/telegram-message.sh "Build completed in `date -d@$TOTAL_TIME -u +%H:%M:%S` $SOURCEDIR"
