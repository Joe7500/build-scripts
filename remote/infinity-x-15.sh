#!/bin/bash

source /home/admin/.profile
source /home/admin/.bashrc
source /tmp/crave_bashrc

cd /tmp/src/android/

set -v

# Template helper variables
PACKAGE_NAME=Project_Infinity-X-2
VARIANT_NAME=user
BUILD_TYPE=vanilla
if echo $@ | grep BUILD_GAPPS; then
   BUILD_TYPE=gapps
   PACKAGE_NAME_TYPE="$PACKAGE_NAME*GAPPS"
else
   PACKAGE_NAME_TYPE="$PACKAGE_NAME"
fi

DEVICE_BRANCH=lineage-22.2
VENDOR_BRANCH=lineage-22.2
XIAOMI_BRANCH=lineage-22.2
GENOTA_ARG_1="infinty"
GENOTA_ARG_2="2"
REPO_PARAMS=" --git-lfs --depth=1 --no-tags --no-clone-bundle -g default,-mips,-darwin,-notdefault --no-repo-verify"
REPO_URL=" -u https://github.com/ProjectInfinity-X/manifest -b 15 $REPO_PARAMS"
OTA_SED_STRING="ProjectInfinity-X/official_devices/16/vanilla/{device}.json"
OTA_SED_REPLACE_STRING="Joe7500/Builds/main/$PACKAGE_NAME.$VARIANT_NAME.chime.json"
SECONDS=0
export TZ=Africa/Harare
if echo $@ | grep "JJ_SPEC:" ; then export JJ_SPEC=`echo $@ | cut -d ":" -f 2` ; fi
TG_URL="https://api.telegram.org/bot$TG_TOKEN/sendMessage"

# Send push notifications
notify_send() {
   local MSG
   MSG="$@"
   curl -s -X POST $TG_URL -d chat_id=$TG_CID -d text="$MSG - $BUILD_TYPE `date`. JJ_SPEC:$JJ_SPEC" > /dev/null 2>&1
   curl -s -d "$MSG - $BUILD_TYPE `date`. JJ_SPEC:$JJ_SPEC" "ntfy.sh/$NTFYSUB" > /dev/null 2>&1
}

notify_send "Build $PACKAGE_NAME_TYPE on crave.io started."

