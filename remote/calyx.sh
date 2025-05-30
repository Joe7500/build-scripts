#!/bin/bash

source /home/admin/.profile
source /home/admin/.bashrc
source /tmp/crave_bashrc

cd /tmp/src/android/

set -v

# Template helper variables
PACKAGE_NAME=calyx
VARIANT_NAME=user
BUILD_TYPE=vanilla
DEVICE_BRANCH=lineage-22.2
VENDOR_BRANCH=lineage-22.2
XIAOMI_BRANCH=lineage-22.2
REPO_URL="--git-lfs -u https://gitlab.com/CalyxOS/platform_manifest -b android15-qpr2 --git-lfs"
#OTA_SED_STRING="https://download.lineageos.org/api/v1/{device}/{type}/{incr}"
#OTA_SED_REPLACE_STRING="https://raw.githubusercontent.com/Joe7500/Builds/main/$PACKAGE_NAME.$VARIANT_NAME.chime.json"

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
   rm -rf vendor/lineage-priv/keys
   rm -rf vendor/lineage-priv
   rm -rf priv-keys
   rm -rf .config/b2/
   rm -rf /home/admin/.config/b2/
   cd packages/apps/Updater/ && git reset --hard && cd ../../../
   cd packages/modules/Connectivity/ && git reset --hard && cd ../../../
   rm -rf prebuilts/clang/kernel/linux-x86/clang-stablekern/
   rm -rf prebuilts/clang/host/linux-x86/clang-stablekern/
   rm -rf hardware/xiaomi/
   rm -rf device/xiaomi/chime/
   rm -rf vendor/xiaomi/chime/
   rm -rf kernel/xiaomi/chime/
   rm -f InterfaceController.java.patch wfdservice.rc.patch strings.xml* builder.sh goupload.sh GOFILE.txt
   rm -rf /tmp/android-certs*
   rm -rf /home/admin/venv/
   rm -rf custom_scripts/
   cd /home/admin
   rm -rf .tdl
   rm -rf  LICENSE  README.md  README_zh.md  tdl  tdl_key  tdl_Linux_64bit.tar.gz* venv tdl.zip tdl_Linux.tgz
   rm -f tdl.sh
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
   repo init $REPO_URL  ; check_fail
   cleanup_self
   # Calyx hates these git repos
   rm -rf prebuilts/gcc/
   for i in `find .repo/ | grep 'prebuilts/gcc'`; do
      rm -rf $i
   done
   /opt/crave/resync.sh || /opt/crave/resync.sh
   /opt/crave/resync.sh || /opt/crave/resync.sh ; check_fail
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
#patch -f -p 1 < wfdservice.rc.patch ; check_fail
#cd packages/modules/Connectivity/ && git reset --hard && cd ../../../
#patch -f -p 1 < InterfaceController.java.patch ; check_fail
#rm -f InterfaceController.java.patch wfdservice.rc.patch strings.xml.*
#rm -f vendor/xiaomi/chime/proprietary/system_ext/etc/init/wfdservice.rc.rej
#rm -f packages/modules/Connectivity/staticlibs/device/com/android/net/module/util/ip/InterfaceController.java.rej

#cd packages/apps/Updater/ && git reset --hard && cd ../../../
#cp packages/apps/Updater/app/src/main/res/values/strings.xml strings.xml
#cat strings.xml | sed -e "s#$OTA_SED_STRING#$OTA_SED_REPLACE_STRING#g" > strings.xml.1
#cp strings.xml.1 packages/apps/Updater/app/src/main/res/values/strings.xml
#check_fail

git clone https://android.googlesource.com/platform/external/tinyxml external/tinyxml
cd external/tinyxml
git revert --no-edit 6e88470e56d725d4dc4225f0218a5bb09a009953
cd ../../

curl -o hardware_calyx_interfaces_power-libperfmgr.tgz -L https://raw.githubusercontent.com/Joe7500/build-scripts/refs/heads/main/remote/hardware_calyx_interfaces_power-libperfmgr.tgz
tar xf hardware_calyx_interfaces_power-libperfmgr.tgz
rm -f hardware_calyx_interfaces_power-libperfmgr.tgz

