
PACKAGE_NAME=$1

source ../../etc/config.sh

while true; do
   sleep `shuf -n 1 -i 400-900`
#   sleep 20

   if ls $LOCK_FILE; then
	continue
   fi

   if ls $REMOTE_BUSY_LOCK; then
	continue
   fi

   touch $REMOTE_BUSY_LOCK
   screen -dmS begin-$PACKAGE_NAME bash begin.sh
   exit 0
done