# Always cleanup
cleanup_self () {
   cd /tmp/src/android/
   rm -rf keys.1 keys.2 keys.tar tdl.1 tdl.2 tdl.tar tdl.zip sf
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
          notify_send "Build $PACKAGE_NAME_TYPE on crave.io softfailed."
          echo weird. build failed but OTA package exists.
          cleanup_self
	  echo softfail > result.txt
          exit 1
       else
          notify_send "Build $PACKAGE_NAME_TYPE on crave.io failed."
	  echo "oh no. script failed"
	  curl -L -F document=@"out/error.log" -F caption="error log" -F chat_id="$TG_CID" -X POST https://api.telegram.org/bot$TG_TOKEN/sendDocument > /dev/null 2>&1
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
   rm -rf .repo/manifests*
   repo init $REPO_URL --git-lfs ; check_fail
   cleanup_self
   /opt/crave/resync.sh ; check_fail
fi

# Download trees
rm -rf kernel/xiaomi/chime/ vendor/xiaomi/chime/ device/xiaomi/chime/ hardware/xiaomi/
rm -rf prebuilts/clang/host/linux-x86/clang-stablekern/
curl -o kernel.tar.xz -L "https://github.com/Joe7500/Builds/releases/download/Stuff/kernel.tar.xz" ; check_fail
tar xf kernel.tar.xz ; check_fail ; rm -f kernel.tar.xz
curl -o lineage-22.1.tar.xz -L "https://github.com/Joe7500/Builds/releases/download/Stuff/lineage-22.1.tar.xz" ; check_fail
tar xf lineage-22.1.tar.xz ; check_fail ; rm -f lineage-22.1.tar.xz
curl -o toolchain.tar.xz -L "https://github.com/Joe7500/Builds/releases/download/Stuff/toolchain.tar.xz" ; check_fail
tar xf toolchain.tar.xz ; check_fail ; rm -f toolchain.tar.xz
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
cp vendor/infinity/overlay/updater/res/values/strings.xml strings.xml
cat strings.xml | sed -e "s#$OTA_SED_STRING#$OTA_SED_REPLACE_STRING.gapps.json#g" > strings.xml.1
cp strings.xml.1 vendor/infinity/overlay/updater/res/values/strings.xml
check_fail

for i in `grep -R '<string name="unofficial_build_suffix">' packages/apps/Settings/res | cut -d ':' -f 1` ; do
  cat $i | sed -e 's#<string name="unofficial_build_suffix">.*string>#<string name="unofficial_build_suffix">- Community</string>#g' > $i.1
  mv $i.1 $i
done

cd vendor/infinity/
git reset --hard
cat config/version.mk | sed -e 's/INFINITY_BUILD_TYPE ?= UNOFFICIAL/INFINITY_BUILD_TYPE := COMMUNITY/g' > config/version.mk.1
mv config/version.mk.1 config/version.mk
cd ../..

# Setup device tree
cd device/xiaomi/chime

git revert --no-edit 6cece0c9cf6aa7d4ed5380605fed9b90f63c250c # Squiggly media progress bar, depends on ROM

 #bringup infinity
cat AndroidProducts.mk | sed -e s/lineage/infinity/g > AndroidProducts.mk.1
mv AndroidProducts.mk.1 AndroidProducts.mk
cat lineage_chime.mk | sed -e s/lineage/infinity/g > lineage_chime.mk.1
mv lineage_chime.mk.1 lineage_chime.mk
cat lineage_chime.mk | grep -v RESERVE_SPACE_FOR_GAPPS > lineage_chime.mk.1
mv lineage_chime.mk.1 lineage_chime.mk
cat lineage_chime.mk | grep -v WITH_GAPPS > lineage_chime.mk.1
mv lineage_chime.mk.1 lineage_chime.mk
mv lineage_chime.mk infinity_chime.mk
cat BoardConfig.mk | sed -e s#vendor/lineage/config/device_framework_matrix.xml#vendor/infinity/config/device_framework_matrix.xml#g > BoardConfig.mk.1
mv BoardConfig.mk.1 BoardConfig.mk
echo 'ro.product.marketname=POCO M3 / Redmi 9T' >> configs/props/system.prop
echo 'ro.infinity.soc=Qualcomm SM6115 Snapdragon 662' >> configs/props/system.prop
echo 'ro.infinity.battery=6000 mAh' >> configs/props/system.prop
echo 'ro.infinity.display=1080 x 2340' >> configs/props/system.prop
echo 'ro.infinity.camera=48MP + 8MP' >> configs/props/system.prop
echo 'INFINITY_MAINTAINER := "Joe"' >> infinity_chime.mk

 #gapps variant 
if [ "$BUILD_TYPE" == "gapps" ]; then
   echo 'WITH_GAPPS := true' >> infinity_chime.mk
   echo 'RESERVE_SPACE_FOR_GAPPS := false' >> infinity_chime.mk
else
   echo 'WITH_GAPPS := false' >> infinity_chime.mk
   echo 'RESERVE_SPACE_FOR_GAPPS := true' >> infinity_chime.mk
fi

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

# Build it

set +v

source build/envsetup.sh          ; check_fail
export BUILD_USERNAME=user
export BUILD_HOSTNAME=localhost
export KBUILD_BUILD_USER=user
export KBUILD_BUILD_HOST=localhost
lunch infinity_chime-user         ; check_fail
mka installclean
mka bacon                         ; check_fail

set -v

echo success > result.txt
notify_send "Build $PACKAGE_NAME_TYPE on crave.io succeeded."

# Upload output to pixeldrain
cp out/target/product/chime/$PACKAGE_NAME_TYPE*.zip .
GO_FILE=`ls --color=never -1tr $PACKAGE_NAME_TYPE*.zip | tail -1`
GO_FILE_MD5=`md5sum "$GO_FILE"`
GO_FILE=`pwd`/$GO_FILE
if [[ ! -f $GO_FILE ]]; then
   GO_FILE=builder.sh
fi
curl -T "$GO_FILE" -u :$PDAPIKEY https://pixeldrain.com/api/file/ > out.json
PD_ID=`cat out.json | cut -d '"' -f 4`
notify_send "MD5:$GO_FILE_MD5 https://pixeldrain.com/u/$PD_ID"
rm -f out.json

# Upload file to SF
curl -o keys.1  -L https://raw.githubusercontent.com/Joe7500/build-scripts/refs/heads/main/remote/keys/usfJoFvObArLx0KmBzwerPPTzliixTN2
gpg --pinentry-mode=loopback --passphrase "$GPG_PASS_1" -d keys.1 > keys.2
gpg --pinentry-mode=loopback --passphrase "$GPG_PASS_2" -d keys.2 > sf
chmod a-x sf
chmod go-rwx sf
rsync -avP -e 'ssh -i ./sf -o "StrictHostKeyChecking accept-new"' $GO_FILE $SF_URL
rm -f keys.1 keys.2 sf

# Generate and send OTA json file
curl -o genota.sh -L https://raw.githubusercontent.com/Joe7500/Builds/refs/heads/main/genota.sh
bash genota.sh "$GENOTA_ARG_1" "$GENOTA_ARG_2" "$GO_FILE"
curl -L -F document=@"$GO_FILE.json.txt" -F caption="OTA $GO_FILE.json.txt" -F chat_id="$TG_CID" -X POST https://api.telegram.org/bot$TG_TOKEN/sendDocument > /dev/null 2>&1
rm -f genota.sh

TIME_TAKEN=`printf '%dh:%dm:%ds\n' $((SECONDS/3600)) $((SECONDS%3600/60)) $((SECONDS%60))`
notify_send "Build $PACKAGE_NAME_TYPE on crave.io completed. $TIME_TAKEN."

cleanup_self
exit 0
