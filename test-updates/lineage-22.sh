#!/bin/bash
# git clone https://github.com/LineageOS/android_build_release build
# git clone https://github.com/LineageOS/android_build_release build-release

cd lineage
cd build
git switch lineage-22.2
if [ $? -ne 0 ]; then echo git switch failed; exit 1; fi
git pull --rebase
if [ $? -ne 0 ]; then echo git pull failed; exit 1; fi
BUILD_ID_TEST=`cat core/build_id.mk | grep BUILD_ID=`
if [ $? -ne 0 ]; then echo get BUILD_ID_TEST failed; exit 1; fi
BUILD_ID=`echo "$BUILD_ID_TEST" | cut -d "=" -f 2 | cut -d "." -f 1 | tr '[:upper:]' '[:lower:]'`
cd -

cd build-release
git switch lineage-22.2
if [ $? -ne 0 ]; then echo git switch failed; exit 1; fi
git pull --rebase
if [ $? -ne 0 ]; then echo git pull failed; exit 1; fi
BUILD_RELEASE_TEST=`cat flag_values/$BUILD_ID/RELEASE_PLATFORM_SECURITY_PATCH.textproto | grep string_value:`
if [ $? -ne 0 ]; then echo get BUILD_RELEASE_TEST failed; exit 1; fi
BUILD_RELEASE=`echo "$BUILD_RELEASE_TEST" | cut -d '"' -f 2`
cd -

LAST_RELEASE=`cat ../LAST_RELEASE_lineage-22`

echo BUILD_RELEASE $BUILD_RELEASE
echo LAST_RELEASE $LAST_RELEASE

if [ "$BUILD_RELEASE" == "$LAST_RELEASE" ]; then
   echo not update
   exit 1
else
   echo update
   if echo "$@" | grep update ; then  echo "$BUILD_RELEASE" > ../LAST_RELEASE_lineage-22; fi
   exit 0
fi

cd ..
exit 1
