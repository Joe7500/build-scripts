#!/bin/bash

cd calyx

git switch android15-qpr2
if [ $? -ne 0 ]; then echo git switch failed; exit 1; fi
git pull --rebase

NEW_MINOR=`cat config/version.mk | grep "PRODUCT_VERSION_MINOR :=" | cut -d " " -f 3`
NEW_PATCH=`cat config/version.mk | grep "PRODUCT_VERSION_PATCH :=" | cut -d " " -f 3`

OLD_MINOR=`cat ../OLD_VER_M_calyx`
OLD_PATCH=`cat ../OLD_VER_P_calyx`

echo NEW_MINOR $NEW_MINOR
echo NEW_PATCH $NEW_PATCH
echo OLD_MINOR $OLD_MINOR
echo OLD_PATCH $OLD_PATCH

# test for integer
test -z $(echo "$NEW_MINOR" | sed s/[0-9]//g) && echo "minor is integer" || exit 1
test -z $(echo "$NEW_PATCH" | sed s/[0-9]//g) && echo "patch is integer" || exit 1

UPDATE=0

#if [ $NEW_PATCH -gt $OLD_PATCH ]; then
#        echo update
#	if echo "$@" | grep update ; then echo $NEW_PATCH > ../OLD_VER_P_calyx; fi
#	UPDATE=1
#fi

if [ $NEW_MINOR -gt $OLD_MINOR ]; then
        echo update
        if echo "$@" | grep update ; then echo $NEW_MINOR > ../OLD_VER_M_calyx; fi
        UPDATE=1
fi

if [ $UPDATE -eq 1 ] ; then
	exit 0
fi

echo not update
exit 1
