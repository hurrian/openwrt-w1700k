include $(TOPDIR)/rules.mk

ARCH:=arm
BOARD:=airoha
BOARDNAME:=Airoha ARM
SUBTARGETS:=en7523 an7581
FEATURES:=dt squashfs nand ramdisk gpio

KERNEL_PATCHVER:=6.6
KERNEL_TESTING_PATCHVER:=6.12

include $(INCLUDE_DIR)/target.mk
DEFAULT_PACKAGES += \
	kmod-leds-gpio kmod-gpio-button-hotplug

$(eval $(call BuildTarget))
