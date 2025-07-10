#!/bin/bash

#LAST_COMMIT="596a5d1bd8e81bb155ef6d90608af06b4f0899d1"
#LAST_COMMIT="65587ae3dbb5712e9399f9d5d24e7fdd6999d95a"
#LAST_COMMIT=`cat LAST_COMMIT | head -1`
#echo LAST $LAST_COMMIT

# https://github.com/Joe7500/build-scripts

cd lineage-21
git switch lineage-22.2
if [ $? -ne 0 ]; then echo git switch failed; exit 1; fi
git pull --rebase
if [ $? -ne 0 ]; then echo git pull failed; exit 1; fi

CURRENT_COMMIT=`git log --format=format:%H | head -1`
echo $CURRENT_COMMIT > ../CURRENT_COMMIT_lineage-22
LAST_COMMIT=`cat ../LAST_COMMIT_lineage-22 | head -1 `

echo LAST $LAST_COMMIT
echo LATEST $CURRENT_COMMIT

if [ "$CURRENT_COMMIT" == "$LAST_COMMIT" ]; then
	echo not update
	exit 1
else
	NEW_COMMITS=`git log --format=format:%H | head -9`
	for i in $NEW_COMMITS; do
		if [ "$i" == "$LAST_COMMIT" ]; then
			echo found last commit
			echo $CURRENT_COMMIT > ../LAST_COMMIT_lineage-22
			exit 1 
		else
			git show -q $i > ../commit_msg.txt
			cat ../commit_msg.txt | grep -iE 'quarter|security|asb|cve|qpr'
			if [ $? -eq 0 ]; then
				if echo "$@" | grep update ; then echo $CURRENT_COMMIT > ../LAST_COMMIT_lineage-22; fi
				echo update
				exit 0
			fi
		fi
	done
fi

exit 1

