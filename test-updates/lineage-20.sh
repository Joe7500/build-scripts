#!/bin/bash
# git clone https://github.com/LineageOS/android_build_release build
# git clone https://github.com/LineageOS/android_build_release build-release

cd lineage
cd build
git switch lineage-20.0
if [ $? -ne 0 ]; then echo git switch failed; exit 1; fi
git pull --rebase
if [ $? -ne 0 ]; then echo git pull failed; exit 1; fi
BUILD_RELEASE_TEST=`cat core/version_defaults.mk | grep 'PLATFORM_SECURITY_PATCH := '`
if [ $? -ne 0 ]; then echo get BUILD_RELEASE_TEST failed; exit 1; fi
BUILD_RELEASE=`echo "$BUILD_RELEASE_TEST" | sed -e 's/ //g' | cut -d "=" -f 2`
cd -

LAST_RELEASE=`cat ../LAST_RELEASE_lineage-20`

echo BUILD_RELEASE $BUILD_RELEASE
echo LAST_RELEASE $LAST_RELEASE

if [ "$BUILD_RELEASE" == "$LAST_RELEASE" ]; then
   echo not update
   exit 1
else
   echo update
   if echo "$@" | grep update ; then  echo "$BUILD_RELEASE" > ../LAST_RELEASE_lineage-20; fi
   exit 0
fi

cd ..
exit 1
