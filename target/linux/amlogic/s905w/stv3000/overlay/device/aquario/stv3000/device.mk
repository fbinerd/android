$(call inherit-product, $(SRC_TARGET_DIR)/product/languages_full.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/generic_no_telephony.mk)

# Copiar kernel pré-compilado para a pasta de saída do produto
PRODUCT_COPY_FILES += \
    device/aquario/stv3000/kernel:kernel \


# Copia do manifest de HALs passthrough
PRODUCT_COPY_FILES += \
    device/aquario/stv3000/manifest.xml:vendor/manifest.xml

# Herdando as cópias de arquivos do vendor proprietário
$(call inherit-product, vendor/aquario/stv3000/stv3000-vendor.mk)

PRODUCT_PACKAGES += \
    wpa_supplicant \
    wpa_cli \
    AquarioMonitor \
    AquarioChromeShortcut \
    AquarioYouTube \
    AquarioChrome \
    AquarioPrimeVideo \
    AquarioAuroraStore \
    AquarioGloboplay

PRODUCT_NAME := aquario_stv3000
PRODUCT_DEVICE := stv3000

# Mali-450 r8p0 advertises native fences but eglDupNativeFenceFDANDROID fails.
PRODUCT_PROPERTY_OVERRIDES += \
    ro.aquario.disable_native_fence_sync=1

# Arquivos de inicialização específicos do Aquário STV-3000
PRODUCT_COPY_FILES += \
    device/aquario/stv3000/init.amlogic.rc:root/init.amlogic.rc \
    device/aquario/stv3000/init.aquario.postboot.sh:root/init.aquario.postboot.sh \
    device/aquario/stv3000/init.aquario.metrics.sh:root/init.aquario.metrics.sh \
    device/aquario/stv3000/odm/default.prop:odm/default.prop \
    device/aquario/stv3000/odm/ueventd.rc:odm/ueventd.rc \
    device/aquario/stv3000/media/bootanimation.zip:system/media/bootanimation.zip \
    device/aquario/stv3000/ueventd.amlogic.rc:root/ueventd.amlogic.rc \
    device/aquario/stv3000/fstab.amlogic:root/fstab.amlogic

# Arquivos originais do ramdisk Amlogic STV-3000
PRODUCT_COPY_FILES += \
    device/aquario/stv3000/init.amlogic.usb.rc:root/init.amlogic.usb.rc \
    device/aquario/stv3000/init.amlogic.board.rc:root/init.amlogic.board.rc \
    device/aquario/stv3000/init.amlogic.wifi.rc:root/init.amlogic.wifi.rc
