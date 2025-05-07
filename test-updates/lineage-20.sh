#!/bin/bash

GIT_DIR="lineage-21"
GIT_BRANCH="lineage-20.0"
NAME="lineage-20"

cd $GIT_DIR
git switch $GIT_BRANCH
if [ $? -ne 0 ]; then echo git switch failed; exit 1; fi
git pull --rebase
git pull
if [ $? -ne 0 ]; then echo git pull failed; exit 1; fi

CURRENT_COMMIT=`git log --format=format:%H | head -1`
echo $CURRENT_COMMIT > ../CURRENT_COMMIT_$NAME
LAST_COMMIT=`cat ../LAST_COMMIT_$NAME | head -1 `

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
			echo $CURRENT_COMMIT > ../LAST_COMMIT_$NAME
			exit 1 
		else
			git show -q $i > ../commit_msg.txt
			cat ../commit_msg.txt | grep -iE 'quarter|security|asb '
			if [ $? -eq 0 ]; then
				if echo "$@" | grep update ; then  echo $CURRENT_COMMIT > ../LAST_COMMIT_$NAME; fi
				echo update
				exit 0
			fi
		fi
	done
fi

exit 1

