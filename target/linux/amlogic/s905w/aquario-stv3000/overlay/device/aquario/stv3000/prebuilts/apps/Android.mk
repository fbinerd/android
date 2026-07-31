LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)
LOCAL_MODULE := AquarioYouTube
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_CLASS := APPS
LOCAL_MODULE_SUFFIX := $(COMMON_ANDROID_PACKAGE_SUFFIX)
LOCAL_SRC_FILES := YouTubeTV/base.apk
LOCAL_REPLACE_PREBUILT_APK_INSTALLED := $(LOCAL_PATH)/YouTubeTV/base.apk
LOCAL_PACKAGE_SPLITS := \
    YouTubeTV/split_config.armeabi_v7a.apk
LOCAL_MODULE_STEM := base.apk
LOCAL_PRIVILEGED_MODULE := true
LOCAL_CERTIFICATE := PRESIGNED
LOCAL_DEX_PREOPT := false
include $(BUILD_PREBUILT)

include $(CLEAR_VARS)
LOCAL_MODULE := AquarioAuroraStore
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_CLASS := APPS
LOCAL_MODULE_SUFFIX := $(COMMON_ANDROID_PACKAGE_SUFFIX)
LOCAL_SRC_FILES := AuroraStore/base.apk
LOCAL_MODULE_STEM := base.apk
LOCAL_CERTIFICATE := PRESIGNED
LOCAL_DEX_PREOPT := false
include $(BUILD_PREBUILT)

include $(CLEAR_VARS)
LOCAL_MODULE := AquarioGloboplay
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_CLASS := APPS
LOCAL_MODULE_SUFFIX := $(COMMON_ANDROID_PACKAGE_SUFFIX)
LOCAL_SRC_FILES := Globoplay/base.apk
LOCAL_REPLACE_PREBUILT_APK_INSTALLED := $(LOCAL_PATH)/Globoplay/base.apk
LOCAL_PACKAGE_SPLITS := \
    Globoplay/config.armeabi_v7a.apk \
    Globoplay/config.pt.apk \
    Globoplay/config.tvdpi.apk
LOCAL_MODULE_STEM := base.apk
LOCAL_CERTIFICATE := PRESIGNED
LOCAL_DEX_PREOPT := false
include $(BUILD_PREBUILT)

include $(CLEAR_VARS)
LOCAL_MODULE := AquarioPrimeVideo
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_CLASS := APPS
LOCAL_MODULE_SUFFIX := $(COMMON_ANDROID_PACKAGE_SUFFIX)
LOCAL_SRC_FILES := PrimeVideo/base.apk
LOCAL_PACKAGE_SPLITS := \
    PrimeVideo/config.armeabi_v7a.apk \
    PrimeVideo/config.en.apk \
    PrimeVideo/config.pt.apk \
    PrimeVideo/config.xhdpi.apk
LOCAL_MODULE_STEM := base.apk
LOCAL_CERTIFICATE := PRESIGNED
LOCAL_DEX_PREOPT := false
include $(BUILD_PREBUILT)

include $(CLEAR_VARS)
LOCAL_MODULE := AquarioChrome
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_CLASS := APPS
LOCAL_MODULE_SUFFIX := $(COMMON_ANDROID_PACKAGE_SUFFIX)
LOCAL_SRC_FILES := Chrome/base.apk
LOCAL_PACKAGE_SPLITS := \
    Chrome/split_chrome.apk \
    Chrome/split_config.en.apk \
    Chrome/split_config.pt.apk \
    Chrome/split_google3.apk
LOCAL_MODULE_STEM := base.apk
LOCAL_CERTIFICATE := PRESIGNED
LOCAL_DEX_PREOPT := false
include $(BUILD_PREBUILT)
