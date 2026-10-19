# Ubuntu Touch device tree for Xiaomi Mi 8 (dipper)

Ubuntu Touch 20.04 (Focal) port for the Xiaomi Mi 8, based on Halium 9.0 and
the [halium_arm64 GSI build mechanism](https://github.com/ubports/porting-notes/wiki/GitLab-CI-builds-for-devices-based-on-halium_arm64-(Halium-9)),
adapted to GitHub Actions.

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
./build-in-podman.sh --flashable              # out/boot.img, recovery.img, system.img
./build-mir-android2-in-podman.sh --install   # optional: rebuild the patched Mir
                                              # android platform into the overlay
                                              # (needs qemu-user-static binfmt)
```

The kernel config additions (`CONFIG_OVERLAY_FS`, required) live in
`kernel.config`; device files that go into the system image live in
`overlay/system`, and the initramfs changes in `ramdisk-overlay`.

## Install

From fastboot (Vol- + Power):

```bash
fastboot flash boot out/boot.img
fastboot flash recovery out/recovery.img
fastboot flash system out/system.img
fastboot format:ext4 userdata   # first install only: wipes all data
fastboot reboot
```

When iterating on a running install, flashing only `system` (and `boot` for
kernel/initramfs changes) keeps userdata.

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
