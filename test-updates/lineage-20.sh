#!/bin/bash
# git clone https://github.com/LineageOS/android_build build
# git clone https://github.com/LineageOS/android_build_release build-release

UPDATE=0

cd lineage
cd build
git switch lineage-20.0
if [ $? -ne 0 ]; then echo git switch failed; exit 1; fi
git pull --rebase
BUILD_RELEASE_TEST=`cat core/version_defaults.mk | grep 'PLATFORM_SECURITY_PATCH := '`
if [ $? -ne 0 ]; then echo get BUILD_RELEASE_TEST failed; exit 1; fi
BUILD_RELEASE=`echo "$BUILD_RELEASE_TEST" | sed -e 's/ //g' | cut -d "=" -f 2`
cd -

LAST_RELEASE=`cat ../LAST_RELEASE_lineage-20`

echo BUILD_RELEASE $BUILD_RELEASE
echo LAST_RELEASE $LAST_RELEASE

if [ "$BUILD_RELEASE" == "$LAST_RELEASE" ]; then
   echo not update
else
   echo update
   UPDATE=1
fi

LAST_COMMIT=$(cat ../LAST_COMMIT_lineage-20 | head -1)
echo LAST $LAST_COMMIT

cd android
git switch lineage-20.0
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

if echo "$@" | grep update; then echo $CURRENT_COMMIT >../LAST_COMMIT_lineage-20; fi
if echo "$@" | grep update; then echo "$BUILD_RELEASE" >../LAST_RELEASE_lineage-20; fi

if [ $UPDATE -eq 1 ]; then
   echo update
   exit 0
fi

cd ..
exit 1
