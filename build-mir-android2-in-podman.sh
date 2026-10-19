#!/bin/bash
# Build the patched mir-android2-platform (graphics-android2.so.15) locally,
# same steps as .github/workflows/mir-android-patch.yml: an arm64 Focal
# container (qemu-user binfmt) with the UBports repo, patches/mir-android2-*.
#
# Output: out/mir-android2/graphics-android2.so.15 (+ the .debs). Install it
# with --install, which copies it into the overlay.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

INSTALL=0
case "${1:-}" in
--install) INSTALL=1 ;;
"") ;;
*) echo "Usage: $0 [--install]" >&2; exit 1 ;;
esac

OUT="$HERE/out/mir-android2"
SO_DEST="$HERE/overlay/system/lib/aarch64-linux-gnu/mir/server-platform/graphics-android2.so.15"
mkdir -p "$OUT"

podman run --rm --platform linux/arm64 \
    -v "$HERE/patches:/patches:ro,Z" \
    -v "$OUT:/out:Z" \
    docker.io/arm64v8/ubuntu:focal \
    bash -euxc '
        export DEBIAN_FRONTEND=noninteractive
        apt-get update
        apt-get install -y ca-certificates gnupg wget git devscripts equivs patch

        echo "deb http://repo.ubports.com/ focal main" > /etc/apt/sources.list.d/ubports.list
        wget -qO- https://repo.ubports.com/keyring.gpg | gpg --dearmor > /etc/apt/trusted.gpg.d/ubports.gpg
        apt-get update

        git clone --depth 1 -b ubports/focal \
            https://gitlab.com/ubports/development/core/hybris-support/mir-android2-platform.git /src
        cd /src
        for p in /patches/mir-android2-egl-probe.patch /patches/mir-android2-initial-display-policy.patch; do
            patch -p1 < "$p"
        done
        grep -n "initial_conf_policy->apply_to" src/platforms/android/server/platform.cpp

        mk-build-deps -i -r -t "apt-get -y --no-install-recommends" debian/control
        DEB_BUILD_OPTIONS="nocheck parallel=$(nproc)" dpkg-buildpackage -b -uc -us
        rm -f /out/*.deb
        cp ../*.deb /out/
        mkdir -p /tmp/x
        for d in /out/mir-platform-graphics-android2*.deb; do dpkg-deb -x "$d" /tmp/x; done
        find /tmp/x -name "graphics-android2.so*" -type f -exec cp {} /out/graphics-android2.so.15 \;
    '

test -f "$OUT/graphics-android2.so.15"
ls -l "$OUT"

if [ "$INSTALL" = "1" ]; then
    cp "$OUT/graphics-android2.so.15" "$SO_DEST"
    echo "Installed into $SO_DEST"
fi
