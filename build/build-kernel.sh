#!/bin/bash
set -ex

TMPDOWN=$1
INSTALL_MOD_PATH=$2
HERE=$(pwd)
source "${HERE}/deviceinfo"

KERNEL_DIR="${TMPDOWN}/$(basename "${deviceinfo_kernel_source}")"
KERNEL_DIR="${KERNEL_DIR%.*}"
OUT="${TMPDOWN}/KERNEL_OBJ"

mkdir -p "$OUT"

case "$deviceinfo_arch" in
    aarch64*) ARCH="arm64" ;;
    arm*) ARCH="arm" ;;
    x86_64) ARCH="x86_64" ;;
    x86) ARCH="x86" ;;
esac

export ARCH
export CROSS_COMPILE=$TMPDOWN/aarch64-linux-android-4.9/bin/aarch64-linux-android-
export CROSS_COMPILE_ARM32=$TMPDOWN/arm-linux-androideabi-4.9/bin/arm-linux-androideabi-
MAKEOPTS=""
if [ -n "$CC" ]; then
    MAKEOPTS="CC=$CC"
fi

cd "$KERNEL_DIR"
make O="$OUT" $deviceinfo_kernel_defconfig
make O="$OUT" $MAKEOPTS -j$(nproc --all)
make O="$OUT" $MAKEOPTS INSTALL_MOD_STRIP=1 INSTALL_MOD_PATH="$INSTALL_MOD_PATH" modules_install
ls "$OUT/arch/$ARCH/boot/"*Image*

if [ -n "$deviceinfo_kernel_apply_overlay" ] && $deviceinfo_kernel_apply_overlay; then
    ${TMPDOWN}/ufdt_apply_overlay "$OUT/arch/arm64/boot/dts/qcom/${deviceinfo_kernel_appended_dtb}.dtb" \
        "$OUT/arch/arm64/boot/dts/qcom/${deviceinfo_kernel_dtb_overlay}.dtbo" \
        "$OUT/arch/arm64/boot/dts/qcom/${deviceinfo_kernel_dtb_overlay}-merged.dtb"
    cat "$OUT/arch/$ARCH/boot/Image.gz" \
        "$OUT/arch/arm64/boot/dts/qcom/${deviceinfo_kernel_dtb_overlay}-merged.dtb" > "$OUT/arch/$ARCH/boot/Image.gz-dtb"
fi
