#!/bin/bash

source /home/admin/.profile
source /home/admin/.bashrc
source /tmp/crave_bashrc

cd /tmp/src/android/

set -v

# Template helper variables
PACKAGE_NAME=lineage-22
VARIANT_NAME=user
BUILD_TYPE=vanilla
if echo $@ | grep BUILD_GAPPS; then
   BUILD_TYPE=gapps
fi
DEVICE_BRANCH=lineage-22.2
VENDOR_BRANCH=lineage-22.2
XIAOMI_BRANCH=lineage-22.2
REPO_URL="-u https://github.com/LineageOS/android.git -b lineage-22.2 --git-lfs"
OTA_SED_STRING="https://download.lineageos.org/api/v1/{device}/{type}/{incr}"
OTA_SED_REPLACE_STRING="https://raw.githubusercontent.com/Joe7500/Builds/main/$PACKAGE_NAME.$VARIANT_NAME.$BUILD_TYPE.chime.json"

# Random template helper stuff
export BUILD_USERNAME=user
export BUILD_HOSTNAME=localhost 
export KBUILD_BUILD_USER=user
export KBUILD_BUILD_HOST=localhost
SECONDS=0
if echo $@ | grep "JJ_SPEC:" ; then export JJ_SPEC=`echo $@ | cut -d ":" -f 2` ; fi
TG_URL="https://api.telegram.org/bot$TG_TOKEN/sendMessage"

# Send push notifications
notify_send() {
   local MSG
   MSG="$@"
   curl -s -X POST $TG_URL -d chat_id=$TG_CID -d text="$MSG `env LC_ALL="" TZ=Africa/Harare LC_TIME="C.UTF-8" date`. JJ_SPEC:$JJ_SPEC" > /dev/null 2>&1
   curl -s -d "$MSG `env LC_ALL="" TZ=Africa/Harare LC_TIME="C.UTF-8" date`. JJ_SPEC:$JJ_SPEC" "ntfy.sh/$NTFYSUB" > /dev/null 2>&1
}

notify_send "Build $PACKAGE_NAME on crave.io started."

# Always cleanup
cleanup_self () {
   cd /tmp/src/android/
   rm -rf vendor/lineage-priv/keys vendor/lineage-priv
   rm -rf priv-keys .config/b2/ /home/admin/.config/b2/
   rm -rf device/xiaomi/chime/ vendor/xiaomi/chime/ kernel/xiaomi/chime/ hardware/xiaomi/
   rm -rf prebuilts/clang/kernel/linux-x86/clang-stablekern/ prebuilts/clang/host/linux-x86/clang-stablekern/
   cd packages/apps/Updater/ && git reset --hard && cd -
   cd packages/modules/Connectivity/ && git reset --hard && cd -
   rm -f InterfaceController.java.patch wfdservice.rc.patch strings.xml* builder.sh goupload.sh GOFILE.txt
   rm -rf /tmp/android-certs* /home/admin/venv/ custom_scripts/
   cd /home/admin
   rm -rf .tdl LICENSE  README.md  README_zh.md  tdl  tdl_key  tdl_Linux_64bit.tar.gz* venv tdl.zip tdl_Linux.tgz tdl.sh
   cd /tmp/src/android/
}

# Better than ' || exit 1 '
check_fail () {
   if [ $? -ne 0 ]; then 
       if ls out/target/product/chime/$PACKAGE_NAME*.zip; then
   	  notify_send "Build $PACKAGE_NAME on crave.io softfailed."
          echo weird. build failed but OTA package exists.
          echo softfail > result.txt
	  cleanup_self
          exit 1
       else
          notify_send "Build $PACKAGE_NAME on crave.io failed."
	  echo "oh no. script failed"
          cleanup_self
	  echo fail > result.txt
          exit 1 
       fi
   fi
}

# repo sync. or not.
if echo "$@" | grep resume; then
   echo "resuming"
else
   repo init $REPO_URL --git-lfs ; check_fail
   cleanup_self
   /opt/crave/resync.sh ; check_fail
fi

