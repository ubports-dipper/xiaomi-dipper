#!/bin/bash
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

IMAGE="${PODMAN_IMAGE:-xiaomi-dipper-build}"
TARBALL=1
FLASHABLE=0

usage() {
    cat <<'EOF_USAGE'
Usage: build-in-podman.sh [--flashable] [--flashable-only]

Build dipper device images inside Podman (Ubuntu 22.04).

  --flashable       Also build boot.img, recovery.img, and rootfs.img via prepare-fake-ota
  --flashable-only  Skip the device tarball build, reuse out/device_<codename>.tar.xz

Everything runs rootless. Without loop devices, system-image-from-ota.sh falls
back to unpacking into a directory and building rootfs.img with `mke2fs -d`;
the user namespace keeps the rootfs file ownership intact.

Environment:
  PODMAN_IMAGE  Container image name (default: xiaomi-dipper-build)
EOF_USAGE
}

while [ $# -gt 0 ]; do
    case "$1" in
    --flashable) FLASHABLE=1 ;;
    --flashable-only) FLASHABLE=1; TARBALL=0 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
    esac
    shift
done

if ! command -v podman >/dev/null 2>&1; then
    echo "podman is required but not installed." >&2
    exit 1
fi

IS_MAC=0
[ "$(uname -s)" = "Darwin" ] && IS_MAC=1

ensure_podman() {
    podman ps >/dev/null 2>&1 && return 0
    if [ "$IS_MAC" = "1" ]; then
        podman machine start podman-machine-default 2>&1 || podman machine start 2>&1 || true
        for _ in 1 2 3 4 5 6 7 8 9 10; do
            podman ps >/dev/null 2>&1 && return 0
            sleep 2
        done
        echo "Podman is not reachable. Try: podman machine stop && podman machine start" >&2
    else
        podman ps >&2 || true
        echo "Podman is not usable for this user." >&2
    fi
    exit 1
}

ensure_podman

# Android NDK toolchains are x86_64 Linux binaries; run amd64 containers on arm64 hosts.
PODMAN_PLATFORM=()
case "$(uname -m)" in
arm64|aarch64) PODMAN_PLATFORM=(--platform linux/amd64) ;;
esac

if [ "$IS_MAC" = "1" ]; then
    # Linux kernel builds require a case-sensitive tree; macOS bind mounts are usually not.
    WORKDIR_VOLUME="${PODMAN_WORKDIR_VOLUME:-xiaomi-dipper-workdir}"
    podman volume exists "$WORKDIR_VOLUME" >/dev/null 2>&1 || podman volume create "$WORKDIR_VOLUME" >/dev/null
    WORKDIR_MOUNT="${WORKDIR_VOLUME}:/src/workdir:Z"
else
    mkdir -p "$HERE/workdir"
    WORKDIR_MOUNT="$HERE/workdir:/src/workdir:Z"
fi

seed_workdir_volume() {
    [ "$IS_MAC" = "1" ] || return 0
    local marker="downloads/.seeded-from-host"
    if podman run --rm "${PODMAN_PLATFORM[@]}" -v "${WORKDIR_VOLUME}:/workdir:Z" "$IMAGE" \
        test -f "/workdir/${marker}"; then
        return 0
    fi
    if [ -d "$HERE/workdir/downloads" ]; then
        echo "Seeding Podman workdir volume from host (one-time)..."
        podman run --rm "${PODMAN_PLATFORM[@]}" \
            -v "$HERE/workdir:/host:Z" \
            -v "${WORKDIR_VOLUME}:/workdir:Z" \
            "$IMAGE" \
            bash -lc '
                cp -a /host/. /workdir/
                rm -rf /workdir/downloads/kernel-xiaomi-sdm845 /workdir/downloads/KERNEL_OBJ
                chmod +x /workdir/downloads/arm-linux-androideabi-4.9/arm-linux-androideabi/bin/as 2>/dev/null || true
                touch /workdir/downloads/.seeded-from-host
            '
    fi
}

PODMAN_MOUNTS=(
    -v "$HERE:/src:Z"
    -v "$WORKDIR_MOUNT"
)

mkdir -p out

if [ "$TARBALL" = "1" ]; then
    echo "Building container image ${IMAGE}..."
    podman build "${PODMAN_PLATFORM[@]}" -t "$IMAGE" -f "$HERE/Containerfile" "$HERE"

    seed_workdir_volume

    echo "Building device tarball..."
    podman run --rm "${PODMAN_PLATFORM[@]}" \
        "${PODMAN_MOUNTS[@]}" \
        -w /src \
        "$IMAGE" \
        ./build.sh -b workdir -o out
fi

if [ "$FLASHABLE" = "1" ]; then
    echo "Building flashable images..."
    podman run --rm "${PODMAN_PLATFORM[@]}" \
        "${PODMAN_MOUNTS[@]}" \
        -w /src \
        "$IMAGE" \
        bash -lc '
            set -xe
            [ -f build/build.sh ] || ./build.sh -c
            DEVICE="$(source deviceinfo && echo "$deviceinfo_codename")"
            test -f "out/device_${DEVICE}.tar.xz" || { echo "device tarball missing"; exit 1; }
            ./build/prepare-fake-ota.sh "out/device_${DEVICE}.tar.xz" ota
            test -f "ota/device_${DEVICE}.tar.xz" || { echo "device tarball not staged into OTA"; exit 1; }
            ./build/system-image-from-ota.sh ota/ubuntu_command out
        '
fi

echo
echo "Build artifacts:"
ls -lh "$HERE/out/" 2>/dev/null || true
