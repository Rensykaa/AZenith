#!/system/bin/sh
# devinfo.sh : detect the device and print its info.
case "$0" in */*) _bd=${0%/*} ;; *) _bd=. ;; esac
. "$_bd/common.sh"
detect_device
echo "Device : $DEV_NAME"
echo "SoC    : $DEV_SOC   RAM: ${DEV_RAM_MB}MB   CPU cores: $DEV_CORES"
echo "Display: max ${DEV_MAXHZ:-?}Hz"
echo "Tier   : $(tier_label "$DEV_TIER") (from $DEV_TIER_SRC)"
exit 0
