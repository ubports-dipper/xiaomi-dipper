# Port status: Ubuntu Touch 24.04 (Noble) on Xiaomi Mi 8 (dipper)

Branch `noble/port-bootstrap`, release `24.04-2.x`. First boot 2026-10-19:
Lomiri comes up and the setup wizard completes, the patched Mir platform
loads (output scale 2.625) and the panel clears the notch. The hardware table
and known issues further down are the Focal results (2026-10-16,
`focal/port-bootstrap`); what has been re-checked on Noble is listed here.

## Noble checks (2026-10-19, service state only)

| Area | State |
|---|---|
| Display / Lomiri | Works, setup wizard completed. Notch handled by deviceinfo cutouts (narrow corner rects so the clock fits right of the notch); in landscape `PanelBar.qml` insets the panel row 40 px from the rounded corners. 24-hour clock: `gsettings set org.ayatana.indicator.datetime time-format '24-hour'`. |
| Wi-Fi | Connected (`wlan0`); NTP synchronised. |
| Modem | Both RIL modems online and powered in ofono. Calls/SMS not tested yet: no SIM inserted (both slots `Present: false`). |
| Audio | Works: loudspeaker playback (`output-speaker`), earpiece (`output-earpiece`) and the built-in mic (`source.droid`, recorded speech played back clearly; peak about -20 dBFS). The card has `voicecall` profiles; in-call routing untested without a SIM. |
| Bluetooth | `hci0` up, powered. Pairing not tested. |
| Sensors | `sensorfwd` active. |
| Power / volume keys | Power-button long press opens the power dialog and held volume keys repeat, now that the Lomiri wrapper no longer copies lsc-wrapper's `MIR_SERVER_ENABLE_KEY_REPEAT=false` (Lomiri detects both from key repeats). |
| Charge limit | Noble has no built-in limit (no settings option; upower 1.90.3 predates charge thresholds; the 4.9 charger has no `charge_control_end_threshold`). `dipper-charge-limit` now stops charging with `battery/charge_control_limit` at its max (driver votes charging off, USB input stays up): tested stop/resume with ADB connected throughout. The old `input_suspend` method dropped USB (ADB/MTP) on every toggle until a replug. |
| ADB | Works with Developer Mode on. Earlier drop-outs came from the charge limiter toggling `input_suspend`. Host side: usb-moded uses pid.codes IDs (`1209:0002/0003/0004`), which the stock `51-android.rules` doesn't know, so without a local udev rule (`GROUP="adbusers"`) the node only gets the active seat's ACL. |
| Failed units | `fpc-key-disable` (this phone has the Goodix sensor, so the FPC helper exits and restart-loops), `logrotate`, `dpkg-db-backup` (stock image: no `/var/log/syslog`, read-only rootfs). |

## Noble first-boot notes

- Format userdata from TWRP (`twrp format data`), not `fastboot format:ext4
  userdata`: the host's e2fsprogs 1.47 adds `orphan_file`, which the
  initramfs's e2fsck 1.43.4 (run on every boot) and the 4.9 kernel don't
  know. That filesystem was destroyed after the first shutdown.
- `adb shell` runs as phablet; `sudo` takes the password `phablet`. ADB needs
  the `/userdata/.force-adb` marker after a fresh format.
- On a fresh install the RTC reads 1970 until timekeeper has a saved offset,
  so snapd's first seeding fails and `snapd.seeded` hangs, keeping
  `multi-user.target` from finishing. `systemctl restart snapd` once the
  clock is sane fixes it. `dipper-shell` no longer waits for
  `multi-user.target`, so the UI starts regardless.

## Noble port changes

- Rootfs on userdata as `/data/ubuntu.img` (5120M image): the Noble rootfs
  plus the Halium image is about 3.3 GiB and doesn't fit the 3072M system
  partition. `systempart=` is gone from the cmdline. `ramdisk-overlay/scripts/halium`
  is the current dynparts initramfs script (it has the `ubuntu.img` "legacy"
  layout) plus the charger-mode change.
- `systemd.unified_cgroup_hierarchy=0` on the cmdline: Noble's systemd
  defaults to cgroup v2; the other Halium 9 ports on 4.x kernels do the same.
- Mir is 1.8.3 under the `mir1` name; the patched Android platform is now
  `lib/aarch64-linux-gnu/mir1/server-platform/graphics-android2.so.16`, built
  from the `ubports/24.04-2.x` branch with the same two patches.
- Notch: Noble Lomiri supports display cutouts, configured in
  `devices/dipper.yaml` (`DisplayCutoutsCollapsed`, `CollapsedPanelHeight`).
  This replaces the Focal `ShellScreen.qml` override.
- `lomiri-systemd-wrapper` picks up Noble's software-rendering guard. The
  session setup (`dipper-shell`, `dipper-lsc-shim`, masked lightdm) is
  unchanged: everything it uses still exists on Noble.

## Hardware (Focal results)

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

## Known issues (Focal)

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
./build-in-podman.sh --flashable            # out/boot.img, recovery.img, rootfs.img
./build-mir-android2-in-podman.sh --install # patched Mir android platform into the overlay
fastboot boot twrp-3.7.0-dipper.img          # then, from TWRP:
adb push out/rootfs.img /data/ubuntu.img     # usual iteration: rootfs only
```

- The UI size comes from the Mir output scale (GridUnit / 8), which needs the
  patched `graphics-android2.so.16` (`patches/mir-android2-initial-display-policy.patch`).
  Check the `qtmir.screens: PlatformScreen ... scale:` line in the journal before
  changing GridUnit.
- Device systemd units go in `overlay/system/lib/systemd/system` (overlay-merged,
  read-only). Don't mark `etc/systemd/system` for merging: that hides the writable
  userdata copy, so `systemctl enable`, `timedatectl set-ntp`, and first-boot units
  fail with "Read-only file system" (clock stuck in 1970, TLS failures).
- The kernel needs `CONFIG_OVERLAY_FS` (`kernel.config`); without it the device
  overlay in `/opt/halium-overlay` fails to mount and the boot ends on a black screen.
- If the system won't boot to a shell, RAM-boot TWRP to pull logs.