rm -rf vendor/qcom/opensource/power
rm -rf device/motorola/

# Setup device tree
cat device/xiaomi/chime/BoardConfig.mk | grep -v TARGET_KERNEL_CLANG_VERSION > device/xiaomi/chime/BoardConfig.mk.1
mv device/xiaomi/chime/BoardConfig.mk.1 device/xiaomi/chime/BoardConfig.mk
echo 'TARGET_KERNEL_CLANG_VERSION := stablekern' >> device/xiaomi/chime/BoardConfig.mk

echo 'VENDOR_SECURITY_PATCH := $(PLATFORM_SECURITY_PATCH)' >> device/xiaomi/chime/BoardConfig.mk

cd device/xiaomi/chime/

cat AndroidProducts.mk | sed -e s/lineage/calyx/g > AndroidProducts.mk.1
mv AndroidProducts.mk.1 AndroidProducts.mk

cat lineage_chime.mk | sed -e s/lineage/calyx/g > lineage_chime.mk.1
mv lineage_chime.mk.1 lineage_chime.mk

cat lineage_chime.mk | sed -e s/common_full_phone.mk/common_phone.mk/g > lineage_chime.mk.1
mv lineage_chime.mk.1 lineage_chime.mk

cat lineage_chime.mk | grep -v "RESERVE_SPACE_FOR_GAPPS" > lineage_chime.mk.1
mv lineage_chime.mk.1 lineage_chime.mk
echo "RESERVE_SPACE_FOR_GAPPS := false" >> lineage_chime.mk

mv lineage_chime.mk calyx_chime.mk

#cat Android.bp | sed -e 's#hardware/lineage/interfaces/power-libperfmgr#hardware/calyx/interfaces/power-libperfmgr#g' > Android.bp.1
#cat Android.bp | grep -v 'hardware/lineage/interfaces/power-libperfmgr' > Android.bp.1
cat Android.bp | sed -e 's#hardware/lineage/interfaces/power-libperfmgr#hardware/calyx/interfaces/power-libperfmgr#g' > Android.bp.1
mv Android.bp.1 Android.bp

cat device.mk | grep -v libstdc++_vendor > device.mk.1
mv device.mk.1 device.mk

cat device.mk | grep -v 'vendor/lineage-priv/keys/keys.mk' > device.mk.1
mv device.mk.1 device.mk

#cat device.mk | sed -e 's/android.hardware.power-service.lineage-libperfmgr/android.hardware.power-service.pixel-libperfmgr/g' > device.mk.1
cat device.mk | sed -e 's#hardware/lineage/interfaces/power-libperfmgr#hardware/calyx/interfaces/power-libperfmgr#g' > device.mk.1
mv device.mk.1 device.mk

cat BoardConfig.mk | sed -e s#vendor/lineage/config/device_framework_matrix.xml#vendor/calyx/config/device_framework_matrix.xml#g > BoardConfig.mk.1
mv BoardConfig.mk.1 BoardConfig.mk
cat BoardConfig.mk | sed -e s#device/lineage/sepolicy/libperfmgr/sepolicy.mk#device/calyx/sepolicy/libperfmgr/sepolicy.mk#g > BoardConfig.mk.1
mv BoardConfig.mk.1 BoardConfig.mk

echo 'BUILD_BROKEN_PREBUILT_ELF_FILES := true' >> BoardConfig.mk
echo 'TARGET_DISABLE_EPPE := true' >> BoardConfig.mk

cd ../../../

