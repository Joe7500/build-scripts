#!/bin/bash
# git clone https://github.com/LineageOS/android_build build
# git clone https://github.com/LineageOS/android_build_release build-release
# git clone https://github.com/LineageOS/android android
# lineage-23 https://github.com/LineageOS/android_vendor_lineage
#     release/flag_values/bp2a/RELEASE_PLATFORM_SECURITY_PATCH.textproto

UPDATE=0

cd lineage
cd build
git switch lineage-23.0
if [ $? -ne 0 ]; then
   echo git switch failed
   exit 1
fi
git pull --rebase
BUILD_ID_TEST=$(cat core/build_id.mk | grep BUILD_ID=)
if [ $? -ne 0 ]; then
   echo get BUILD_ID_TEST failed
   exit 1
fi
BUILD_ID=$(echo "$BUILD_ID_TEST" | cut -d "=" -f 2 | cut -d "." -f 1 | tr '[:upper:]' '[:lower:]')
cd -

cd android_vendor_lineage
git switch lineage-23.0
if [ $? -ne 0 ]; then
   echo git switch failed
   exit 1
fi
git pull --rebase
BUILD_RELEASE_TEST=$(cat release/flag_values/$BUILD_ID/RELEASE_PLATFORM_SECURITY_PATCH.textproto | grep string_value:)
if [ $? -ne 0 ]; then
   echo get BUILD_RELEASE_TEST failed
   exit 1
fi
BUILD_RELEASE=$(echo "$BUILD_RELEASE_TEST" | cut -d '"' -f 2)
cd -

LAST_RELEASE=$(cat ../LAST_RELEASE_lineage-23)

echo BUILD_RELEASE $BUILD_RELEASE
echo LAST_RELEASE $LAST_RELEASE

if [ "$BUILD_RELEASE" == "$LAST_RELEASE" ]; then
   echo not update
else
   echo update
   UPDATE=1
fi

LAST_COMMIT=$(cat ../LAST_COMMIT_lineage-23 | head -1)
echo LAST $LAST_COMMIT

cd android
git switch lineage-23.0
if [ $? -ne 0 ]; then
   echo git switch failed
   exit 1
fi
git pull --rebase

CURRENT_COMMIT=$(git log --format=format:%H | head -1)
echo CURRENT $CURRENT_COMMIT

if [ "$CURRENT_COMMIT" == "$LAST_COMMIT" ]; then
   echo not update
else
   NEW_COMMITS=$(git log --format=format:%H | head -9)
   for COMMIT in $NEW_COMMITS; do
      if [ "$COMMIT" == "$LAST_COMMIT" ]; then
         echo found last commit
         break
      else
         git show -q $COMMIT >../../commit_msg.txt
         cat ../../commit_msg.txt | grep -iE 'quarter|security|asb|cve|qpr'
         if [ $? -eq 0 ]; then
            echo update
            UPDATE=1
            break
         fi
      fi
   done
fi
cd -

if echo "$@" | grep update; then echo $CURRENT_COMMIT >../LAST_COMMIT_lineage-23; fi
if echo "$@" | grep update; then echo "$BUILD_RELEASE" >../LAST_RELEASE_lineage-23; fi

if [ $UPDATE -eq 1 ]; then
   echo update
   exit 0
fi

cd ..
exit 1
