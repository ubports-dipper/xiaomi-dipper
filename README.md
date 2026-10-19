# Ubuntu Touch device tree for Xiaomi Mi 8 (dipper)

Ubuntu Touch 24.04 (Noble, `24.04-2.x`) port for the Xiaomi Mi 8, based on
Halium 9.0 and the [halium_arm64 GSI build mechanism](https://github.com/ubports/porting-notes/wiki/GitLab-CI-builds-for-devices-based-on-halium_arm64-(Halium-9)),
adapted to GitHub Actions. The 20.04 (Focal) port lives on the
`focal/port-bootstrap` branch.

What works, known issues and debugging notes are in [STATUS.md](STATUS.md).

The ZIPs under [Releases](https://github.com/ubports-dipper/xiaomi-dipper/releases)
(OTA-20 to OTA-24, 2021-2022) are the older 16.04 (Xenial) builds. Install them
like any custom ROM: full wipe, format data, flash the ZIP. Don't install
Magisk.

## Pre-requisites

- Unlocked bootloader.
- Stock Android 9 vendor and firmware. Get them from
  [Xiaomi Firmware Updater](https://xiaomifirmwareupdater.com)
  ([GLOBAL](https://github.com/TryHardDood/mi-vendor-updater/releases/download/dipper_global-stable/fw-vendor_dipper_miui_MI8Global_V11.0.6.0.PEAMIXM_45261e66d2_9.0.zip),
  [RUSSIA](https://github.com/TryHardDood/mi-vendor-updater/releases/download/dipper_ru_global-stable/fw-vendor_dipper_miui_MI8RUGlobal_V11.0.6.0.PEARUXM_99fd810f76_9.0.zip),
  [CHINA](https://github.com/TryHardDood/mi-vendor-updater/releases/download/dipper-stable/fw-vendor_dipper_miui_MI8_V11.0.4.0.PEACNXM_93fe86f258_9.0.zip))
  and flash them before installing.

## Getting images

**Prebuilt:** every push runs the CI workflow; download the `OTA images`
artifact of a successful run from the
[Actions](https://github.com/ubports-dipper/xiaomi-dipper/actions) page and
unpack it into `out/`.

**Local build** (Linux, rootless Podman):

```bash
./build-in-podman.sh --flashable              # out/boot.img, recovery.img, rootfs.img
./build-mir-android2-in-podman.sh --install   # optional: rebuild the patched Mir
                                              # android platform into the overlay
                                              # (needs qemu-user-static binfmt)
```

The kernel config additions (`CONFIG_OVERLAY_FS`, required) live in
`kernel.config`; device files that go into the system image live in
`overlay/system`, and the initramfs changes in `ramdisk-overlay`.

## Install

The Noble rootfs (about 3.3 GiB with the Halium image) doesn't fit the 3 GiB
system partition, so it lives on userdata as `/data/ubuntu.img`, the
initramfs's "legacy" layout. The system partition is unused.

From fastboot (Vol- + Power):

```bash
fastboot flash boot out/boot.img
fastboot flash recovery out/recovery.img
fastboot boot twrp-3.7.0-dipper.img   # RAM-boot TWRP, nothing is flashed
adb shell twrp format data            # first install only: wipes all data
adb push out/rootfs.img /data/ubuntu.img
adb shell touch /data/.force-adb      # ADB on the booted system
adb reboot
```

Format userdata from TWRP, not with `fastboot format:ext4 userdata`: a recent
host e2fsprogs (1.47+) adds the `orphan_file` feature, which the 4.9 kernel
and the initramfs's e2fsck 1.43 don't support, and the filesystem gets
corrupted. After `twrp format data` the phone may drop out of TWRP; get back
to it the same way (Vol- + Power, `fastboot boot`) before pushing.

When iterating on a running install, pushing only `ubuntu.img` from TWRP (and
flashing `boot` for kernel/initramfs changes) keeps the rest of userdata.
Formatting userdata removes the OS as well.

## Notes

- Use the buttons (Vol- + Power) to get to fastboot. `adb reboot` and
  `adb reboot bootloader` are currently handled by Android inside the
  container and leave the phone hung with USB off.
- If the phone doesn't come up, RAM-boot TWRP from fastboot
  (`fastboot boot twrp-3.7.0-dipper.img`, nothing is flashed) and read the
  previous boot's kernel log from `/sys/fs/pstore/console-ramoops-0`; the
  system journal is persistent under `/data/system-data/var/log/journal`.
- Off-mode charging (USB plugged into a powered-off phone) doesn't boot yet,
  see STATUS.md.