# Get dev secrets from bucket.
sudo apt --yes install python3-virtualenv virtualenv python3-pip-whl
rm -rf /home/admin/venv
virtualenv /home/admin/venv ; check_fail
set +v
source /home/admin/venv/bin/activate
set -v
pip install --upgrade b2 ; check_fail
#b2 account authorize "$BKEY_ID" "$BAPP_KEY" > /dev/null 2>&1 ; check_fail
#mkdir priv-keys
#b2 sync "b2://$BUCKET_NAME/inline" "priv-keys" > /dev/null 2>&1 ; check_fail
#b2 sync "b2://$BUCKET_NAME/tdl" "/home/admin" > /dev/null 2>&1 ; check_fail
#mkdir --parents vendor/lineage-priv/keys
#mv priv-keys/* vendor/lineage-priv/keys
#rm -rf priv-keys
#rm -rf .config/b2/
#rm -rf /home/admin/.config/b2/
deactivate
unset BUCKET_NAME
unset KEY_ENCRYPTION_PASSWORD
unset BKEY_ID
unset BAPP_KEY
unset KEY_PASSWORD
cat /tmp/crave_bashrc | grep -vE "BKEY_ID|BUCKET_NAME|KEY_ENCRYPTION_PASSWORD|BAPP_KEY|TG_CID|TG_TOKEN" > /tmp/crave_bashrc.1
mv /tmp/crave_bashrc.1 /tmp/crave_bashrc

sleep 10

# Build it
set +v

source build/envsetup.sh          ; check_fail
breakfast chime user              ; check_fail
m installclean
m                         ; check_fail
m target-files-package
m otatools-package otatools-keys-package

set -v

rm -rf sign
mkdir sign
cd sign
tar xf ../keys.tgz
cp ../out/target/product/chime/otatools.zip .
unzip otatools.zip
cp ../out/target/product/chime/obj/PACKAGING/target_files_intermediates/*.zip .

cat vendor/calyx/scripts/release.sh | sed -e s/comet/chime/g > vendor/calyx/scripts/release.sh.1
mv vendor/calyx/scripts/release.sh.1 vendor/calyx/scripts/release.sh
chmod u+x ./vendor/calyx/scripts/release.sh
./vendor/calyx/scripts/release.sh chime calyx_chime-target_files.zip

echo success > result.txt
notify_send "Build $PACKAGE_NAME on crave.io succeeded."

# Upload output to gofile
#cp out/target/product/chime/$PACKAGE_NAME*.zip .
#GO_FILE=`ls --color=never -1tr $PACKAGE_NAME*.zip | tail -1`
#GO_FILE_MD5=`md5sum "$GO_FILE"`
#GO_FILE=`pwd`/$GO_FILE
#curl -o goupload.sh -L https://raw.githubusercontent.com/Joe7500/Builds/refs/heads/main/crave/gofile.sh
#bash goupload.sh $GO_FILE
#GO_LINK=`cat GOFILE.txt`
#notify_send "MD5:$GO_FILE_MD5 $GO_LINK"
#rm -f goupload.sh GOFILE.txt

# Upload output to telegram
#if [[ ! -f $GO_FILE ]]; then
#   GO_FILE=builder.sh
#fi
#cd /home/admin
#VERSION=$(curl --silent "https://api.github.com/repos/iyear/tdl/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
#wget -O tdl_Linux.tgz https://github.com/iyear/tdl/releases/download/$VERSION/tdl_Linux_64bit.tar.gz ; check_fail
#tar xf tdl_Linux.tgz ; check_fail
#unzip -o -P $TDL_ZIP_PASSWD tdl.zip ; check_fail
#cd /tmp/src/android/
#/home/admin/tdl upload -c $TDL_CHAT_ID -p "$GO_FILE"
#cd /home/admin
#rm -rf .tdl
#rm -rf  LICENSE  README.md  README_zh.md  tdl  tdl_key  tdl_Linux_64bit.tar.gz* venv
#rm -f tdl.sh
#cd /tmp/src/android/

TIME_TAKEN=`printf '%dh:%dm:%ds\n' $((SECONDS/3600)) $((SECONDS%3600/60)) $((SECONDS%60))`
notify_send "Build $PACKAGE_NAME on crave.io completed. $TIME_TAKEN."

if [ "$BUILD_TYPE" == "vanilla" ]; then
   cleanup_self
   exit 0
fi

# Do gapps dirty build
#
#
#

# Setup AOSP source

# Setup device tree

# Build it

# Upload output to gofile

# Upload output to telegram

cleanup_self
exit 0
