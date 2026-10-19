#!/bin/bash
set -xe

ADAPTATION_TOOLS_REPO="https://gitlab.com/ubports/porting/community-ports/halium-generic-adaptation-build-tools.git"
ADAPTATION_TOOLS_BRANCH="${ADAPTATION_TOOLS_BRANCH:-main}"

apply_build_toolchain_fixes() {
    local repo="$1"
    local setup="$repo/setup_repositories.sh"
    local kernel="$repo/build-kernel.sh"

    if [ -f "$setup" ] && ! grep -q 'chmod +x "$GCC_ARM32_PATH/arm-linux-androideabi/bin/as"' "$setup"; then
        sed -i.bak '/sed -i.bak "1 s:\.\*:#!\/usr\/bin\/env python3:" "$GCC_ARM32_PATH\/arm-linux-androideabi\/bin\/as"/a\            chmod +x "$GCC_ARM32_PATH/arm-linux-androideabi/bin/as"' "$setup"
    fi

    if [ -f "$kernel" ] && ! grep -q 'ARM32_MAKE_ARGS' "$kernel"; then
        sed -i.bak '/export CROSS_COMPILE_ARM32/a\
    ARM32_GCC_BIN="${TMPDOWN}/arm-linux-androideabi-4.9/arm-linux-androideabi/bin"\
    if [ -d "$ARM32_GCC_BIN" ]; then\
        ARM32_MAKE_ARGS=(CC_ARM32="${CROSS_COMPILE_ARM32}gcc -B ${ARM32_GCC_BIN}/")\
    fi' "$kernel"
        sed -i.bak 's/make O="$OUT" $MAKEOPTS /make O="$OUT" $MAKEOPTS "${ARM32_MAKE_ARGS[@]}" /g' "$kernel"
    fi

    # Merge ./kernel.config over the defconfig and fail if any option is lost.
    if [ -f "$kernel" ] && ! grep -q 'kernel.config fragment' "$kernel"; then
        sed -i.bak '/^make O=.*\$deviceinfo_kernel_defconfig$/a\
# kernel.config fragment (added by xiaomi-dipper build.sh)\
if [ -f "$HERE/kernel.config" ]; then\
    sed -n "s/^CONFIG_\\([A-Za-z0-9_]*\\)=\\(.*\\)$/\\1 \\2/p" "$HERE/kernel.config" | while read -r name val; do\
        scripts/config --file "$OUT/.config" --set-val "$name" "$val"\
    done\
    make O="$OUT" $MAKEOPTS "${ARM32_MAKE_ARGS[@]}" olddefconfig\
    grep "^CONFIG_" "$HERE/kernel.config" | while read -r opt; do\
        grep -qx "$opt" "$OUT/.config" || { echo "kernel.config: $opt not applied" >&2; exit 1; }\
    done\
fi' "$kernel"
        grep -q 'kernel.config fragment' "$kernel"
    fi
}

if [ ! -f build/build.sh ]; then
    git clone -b "$ADAPTATION_TOOLS_BRANCH" --depth 1 "$ADAPTATION_TOOLS_REPO" build
fi

apply_build_toolchain_fixes build

exec ./build/build.sh "$@"
