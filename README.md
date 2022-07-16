# Ubuntu Touch device tree for Xiaomi Mi 8 (dipper)

This is based on Halium 9.0, and uses the mechanism described in [this page](https://github.com/ubports/porting-notes/wiki/GitLab-CI-builds-for-devices-based-on-halium_arm64-(Halium-9)). (actually a little modified to work in GitHub Actions, but in general it is the same)

You can download the ready-made artifacts from github: take the [latest archive](https://github.com/ubports-dipper/xiaomi-dipper/suites/4028909010/artifacts/101927864e), unpack the `OTA images.zip` file (make sure that all files are created inside a directory called `out/`, then follow the instructions in the [Install](#install) section. You can apply patches yourself, just use my [script](https://github.com/istadem2077/simg2zip).

Or you can use installable ZIP archives from Releases. Just install it as any other Custom ROM. Do a full wipe and format data (WARNING!! ALL DATA WILL BE LOST, FORMATTING DATA IS NECESSARY IF YOU ARE DOWNGRADING FROM ANDROID 10 OR HIGHER), and install zip. Don't install Magisk, it wont work here, and may even destroy your system. Firmware and Vendor are already packed in zip so no need to additionally install vendor+fw.

## Pre-requisites

As this is based on Android 9, it is required to install stock vendor.img from Android 9. You can Android 9 stock firmware from [Xiaomi Firmware Updater](https://xiaomifirmwareupdater.com)([GLOBAL](https://github.com/TryHardDood/mi-vendor-updater/releases/download/dipper_global-stable/fw-vendor_dipper_miui_MI8Global_V11.0.6.0.PEAMIXM_45261e66d2_9.0.zip), [RUSSIA](https://github.com/TryHardDood/mi-vendor-updater/releases/download/dipper_ru_global-stable/fw-vendor_dipper_miui_MI8RUGlobal_V11.0.6.0.PEARUXM_99fd810f76_9.0.zip), [CHINA](https://github.com/TryHardDood/mi-vendor-updater/releases/download/dipper-stable/fw-vendor_dipper_miui_MI8_V11.0.4.0.PEACNXM_93fe86f258_9.0.zip))

Copy these images to directory `out/` above together with the artifacts.

## Install

```bash
fastboot flash boot out/boot.img
fastboot flash recovery out/recovery.img
fastboot flash system out/system.img
```