# Download trees
rm -rf kernel/xiaomi/chime/
rm -rf vendor/xiaomi/chime/
rm -rf device/xiaomi/chime/
rm -rf hardware/xiaomi/
rm -rf prebuilts/clang/host/linux-x86/clang-stablekern/
curl -o kernel.tar.xz -L "https://github.com/Joe7500/Builds/releases/download/Stuff/kernel.tar.xz" ; check_fail
tar xf kernel.tar.xz ; check_fail
rm -f kernel.tar.xz
curl -o lineage-22.1.tar.xz -L "https://github.com/Joe7500/Builds/releases/download/Stuff/lineage-22.1.tar.xz" ; check_fail
tar xf lineage-22.1.tar.xz ; check_fail
rm -f lineage-22.1.tar.xz
curl -o toolchain.tar.xz -L "https://github.com/Joe7500/Builds/releases/download/Stuff/toolchain.tar.xz" ; check_fail
tar xf toolchain.tar.xz ; check_fail
rm -f toolchain.tar.xz
git clone https://github.com/Joe7500/device_xiaomi_chime.git -b $DEVICE_BRANCH device/xiaomi/chime ; check_fail
git clone https://github.com/Joe7500/vendor_xiaomi_chime.git -b $VENDOR_BRANCH vendor/xiaomi/chime ; check_fail
git clone https://github.com/LineageOS/android_hardware_xiaomi -b $XIAOMI_BRANCH hardware/xiaomi ; check_fail

# Setup AOSP source 
patch -f -p 1 < wfdservice.rc.patch ; check_fail
cd packages/modules/Connectivity/ && git reset --hard && cd -
patch -f -p 1 < InterfaceController.java.patch ; check_fail
rm -f InterfaceController.java.patch wfdservice.rc.patch strings.xml.*
rm -f vendor/xiaomi/chime/proprietary/system_ext/etc/init/wfdservice.rc.rej
rm -f packages/modules/Connectivity/staticlibs/device/com/android/net/module/util/ip/InterfaceController.java.rej

cd packages/apps/Updater/ && git reset --hard && cd -
cp packages/apps/Updater/app/src/main/res/values/strings.xml strings.xml
cat strings.xml | sed -e "s#$OTA_SED_STRING#$OTA_SED_REPLACE_STRING#g" > strings.xml.1
cp strings.xml.1 packages/apps/Updater/app/src/main/res/values/strings.xml
check_fail

# Setup device tree
cd device/xiaomi/chime
cat BoardConfig.mk | grep -v TARGET_KERNEL_CLANG_VERSION > BoardConfig.mk.1
mv BoardConfig.mk.1 BoardConfig.mk
echo 'TARGET_KERNEL_CLANG_VERSION := stablekern' >> BoardConfig.mk
echo 'VENDOR_SECURITY_PATCH := $(PLATFORM_SECURITY_PATCH)' >> BoardConfig.mk
cd -

# Setup kernel

# Get and decrypt signing keys
curl -o keys.1  -L https://raw.githubusercontent.com/Joe7500/build-scripts/refs/heads/main/remote/keys/BinlFm0d0LoeeibAVCofXsbYTCtcRHpo
gpg --pinentry-mode=loopback --passphrase "$GPG_PASS_1" -d keys.1 > keys.2
gpg --pinentry-mode=loopback --passphrase "$GPG_PASS_2" -d keys.2 > keys.tar
tar xf keys.tar
rm -f keys.1 keys.2 keys.tar
curl -o tdl.1  -L https://raw.githubusercontent.com/Joe7500/build-scripts/refs/heads/main/remote/keys/ktdlxIevOo3wGJWrun01W1BzVWvKKZGw
gpg --pinentry-mode=loopback --passphrase "$GPG_PASS_1" -d tdl.1 > tdl.2
gpg --pinentry-mode=loopback --passphrase "$GPG_PASS_2" -d tdl.2 > tdl.tar
tar xf tdl.tar
rm -f tdl.1 tdl.2 tdl.tar
mv tdl.zip /home/admin/

