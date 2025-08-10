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

cp -f ~/.gitconfig.bak.http ~/.gitconfig

if ls $REMOTE_BUSY_LOCK ; then 
        echo "======================================================="
	echo "hhmmm. lock file exists: $REMOTE_BUSY_LOCK. You sure? "
	echo "======================================================="
	echo ""
fi

JJ_SPEC="JJ_SPEC:`date | md5sum | cut -d " " -f 1`"
echo $JJ_SPEC

# Parse command line
# JJ_SPEC always last. eg. --resume GAPPS_BUILD JJ_SPEC:1234
if echo "$@" | grep JJ_SPEC ; then
	JJ_SPEC="JJ_SPEC:`echo $@ | cut -d ":" -f 2`"
fi	
if echo "$@" | grep clean ; then CLEAN='--clean' ; fi
if echo "$@" | grep resume ; then RESUME='--resume' ; fi
# check if we are dealing with a vanilla & gapps build. begin.sh is synlink to ../scripts/begin-gapps.sh
# will start check_progress.sh with GAPPS_BUILD command line
if ls -l begin.sh | grep begin-gapps.sh; then GAPPS_BUILD=GAPPS_BUILD ; echo GAPPS_BUILD ; fi
# check_progress.sh will start me with GAPPS_BUILD command line. In turn I will start remote script with GAPPS_BUILD command line. 
# JJ_SPEC should handle duplicate check_progress.sh tasks. Not ideal, could race.
if echo "$@" | grep GAPPS_BUILD ; then DO_GAPPS_BUILD=GAPPS_BUILD ; echo DO_GAPPS_BUILD; fi

echo -e "\\a" ; sleep 1 ; echo -e "\\a"
echo ""
echo "======================================================="
echo "           dont forget --clean or --resume."
echo "======================================================="
echo ""
echo "starting in 30 seconds"
sleep 30

set -v

repo init $CRAVE_MANIFEST_ARGS  --depth=1 --no-tags --no-clone-bundle --git-lfs
cp $CRAVE_YAML .repo/manifests/crave.yaml

if crave list | grep -iE 'queued|running'; then
	echo "====================================================="
	echo " ABORTING !!!"
	echo " crave list says a build is already queued or running"
	echo "====================================================="
	exit 1
fi

touch $REMOTE_BUSY_LOCK

curl -s -X POST $URL -d chat_id=$ID -d text="Build $PACKAGE_NAME on crave.io queued. `env TZ=Africa/Harare date`. $JJ_SPEC "
curl -s -d "Build $PACKAGE_NAME on crave.io queued. `env TZ=Africa/Harare date`. $JJ_SPEC " $NTFY_URL

screen -dmS check_progress bash check_progress.sh $JJ_SPEC $PACKAGE_NAME $GAPPS_BUILD

crave run $CLEAN --no-patch -- "/usr/bin/curl -o builder.sh -L https://raw.githubusercontent.com/Joe7500/build-scripts/refs/heads/main/remote/$CRAVE_SCRIPT; \
/usr/bin/bash builder.sh $RESUME $DO_GAPPS_BUILD $JJ_SPEC "

# JJ_SPEC always last. eg. /usr/bin/bash builder.sh --resume GAPPS_BUILD JJ_SPEC:1234
#crave run $CLEAN --no-patch -- "repo init $PACKAGE_MANIFEST_ARGS; \
#rm -rf custom_scripts; \
#git clone https://github.com/Joe7500/build-scripts.git -b main custom_scripts; \
#cp -f custom_scripts/remote/$CRAVE_SCRIPT builder.sh; \
#rm -rf custom_scripts; \
#source build/envsetup.sh; \
#/usr/bin/bash builder.sh $RESUME $DO_GAPPS_BUILD $JJ_SPEC "

echo -e "\\a" ; sleep 1 ; echo -e "\\a"
sleep 86400
