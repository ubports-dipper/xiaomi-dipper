# Port status: Ubuntu Touch 20.04 (Focal) on Xiaomi Mi 8 (dipper)

Last checked: 2026-10-16, branch `focal/port-bootstrap`, local build flashed to `system`.

## Hardware

| Area | State |
|---|---|
| Display / Lomiri | Works. Lomiri is the only Mir compositor, runs as phablet in a logind session. UI scale correct (GridUnit 21, Mir output scale 2.625). |
| Touch | Works (`MIR_SERVER_CONSOLE_PROVIDER=none`, evdev opened directly). |
| Power button | Works through `dipper-lsc-shim`, a USC D-Bus stand-in for repowerd. |
| Wi-Fi | Works (connects to WPA networks). |
| Time | NTP sync via systemd-timesyncd. |
| Modem | Both RIL modems online and powered in ofono. Calls and SMS not yet tested. |
| Audio | Playback works (PulseAudio, `sink.primary_output` on the droid card). Mic and call audio not yet tested. |
| Bluetooth | `hci0` up. Pairing not yet tested. |
| Sensors | Android sensors HAL runs; rotation events reach qtmir. |
| ADB on booted system | Works (usb-moded with `extcon_tracking=0`, plus a `/userdata/.force-adb` marker). |
| Charge limit | `dipper-charge-limit.service` suspends charger input (`battery/input_suspend`) at 80% and resumes at 75%. Not yet verified on the phone. Change limits with `systemctl edit` (`Environment=CHARGE_STOP=`/`CHARGE_START=`), disable with `systemctl mask`. |
| Suspend | Kernel autosleep works: unplugged with the screen off the SoC reaches deep sleep (aosd/cxsd). See known issue 7 for spurious logind suspends. |

## Known issues

1. Forced `systemd-suspend` fails with EBUSY (expected with autosleep and wakelocks; the real sleep path is autosleep).
2. repowerd floods the log with `NoSessionForPID` for the Lomiri processes.
3. upowerd: `energy_full_design` is 0.
4. Failed units: `systemd-backlight@backlight:panel0-backlight`; `usb-moded-ssh` gets killed during first-boot host-key generation.
5. usb-moded still runs with `-D` (debug).
6. **Off-mode charging boot hangs (work in progress).** Powering up with USB
   attached to a powered-off phone makes the bootloader pass
   `androidboot.mode=charger` (`fastboot oem off-mode-charge 0` is accepted but
   doesn't prevent it). Done so far: the initrd boots Ubuntu instead of
   Android's charger root (`ramdisk-overlay/scripts/halium`); the container
   gets a `/proc/cmdline` without the mode and `/dev/null` over
   `/proc/sysrq-trigger` (`overlay/system/var/lib/lxc/android/config`); the
   Android `on charger` blocks are disabled
   (`/usr/libexec/dipper-android-charger-guard`). Still failing at last test:
   at ~7 s a `sysrq: SysRq : Emergency Remount R/O` makes every filesystem
   read-only and the phone sits on the Mi logo; the sysrq mask is not yet
   tested in a charger boot. In charger mode the kernel charger driver
   (`smb-lib.c`, `off_charge_flag`) also leaves USB data off, so no ADB.
   Recover: Vol- + Power to fastboot, `fastboot boot` TWRP, `adb reboot`.
   Evidence: TWRP `/sys/fs/pstore/console-ramoops-0` and
   `/data/dipper-charger-guard.log` (debug output, to be removed).
7. Something calls logind `Suspend` every ~30 s for the first ~3 minutes
   after boot; each attempt fails with EBUSY and makes NetworkManager drop
   Wi-Fi and the modems. Not repowerd (HIDL backend, its `suspend()` is a no-op).

## Build and flash

```bash
./build-in-podman.sh --flashable            # out/boot.img, recovery.img, system.img
./build-mir-android2-in-podman.sh --install # patched Mir android platform into the overlay
fastboot flash system out/system.img        # usual iteration: system only
```

- The UI size comes from the Mir output scale (GridUnit / 8), which needs the
  patched `graphics-android2.so.15` (`patches/mir-android2-initial-display-policy.patch`).
  Check the `qtmir.screens: PlatformScreen ... scale:` line in the journal before
  changing GridUnit.
- Device systemd units go in `overlay/system/lib/systemd/system` (overlay-merged,
  read-only). Don't mark `etc/systemd/system` for merging: that hides the writable
  userdata copy, so `systemctl enable`, `timedatectl set-ntp`, and first-boot units
  fail with "Read-only file system" (clock stuck in 1970, TLS failures).
- The kernel needs `CONFIG_OVERLAY_FS` (`kernel.config`); without it the device
  overlay in `/opt/halium-overlay` fails to mount and the boot ends on a black screen.
- If the system won't boot to a shell, RAM-boot TWRP to pull logs.
