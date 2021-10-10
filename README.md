# Ubuntu Touch device tree for Xiaomi Mi 8 (dipper)

This is based on Halium 9.0, and uses the mechanism described in [this page](https://github.com/ubports/porting-notes/wiki/GitLab-CI-builds-for-devices-based-on-halium_arm64-(Halium-9)).

You can download the ready-made artifacts from gitlab: take the [latest archive](https://gitlab.com/ubports/community-ports/android9/xiaomi-mi-mix-3/xiaomi-perseus/-/jobs/artifacts/master/download?job=flashable), unpack the `artifacts.zip` file (make sure that all files are created inside a directory called `out/`, then follow the instructions in the [Install](#install) section.

## Pre-requisites

As this is based on Android 9, it is required to install stock vendor.img from Android 9. You can Android 9 stock firmware from [Xiaomi Firmware Updater](https://xiaomifirmwareupdater.com/).
DTBO based on LineageOS 16.0 is required to boot the Ubuntu Touch.

Copy these images to directory `out/` above together with the artifacts.

## Install

```bash
fastboot flash boot out/boot.img
fastboot flash dtbo out/dtbo.img
fastboot flash recovery out/recovery.img
fastboot flash system out/system.img
```

