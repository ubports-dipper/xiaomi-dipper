#!/bin/bash
set -xe

BUILD_DIR=
OUT=

while [ $# -gt 0 ]
do
    case "$1" in
    (-b) BUILD_DIR="$(realpath "$2")"; shift;;
    (-o) OUT="$2"; shift;;
    (-*) echo "$0: Error: unknown option $1" 1>&2; exit 1;;
    (*) OUT="$2"; break;;
    esac
    shift
done

OUT="$(realpath "$OUT" 2>/dev/null || echo 'out')"
mkdir -p "$OUT"

if [ -z "$BUILD_DIR" ]; then
    TMP=$(mktemp -d)
    TMPDOWN=$(mktemp -d)
else
    TMP="$BUILD_DIR/tmp"
    mkdir -p "$TMP"
    TMPDOWN="$BUILD_DIR/downloads"
    mkdir -p "$TMPDOWN"
fi

HERE=$(pwd)
SCRIPT="$(dirname "$(realpath "$0")")"/build

mkdir -p "${TMP}/system"
mkdir -p "${TMP}/partitions"

source "${HERE}/deviceinfo"

case $deviceinfo_arch in
    "armhf") RAMDISK_ARCH="armhf";;
    "aarch64") RAMDISK_ARCH="arm64";;
    "x86") RAMDISK_ARCH="i386";;
esac

cd "$TMPDOWN"
    [ -d aarch64-linux-android-4.9 ] || git clone https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9 -b pie-gsi --depth 1
    GCC_PATH="$TMPDOWN/aarch64-linux-android-4.9"
    if [ -n "$deviceinfo_kernel_clang_compile" ] && $deviceinfo_kernel_clang_compile; then
        [ -d linux-x86 ] || git clone https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86 -b pie-gsi --depth 1
        CLANG_PATH="$TMPDOWN/linux-x86/clang-4691093"
    fi
    [ -d arm-linux-androideabi-4.9 ] || git clone https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9 -b pie-gsi --depth 1
    GCC_ARM32_PATH="$TMPDOWN/arm-linux-androideabi-4.9"

    KERNEL_DIR="$(basename "${deviceinfo_kernel_source}")"
    KERNEL_DIR="${KERNEL_DIR%.*}"
    [ -d "$KERNEL_DIR" ] || git clone "$deviceinfo_kernel_source" -b $deviceinfo_kernel_source_branch --depth 1

    [ -f halium-boot-ramdisk.img ] || curl --location --output halium-boot-ramdisk.img \
        "https://github.com/halium/initramfs-tools-halium/releases/download/continuous/initrd.img-touch-${RAMDISK_ARCH}"

    if [ -n "$deviceinfo_kernel_apply_overlay" ] && $deviceinfo_kernel_apply_overlay; then
        [ -d libufdt ] || git clone https://android.googlesource.com/platform/system/libufdt -b pie-gsi --depth 1
        [ -d dtc ] || git clone https://android.googlesource.com/platform/external/dtc -b pie-gsi --depth 1
    fi
    ls .
cd "$HERE"

if [ -n "$deviceinfo_kernel_apply_overlay" ] && $deviceinfo_kernel_apply_overlay; then
    "$SCRIPT/build-ufdt-apply-overlay.sh" "${TMPDOWN}"
fi

if [ -n "$deviceinfo_kernel_clang_compile" ] && $deviceinfo_kernel_clang_compile; then
    CC=clang \
    CLANG_TRIPLE=${deviceinfo_arch}-linux-gnu- \
    PATH="$CLANG_PATH/bin:$GCC_PATH/bin:$GCC_ARM32_PATH/bin:${PATH}" \
    "$SCRIPT/build-kernel.sh" "${TMPDOWN}" "${TMP}/system"
else
    PATH="$GCC_PATH/bin:$GCC_ARM32_PATH/bin:${PATH}" \
    "$SCRIPT/build-kernel.sh" "${TMPDOWN}" "${TMP}/system"
fi

"$SCRIPT/make-bootimage.sh" "${TMPDOWN}/KERNEL_OBJ" "${TMPDOWN}/halium-boot-ramdisk.img" "${TMP}/partitions/boot.img"

cp -av overlay/* "${TMP}/"
"$SCRIPT/build-tarball-mainline.sh" "${deviceinfo_codename}" "${OUT}" "${TMP}"

if [ -z "$BUILD_DIR" ]; then
    rm -r "${TMP}"
    rm -r "${TMPDOWN}"
fi

echo "done"
