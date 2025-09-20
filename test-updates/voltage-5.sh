#!/bin/bash
# git clone https://github.com/VoltageOS/vendor_voltage voltage

cd voltage

git switch 16
if [ $? -ne 0 ]; then echo git switch failed; exit 1; fi
git pull --rebase
if [ $? -ne 0 ]; then echo git pull failed; exit 1; fi

NEW_VER=`cat config/version.mk | grep "VOLTAGEVERSION :"| cut -d . -f 2`
OLD_VER=`cat ../OLD_VER_voltage-5`

echo new $NEW_VER
echo old $OLD_VER

# test for integer
test -z $(echo "$OLD_VER" | sed s/[0-9]//g) && echo "old is integer" || exit 1
test -z $(echo "$NEW_VER" | sed s/[0-9]//g) && echo "new is integer" || exit 1

if [ $NEW_VER -gt $OLD_VER ]; then
        echo update
	if echo "$@" | grep update ; then echo $NEW_VER > ../OLD_VER_voltage-5; fi
	exit 0
else
	echo not update
	exit 1
fi

exit 1
