#!/bin/bash
# Build the patched mir-android2-platform (graphics-android2.so.16) locally,
# same steps as .github/workflows/mir-android-patch.yml: an arm64 Noble
# container (qemu-user binfmt) with the UBports 24.04-2.x repo,
# patches/mir-android2-*.
#
# Output: out/mir-android2/graphics-android2.so.16 (+ the .debs). Install it
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
SO_NAME=graphics-android2.so.16
SO_DEST="$HERE/overlay/system/lib/aarch64-linux-gnu/mir1/server-platform/$SO_NAME"
mkdir -p "$OUT"

podman run --rm --platform linux/arm64 \
    -v "$HERE/patches:/patches:ro,Z" \
    -v "$OUT:/out:Z" \
    docker.io/arm64v8/ubuntu:noble \
    bash -euxc '
        export DEBIAN_FRONTEND=noninteractive
        apt-get update
        apt-get install -y ca-certificates gnupg wget git devscripts equivs patch

        echo "deb http://repo.ubports.com/ 24.04-2.x main" > /etc/apt/sources.list.d/ubports.list
        wget -qO- https://repo.ubports.com/keyring.gpg | gpg --dearmor > /etc/apt/trusted.gpg.d/ubports.gpg
        apt-get update

        git clone --depth 1 -b ubports/24.04-2.x \
            https://gitlab.com/ubports/development/core/hybris-support/mir-android2-platform.git /src
        cd /src
        for p in /patches/mir-android2-egl-probe.patch /patches/mir-android2-initial-display-policy.patch; do
            patch -p1 < "$p"
        done
        grep -n "initial_conf_policy->apply_to" src/platforms/android/server/platform.cpp

        mk-build-deps -i -r -t "apt-get -y --no-install-recommends" debian/control
        DEB_BUILD_OPTIONS="nocheck parallel=$(nproc)" dpkg-buildpackage -b -uc -us
        rm -f /out/*.deb /out/graphics-android2.so*
        cp ../*.deb /out/
        mkdir -p /tmp/x
        for d in /out/mir1-platform-graphics-android2*.deb; do dpkg-deb -x "$d" /tmp/x; done
        find /tmp/x -name "graphics-android2.so*" -type f -exec cp {} /out/ \;
    '

test -f "$OUT/$SO_NAME"
ls -l "$OUT"

if [ "$INSTALL" = "1" ]; then
    mkdir -p "$(dirname "$SO_DEST")"
    cp "$OUT/$SO_NAME" "$SO_DEST"
    echo "Installed into $SO_DEST"
fi
