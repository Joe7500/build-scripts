#!/bin/bash

source /home/admin/.profile
source /home/admin/.bashrc
source /tmp/crave_bashrc

cd /tmp/src/android/

set -v

# Template helper variables
PACKAGE_NAME=voltage-5
VARIANT_NAME=user
BUILD_TYPE=vanilla
DEVICE_BRANCH=lineage-23.0
VENDOR_BRANCH=lineage-23.0
XIAOMI_BRANCH=lineage-23.0
GENOTA_ARG_1="voltage"
GENOTA_ARG_2="23"
REPO_PARAMS=" --git-lfs --depth=1 --no-tags --no-clone-bundle"
REPO_URL="-u https://github.com/VoltageOS/manifest.git -b 16 $REPO_PARAMS"
OTA_SED_STRING="VoltageOS/android_vendor_voltageota/16/{device}.json"
OTA_SED_REPLACE_STRING="Joe7500/Builds/main/$PACKAGE_NAME.$VARIANT_NAME.$BUILD_TYPE.chime.json"
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

notify_send "Build $PACKAGE_NAME on crave.io started."

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
   cd vendor/voltage-priv/keys && rm -rf * && git reset --hard && cd /tmp/src/android/
}

# Better than ' || exit 1 '
check_fail () {
   if [ $? -ne 0 ]; then 
       if ls out/target/product/chime/$PACKAGE_NAME*.zip; then
          notify_send "Build $PACKAGE_NAME on crave.io softfailed."
          echo weird. build failed but OTA package exists.
          cleanup_self
          echo softfail > result.txt
          exit 1
       else
          notify_send "Build $PACKAGE_NAME on crave.io failed."
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
curl -o kernel.tar.xz -L "https://github.com/Joe7500/Builds/releases/download/Stuff/kernel-prebuilt-perf-lilium-ksun.tar.xz" ; check_fail
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

cd packages/apps/Updater/ && git reset --hard && cd -
cp packages/apps/Updater/app/src/main/res/values/strings.xml strings.xml
cat strings.xml | sed -e "s#$OTA_SED_STRING#$OTA_SED_REPLACE_STRING#g" > strings.xml.1
cp strings.xml.1 packages/apps/Updater/app/src/main/res/values/strings.xml
rm -f strings.xml.1
check_fail

sed -i -e 's#ifeq ($(call is-version-lower-or-equal,$(TARGET_KERNEL_VERSION),6.1),true)#ifeq ($(BOARD_USES_QCOM_HARDWARE),true)#g' vendor/voltage/build/tasks/kernel.mk
sed -i -e 's#ifeq ($(call is-version-greater-or-equal,$(TARGET_KERNEL_VERSION),5.15),true)#ifeq ($(BOARD_USES_QCOM_HARDWARE),true)#g' vendor/voltage/build/tasks/kernel.mk
sed -i -e 's#GKI_SUFFIX := /$(shell echo android$(PLATFORM_VERSION)-$(TARGET_KERNEL_VERSION))#NOT_NEEDED_DISCARD_567 := true#g' vendor/voltage/build/tasks/kernel.mk

cd vendor/voltage/
cat config/version.mk | sed -e 's/UNOFFICIAL/COMMUNITY/g' > config/version.mk.1
mv config/version.mk.1 config/version.mk
cd ../..

rm -f hardware/qcom/sm7250/Android.bp hardware/qcom/sm7250/Android.mk
rm -f hardware/qcom/sdm845/Android.bp hardware/qcom/sdm845/Android.mk
rm -f hardware/qcom/sm8150/Android.bp hardware/qcom/sm8150/Android.mk

# Setup device tree
cat device/xiaomi/chime/BoardConfig.mk | grep -v TARGET_KERNEL_CLANG_VERSION > device/xiaomi/chime/BoardConfig.mk.1
mv device/xiaomi/chime/BoardConfig.mk.1 device/xiaomi/chime/BoardConfig.mk
echo 'TARGET_KERNEL_CLANG_VERSION := stablekern' >> device/xiaomi/chime/BoardConfig.mk

cd device/xiaomi/chime/
cat device.mk | sed -e 's#vendor/lineage-priv/keys/keys.mk#vendor/voltage-priv/keys/keys.mk#g' > device.mk.1
mv device.mk.1 device.mk
cat AndroidProducts.mk | sed -e s/lineage/voltage/g > AndroidProducts.mk.1
mv AndroidProducts.mk.1 AndroidProducts.mk

#cat BoardConfig.mk | sed -e s#vendor/lineage/config/device_framework_matrix.xml#vendor/voltage/config/device_framework_matrix.xml#g > BoardConfig.mk.1
#cat BoardConfig.mk | grep -iv 'vendor/lineage/config/device_framework_matrix.xml' > BoardConfig.mk.1
#mv BoardConfig.mk.1 BoardConfig.mk
curl -o lineage_frame.xml -L https://raw.githubusercontent.com/LineageOS/android_vendor_lineage/refs/heads/lineage-22.2/config/device_framework_matrix.xml
mkdir ../../../vendor/lineage
mkdir ../../../vendor/lineage/config
mv lineage_frame.xml ../../../vendor/lineage/config/device_framework_matrix.xml

cat BoardConfig.mk | sed -e s#device/lineage/sepolicy/libperfmgr/sepolicy.mk#device/voltage/sepolicy/libperfmgr/sepolicy.mk#g > BoardConfig.mk.1
mv BoardConfig.mk.1 BoardConfig.mk
cat lineage_chime.mk | sed -e s/lineage/voltage/g > lineage_chime.mk.1
mv lineage_chime.mk.1 lineage_chime.mk
mv lineage_chime.mk voltage_chime.mk
echo 'BUILD_BROKEN_PREBUILT_ELF_FILES := true' >> BoardConfig.mk
echo 'TARGET_DISABLE_EPPE := true' >> BoardConfig.mk
echo 'VENDOR_SECURITY_PATCH := $(PLATFORM_SECURITY_PATCH)' >> BoardConfig.mk

mkdir --parents overlay-lineage/packages/apps/Settings/res/values
echo '<?xml version="1.0" encoding="utf-8"?>' > overlay-lineage/packages/apps/Settings/res/values/voltage_strings.xml
echo '<resources xmlns:xliff="urn:oasis:names:tc:xliff:document:1.2">' >> overlay-lineage/packages/apps/Settings/res/values/voltage_strings.xml
echo '<string name="voltage_maintainer">Joe</string>' >> overlay-lineage/packages/apps/Settings/res/values/voltage_strings.xml
echo '</resources>' >> overlay-lineage/packages/apps/Settings/res/values/voltage_strings.xml

mkdir --parents overlay-lineage/packages/apps/Powerhub/res/values
echo '<?xml version="1.0" encoding="utf-8"?>
<PreferenceScreen
    xmlns:android="http://schemas.android.com/apk/res/android"
    android:title="@string/statusbar_title"
    xmlns:settings="http://schemas.android.com/apk/res/com.android.settings">
    <com.voltage.support.preferences.SecureSettingListPreference
        android:key="qs_brightness_slider_enabled"
        android:title="@string/status_bar_brightness_slider_title"
        android:summary="%s"
        android:dialogTitle="@string/status_bar_brightness_slider_title"
        android:entries="@array/status_bar_brightness_slider_entries"
        android:entryValues="@array/status_bar_brightness_slider_values"
        android:defaultValue="1" />
</PreferenceScreen>' > overlay-lineage/packages/apps/Powerhub/res/values/powerhub_statusbar.xml

cd ../../../

echo 'persist.sys.activity_anim_perf_override=true' >> device/xiaomi/chime/configs/props/system.prop
echo 'PRODUCT_PACKAGES += Updater' >> device/xiaomi/chime/device.mk

# Setup kernel

# Get and decrypt signing keys
curl -o keys.1  -L https://raw.githubusercontent.com/Joe7500/build-scripts/refs/heads/main/remote/keys/vvoloOqXuBFNu8wTDmPB8vbawCQzSEli
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
breakfast chime user              ; check_fail
mka installclean
mka bacon                         ; check_fail

set -v

echo success > result.txt
notify_send "Build $PACKAGE_NAME on crave.io succeeded."

# Upload output to pixeldrain
cp out/target/product/chime/$PACKAGE_NAME*.zip .
GO_FILE=`ls --color=never -1tr $PACKAGE_NAME*.zip | tail -1`
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
notify_send "Build $PACKAGE_NAME on crave.io completed. $TIME_TAKEN."

cleanup_self
exit 0
