# Arquitetura do processador
TARGET_CPU_ABI := armeabi-v7a
TARGET_CPU_ABI2 := armeabi
TARGET_ARCH := arm
TARGET_ARCH_VARIANT := armv7-a-neon
TARGET_CPU_VARIANT := generic

# Plataforma Amlogic original do STV-3000
TARGET_BOARD_PLATFORM := gxl

# The SV6051P driver is a mac80211/nl80211 SoftMAC device.
WPA_SUPPLICANT_VERSION := VER_0_8_X
BOARD_WPA_SUPPLICANT_DRIVER := NL80211
BOARD_HOSTAPD_DRIVER := NL80211

# Kernel pre-compilado e cmdline. A cmdline abaixo vem do boot funcional
# do firmware original Aquario/STV-3000 e habilita log serial cedo.
TARGET_NO_KERNEL := false
TARGET_PREBUILT_KERNEL := device/aquario/stv3000/kernel
BOARD_PREBUILT_DTBIMAGE_DIR := device/aquario/stv3000
BOARD_KERNEL_CMDLINE := rootfstype=ramfs init=/init console=ttyS0,115200 no_console_suspend earlyprintk=aml-uart,0xc81004c0 ramoops.pstore_en=1 ramoops.record_size=0x8000 ramoops.console_size=0x4000 androidboot.selinux=permissive logo=osd1,loaded,0x3d800000,576cvbs maxcpus=4 vout=576cvbs,enable hdmimode=1080p60hz cvbsmode=576cvbs cvbsdrv=0 androidboot.firstboot=0 jtag=apao androidboot.hardware=amlogic androidboot.slot_suffix=_a buildvariant=userdebug

# Configurações de endereços do Kernel e bootloader da Amlogic
BOARD_KERNEL_BASE := 0x00000000
BOARD_KERNEL_PAGESIZE := 2048
BOARD_MKBOOTIMG_ARGS := --kernel_offset 0x01080000 --ramdisk_offset 0x01000000 --second_offset 0x00f00000 --tags_offset 0x00000100


# Layout original do aquario.img nao tem particoes vendor/odm.
# Android 9 precisa rodar como build legacy, com blobs em /system/vendor.
BOARD_USES_VENDORIMAGE := false
PRODUCT_FULL_TREBLE_OVERRIDE := false

# Configurações do filesystem ext4
TARGET_USERIMAGES_USE_EXT4 := true
BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_CACHEIMAGE_FILE_SYSTEM_TYPE := ext4

BOARD_BOOTIMAGE_PARTITION_SIZE := 33554432
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 33554432
BOARD_SYSTEMIMAGE_PARTITION_SIZE := 2147483648
BOARD_USERDATAIMAGE_PARTITION_SIZE := 4743757824
BOARD_CACHEIMAGE_PARTITION_SIZE := 536870912

# SEPolicy
BOARD_SEPOLICY_DIRS += device/aquario/stv3000/sepolicy
