#!/bin/bash

cd rising

#git switch fifteen
git switch sixteen
if [ $? -ne 0 ]; then echo git switch failed; exit 1; fi
git pull --rebase

NEW_VER=`cat config/version.mk | grep 'RISING_VERSION :=' | md5sum | cut -d " " -f 1`
OLD_VER=`cat ../OLD_VER_rising-6 | cut -d " " -f 1`

echo new $NEW_VER
echo old $OLD_VER

if [ "$NEW_VER" != "$OLD_VER" ]; then
        echo update
        if echo "$@" | grep update ; then echo $NEW_VER > ../OLD_VER_rising-6; fi
        exit 0
else
	echo not update
	exit 1
fi

exit 1
