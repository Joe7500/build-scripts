#!/bin/bash
# 
# Edit config.sh:
# PACKAGE_NAME
# PACKAGE_MANIFEST_ARGS
# CRAVE_MANIFEST_ARGS
# CRAVE_SCRIPT
# CRAVE_YAML


export PATH=~/bin:$PATH

source config.sh
source ../../etc/config.sh
source ../../etc/secrets/telegram.sh
source ../../etc/secrets/ntfy.sh

JJ_SPEC="JJ_SPEC:`date | md5sum | cut -d " " -f 1`"
echo $JJ_SPEC

if ls $REMOTE_BUSY_LOCK ; then 
        echo "======================================================="
	echo "hhmmm. lock file exists: $REMOTE_BUSY_LOCK. You sure? "
	echo "======================================================="
	echo ""
fi

if echo "$@" | grep clean ; then CLEAN='--clean' ; fi
if echo "$@" | grep resume ; then RESUME='--resume' ; fi
echo -e "\\a" ; sleep 1 ; echo -e "\\a"
echo ""
echo "======================================================="
echo "           dont forget --clean or --resume."
echo "======================================================="
echo ""
echo "starting in 30 seconds"
sleep 30

set -v

rm -rf .repo
repo init $CRAVE_MANIFEST_ARGS
cp $CRAVE_YAML .repo/manifests/crave.yaml

touch $REMOTE_BUSY_LOCK

curl -s -X POST $URL -d chat_id=$ID -d text="Build $PACKAGE_NAME on crave.io queued. `env TZ=Africa/Harare date`. $JJ_SPEC "
curl -s -d "Build $PACKAGE_NAME on crave.io queued. `env TZ=Africa/Harare date`. $JJ_SPEC " $NTFY_URL

screen -dmS check_progress bash check_progress.sh $JJ_SPEC $PACKAGE_NAME

crave run $CLEAN --no-patch -- "repo init $PACKAGE_MANIFEST_ARGS; \
rm -rf custom_scripts; \
git clone https://github.com/Joe7500/build-scripts.git -b main custom_scripts; \
cp -f custom_scripts/remote/$CRAVE_SCRIPT builder.sh; \
rm -rf custom_scripts; \
source build/envsetup.sh; \
/usr/bin/bash builder.sh $RESUME $JJ_SPEC "

echo -e "\\a" ; sleep 1 ; echo -e "\\a"
sleep 86400