# Build it
if [ "$BUILD_TYPE" == "vanilla" ]; then

   set +v

   source build/envsetup.sh          ; check_fail
   breakfast chime user              ; check_fail
   mka installclean
   mka bacon                         ; check_fail

   set -v

   echo success > result.txt
   notify_send "Build $PACKAGE_NAME on crave.io succeeded."

   # Upload output to gofile
   cp out/target/product/chime/$PACKAGE_NAME*.zip .
   GO_FILE=`ls --color=never -1tr $PACKAGE_NAME*.zip | tail -1`
   GO_FILE_MD5=`md5sum "$GO_FILE"`
   GO_FILE=`pwd`/$GO_FILE
   curl -o goupload.sh -L https://raw.githubusercontent.com/Joe7500/build-scripts/refs/heads/main/remote/utils/gofile.sh
   bash goupload.sh $GO_FILE
   GO_LINK=`cat GOFILE.txt`
   notify_send "MD5:$GO_FILE_MD5 $GO_LINK"
   rm -f goupload.sh GOFILE.txt

   # Upload output to telegram
   if [[ ! -f $GO_FILE ]]; then
      GO_FILE=builder.sh
   fi
   cd /home/admin
   VERSION=$(curl --silent "https://api.github.com/repos/iyear/tdl/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
   wget -O tdl_Linux.tgz https://github.com/iyear/tdl/releases/download/$VERSION/tdl_Linux_64bit.tar.gz ; check_fail
   tar xf tdl_Linux.tgz ; check_fail
   unzip -o -P $TDL_ZIP_PASSWD tdl.zip ; check_fail
   cd /tmp/src/android/
   /home/admin/tdl upload -c $TDL_CHAT_ID -p "$GO_FILE"
   cd /home/admin
   rm -rf .tdl LICENSE  README.md README_zh.md tdl tdl_key tdl_Linux_64bit.tar.gz* venv tdl.sh
   cd /tmp/src/android/

   # Generate and send OTA json file
   curl -o genota.sh -L https://raw.githubusercontent.com/Joe7500/Builds/refs/heads/main/genota.sh
   bash genota.sh lineage 22 "$GO_FILE"
   curl -L -F document=@"$GO_FILE.json.txt" -F caption="OTA $GO_FILE.json.txt" -F chat_id="$TG_CID" -X POST https://api.telegram.org/bot$TG_TOKEN/sendDocument > /dev/null 2>&1
   rm -f genota.sh

   TIME_TAKEN=`printf '%dh:%dm:%ds\n' $((SECONDS/3600)) $((SECONDS%3600/60)) $((SECONDS%60))`
   notify_send "Build $PACKAGE_NAME on crave.io completed. $TIME_TAKEN."

fi

# If time permits, do dirty GAPPS build. 

#if [ $SECONDS -le 12600 ] ; then
#   BUILD_TYPE=gapps
#fi

# Do GAPPS build
#
#
#

#if [ "$BUILD_TYPE" == "gapps" ]; then

# Setup AOSP source

# Setup device tree
   #cd device/xiaomi/chime
   #rm -rf *
   #git reset --hard ; check_fail

   #cat BoardConfig.mk | grep -v TARGET_KERNEL_CLANG_VERSION > BoardConfig.mk.1
   #mv BoardConfig.mk.1 BoardConfig.mk
   #echo 'TARGET_KERNEL_CLANG_VERSION := stablekern' >> BoardConfig.mk
   #echo 'VENDOR_SECURITY_PATCH := $(PLATFORM_SECURITY_PATCH)' >> BoardConfig.mk
   #cd -

# Build it

# Upload output to gofile
   #cp out/target/product/chime/$PACKAGE_NAME*GAPPS*.zip .
   #GO_FILE=`ls --color=never -1tr $PACKAGE_NAME*GAPPS*.zip | tail -1`
   #GO_FILE_MD5=`md5sum "$GO_FILE"`
   #GO_FILE=`pwd`/$GO_FILE
   #curl -o goupload.sh -L https://raw.githubusercontent.com/Joe7500/build-scripts/refs/heads/main/remote/utils/gofile.sh
   #bash goupload.sh $GO_FILE
   #GO_LINK=`cat GOFILE.txt`
   #notify_send "MD5:$GO_FILE_MD5 $GO_LINK"
   #rm -f goupload.sh GOFILE.txt

# Upload output to telegram

   #TIME_TAKEN=`printf '%dh:%dm:%ds\n' $((SECONDS/3600)) $((SECONDS%3600/60)) $((SECONDS%60))`
   #notify_send "Build $PACKAGE_NAME GAPPS on crave.io completed. $TIME_TAKEN."

#fi

cleanup_self
exit 0
