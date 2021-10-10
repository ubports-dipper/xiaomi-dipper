#!/bin/bash
set -ex

KERNEL_OBJ=$(realpath $1)
RAMDISK=$(realpath $2)
OUT=$(realpath $3)

HERE=$(pwd)
source "${HERE}/deviceinfo"

case "$deviceinfo_arch" in
    aarch64*) ARCH="arm64" ;;
    arm*) ARCH="arm" ;;
    x86_64) ARCH="x86_64" ;;
    x86) ARCH="x86" ;;
esac

if [ -d "$HERE/ramdisk-overlay" ]; then
    cp "$RAMDISK" "${RAMDISK}-merged"
    RAMDISK="${RAMDISK}-merged"
    cd "$HERE/ramdisk-overlay"
    find . | cpio -o -H newc | gzip >> "$RAMDISK"
fi

if [ -d "$HERE/recovery/overlay" ] && [ -e "$HERE/recovery/ramdisk-recovery.img" ]; then
    mkdir -p "$HERE/ramdisk-recovery"
    cd "$HERE/ramdisk-recovery"

    gzip -dc "$HERE/recovery/ramdisk-recovery.img" | cpio -i
    cp -r "$HERE/recovery/overlay"/* "$HERE/ramdisk-recovery"

    # Set values in prop.default based on deviceinfo
    sed -i 's/^\(ro\.product\.\(vendor\.\)\?brand=\).*$/\1'"$deviceinfo_manufacturer"'/' prop.default
    sed -i 's/^\(ro\.product\.\(vendor\.\)\?manufacturer=\).*$/\1'"$deviceinfo_manufacturer"'/' prop.default
    sed -i 's/^\(ro\.product\.vendor\.name=\).*$/\1'"$deviceinfo_manufacturer"'/' prop.default

    sed -i 's/^\(ro\.product\.\(vendor\.\)\?device=\).*$/\1'"$deviceinfo_codename"'/' prop.default
    sed -i 's/^\(ro\.product\.name=\).*$/\1'"$deviceinfo_codename"'/' prop.default
    sed -i 's/^\(ro\.build\.product=\).*$/\1'"$deviceinfo_codename"'/' prop.default

    sed -i 's/^\(ro\.product\.\(vendor\.\)\?model=\).*$/\1'"$deviceinfo_name"'/' prop.default

    find . | cpio -o -H newc | gzip > "$HERE/recovery/ramdisk-recovery-overlayed.img"
fi

mkbootimg --kernel "$KERNEL_OBJ/arch/$ARCH/boot/Image.gz-dtb" --ramdisk "$RAMDISK" --base $deviceinfo_flash_offset_base --kernel_offset $deviceinfo_flash_offset_kernel --ramdisk_offset $deviceinfo_flash_offset_ramdisk --second_offset $deviceinfo_flash_offset_second --tags_offset $deviceinfo_flash_offset_tags --pagesize $deviceinfo_flash_pagesize --os_version $deviceinfo_os_version --os_patch_level $deviceinfo_os_patch_level --cmdline "$deviceinfo_kernel_cmdline" -o "$OUT"

mkbootimg --kernel "$KERNEL_OBJ/arch/$ARCH/boot/Image.gz-dtb" --ramdisk "$HERE/recovery/ramdisk-recovery-overlayed.img" --base $deviceinfo_flash_offset_base --kernel_offset $deviceinfo_flash_offset_kernel --ramdisk_offset $deviceinfo_flash_offset_ramdisk --second_offset $deviceinfo_flash_offset_second --tags_offset $deviceinfo_flash_offset_tags --pagesize $deviceinfo_flash_pagesize --os_version $deviceinfo_os_version --os_patch_level $deviceinfo_os_patch_level --cmdline "$deviceinfo_kernel_cmdline" -o "$(dirname $OUT)/recovery.img"
