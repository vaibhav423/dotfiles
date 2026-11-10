# Persistent chroot namespace — direct / adb login

New files only. Nothing here replaces or edits `chroot_sshd.sh`, `arch-shell`,
`archl`, `chroot_min.sh`, or `chroot_unmount.sh`.

Background, rationale and the full troubleshooting matrix live in
`../termux/CHROOT-NS.md`.

## Files

| File | Purpose |
|---|---|
| `scripts/chroot_ns_boot.sh` | Boot entry. Deploy as `/data/adb/service.d/chroot_ns.sh` |
| `scripts/chroot_ns_holder.sh` | Runs inside the slave namespace: mounts, optional sshd, pid file, keeps namespace alive |
| `scripts/chroot_ns_enter.sh` | Attach a terminal from adb/Termux via `nsenter` |
| `scripts/chroot_ns_stop.sh` | Kill every process in the namespace; kernel removes all mounts |
| `scripts/chroot_ns_ephemeral.sh` | Fallback: one-shot private namespace, auto-cleanup |
| `../termux/scripts/archl-ns` | New Termux direct launcher (does not replace `archl`) |

## Why

The old boot script mounts in the namespace it is started in, so
`/data/local/tmp/archl/{dev,sys,proc,...}` ends up in init's mount table and is
visible to every app and to Duck Detector. `su -mm` for `/sdcard` and
`Water/Fire` creates global mounts even when the rest is hidden.

Here the chroot owns one **slave** mount namespace:

- mounts created inside never propagate out;
- mounts created later in the global namespace (`/sdcard` after unlock) still
  propagate in, so the chroot sees them;
- direct adb/Termux login enters the same namespace with `nsenter`.

`chroot_ns_ephemeral.sh` uses a **private** namespace instead, because a
disposable session starts after unlock and does not need late mount events.

## Deploy

```sh
# from the dotfiles repo
adb push chroot/scripts/chroot_ns_boot.sh      /data/local/tmp/
adb push chroot/scripts/chroot_ns_holder.sh    /data/local/tmp/
adb push chroot/scripts/chroot_ns_enter.sh     /data/local/tmp/
adb push chroot/scripts/chroot_ns_stop.sh      /data/local/tmp/
adb push chroot/scripts/chroot_ns_ephemeral.sh /data/local/tmp/

adb shell 'chmod 755 /data/local/tmp/chroot_ns_*.sh'

# install boot entry (new file; use su because adb cannot write /data/adb)
adb shell 'su -c "cp /data/local/tmp/chroot_ns_boot.sh /data/adb/service.d/chroot_ns.sh &&
                  chmod 755 /data/adb/service.d/chroot_ns.sh"'

# reboot
adb reboot
```

If the old `chroot_sshd.sh` is still installed in `service.d`, disable it;
running both duplicates mounts and leaks.

## Use

```sh
# adb (interactive; -t -t forces a pty when stdin is not a tty)
adb shell -t -t 'su --no-pty -c /data/local/tmp/chroot_ns_enter.sh'

# one command
adb shell -t -t 'su --no-pty -c "/data/local/tmp/chroot_ns_enter.sh -c id"'

# Termux
archl-ns
archl-ns -c 'nvim'

# stop everything in the namespace
adb shell 'su -c /data/local/tmp/chroot_ns_stop.sh'
```

No holder running? `chroot_ns_enter.sh` falls back to
`chroot_ns_ephemeral.sh`, so direct login still works (mounts private,
auto-cleaned).

## Termux:Widget

New file: `termux/.shortcuts/nvim` → `~/.shortcuts/nvim` (executable).

It opens `nvim` in `~/Water/Fire` inside the chroot:

```sh
exec su --no-pty -c "exec /data/local/tmp/chroot_ns_enter.sh -c 'cd \"\$HOME/Water/Fire\" || exit 1; exec nvim'"
```

Verified as the Termux uid: cwd `/home/fire/Water/Fire`, `nvim` from
`/usr/bin/nvim` (NVIM v0.12.5).

## sshd

Off by default (`CHROOT_WITH_SSHD=0` in `chroot_ns_holder.sh`). Set it to `1`
if you still want `ssh fire@localhost` from the laptop. sshd then runs inside
the same hidden namespace; `arch-shell` keeps working unchanged.

## What is mounted inside

- `rbind /dev` — shares the host devpts. Do **not** mount a fresh devpts:
  a direct adb PTY is allocated on the host devpts, so a separate instance
  would make `tty`, job control and `/dev/tty` fail.
- `rbind /sys`, `bind /proc`, `bind /system`, `rbind /apex`,
  `bind /linkerconfig`, optional `vendor/product/odm/system_ext`.
- `tmpfs /dev/shm`, optional `bindfs /data` (ownership mapped to fire).
- After CE unlock: `bind /sdcard`, `bind /data/media/0/Documents/Fire`,
  `bind` Termux tmp and X11 socket.
- No `su -mm` anywhere.

## Verify

```sh
# must be 0 in init/apps
grep -c archl /proc/self/mountinfo
# must be >0 in the holder
grep -c archl /proc/$(cat /data/local/tmp/chroot_ns.pid)/mountinfo

# host pty must be intact
grep ' /dev/pts ' /proc/self/mountinfo

# inside direct login
adb shell -t -t 'su --no-pty -c "/data/local/tmp/chroot_ns_enter.sh -c \"id; tty\""'
# expect uid=1000(fire) and tty=/dev/pts/N
```

Expected: `archl` count is 0 in init and every app namespace; the holder
namespace contains all chroot mounts; `/sdcard` appears inside after unlock.

## Notes

- The holder namespace has `master:`/slave propagation; that is internal to
  the namespace and invisible to apps.
- Root can still inspect `/proc/<holder>/mountinfo`; unprivileged scanners
  cannot (Android `hidepid=2`).
- Do not run `chroot_min.sh`, `chroot_bare.sh` or `chroot_unmount.sh` for this
  setup. They mount in the caller's namespace.
- `chroot_ns_stop.sh` kills all processes in the namespace, including tmux,
  sshd and bindfs; the kernel then destroys the namespace and its mounts.
