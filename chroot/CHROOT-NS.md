# Arch chroot on Android — namespace hiding, direct login, and the patterns behind it

Working notes for the setup that runs on this phone (Motorola Edge 20 "berlin",
Android 17 / LineageOS, kernel 5.4.302-moto, APatch + ReZygisk).

Operational subset lives in `../chroot/chroot-ns.md`. This file is the *why*:
every pattern, every trap, and how to fix things when they break.

---

## Table of contents

1. [What is running right now](#1-what-is-running-right-now)
2. [Device facts worth memorising](#2-device-facts-worth-memorise)
3. [The problem: chroot mounts are visible to every app](#3-the-problem-chroot-mounts-are-visible-to-every-app)
4. [The Linux model: namespaces, propagation, mountinfo](#4-the-linux-model-namespaces-propagation-mountinfo)
5. [The three designs we tried](#5-the-three-designs-we-tried)
6. [The shipped architecture](#6-the-shipped-architecture)
7. [Every new file, line by line](#7-every-new-file-line-by-line)
8. [Direct login paths and the TTY rules](#8-direct-login-paths-and-the-tty-rules)
9. [Verification cookbook](#9-verification-cookbook)
10. [Failure modes → cause → fix](#10-failure-modes--cause--fix)
11. [Rules and anti-patterns](#11-rules-and-anti-patterns)
12. [Appendix A: ReVanced + Vector hiding (same session)](#12-appendix-a-revanced--vector-hiding-same-session)
13. [Appendix B: path / uid / namespace reference](#13-appendix-b-path--uid--namespace-reference)

---

## 1. What is running right now

| Piece | Where | Job |
|---|---|---|
| `chroot_ns.sh` | `/data/adb/service.d/chroot_ns.sh` | Boot entry: waits for boot, global setup, starts the holder |
| `chroot_ns_holder.sh` | `/data/local/tmp/` | Runs **inside** the slave namespace: all mounts, optional sshd, pid file |
| `chroot_ns_enter.sh` | `/data/local/tmp/` | Direct login: `nsenter` → `chroot` → `setpriv` → fire's shell |
| `chroot_ns_stop.sh` | `/data/local/tmp/` | Kills every process in the namespace; kernel removes all mounts |
| `chroot_ns_ephemeral.sh` | `/data/local/tmp/` | Fallback: one-shot **private** namespace, auto-cleanup |
| `archl-ns` | `~/bin` (Termux) | New Termux launcher for the above |
| `nvim` | `~/.shortcuts/nvim` (Termux) | Widget: opens nvim in `~/Water/Fire` inside the chroot |

Source of truth in the dotfiles:

```
chroot/scripts/chroot_ns_boot.sh
chroot/scripts/chroot_ns_holder.sh
chroot/scripts/chroot_ns_enter.sh
chroot/scripts/chroot_ns_stop.sh
chroot/scripts/chroot_ns_ephemeral.sh
chroot/chroot-ns.md
termux/scripts/archl-ns
termux/.shortcuts/nvim
```

Source copies in the dotfiles repo, deployed copies on the phone. The boot
entry must be copied with `su` — `adb push` cannot write into `/data/adb`:

```sh
adb push chroot/scripts/chroot_ns_boot.sh /data/local/tmp/
adb shell 'su -c "cp /data/local/tmp/chroot_ns_boot.sh /data/adb/service.d/chroot_ns.sh &&
                  chmod 755 /data/adb/service.d/chroot_ns.sh"'
```

---

## 2. Device facts worth memorising

* **Root shell namespace.** `su -c` runs in *init's* mount namespace, not a
  private one. On this device `readlink /proc/self/ns/mnt` and
  `readlink /proc/1/ns/mnt` both return `mnt:[4026533299]`. That single fact is
  the root cause of every leak we chased: a `mount` from a root shell is a
  **global** mount.
* **`service.d` context.** Boot scripts also run in init's namespace. The old
  `chroot_sshd.sh` proved it: its mounts showed up in `/proc/1/mountinfo`.
* **Apps get their own namespace inodes.** Each app process had a distinct
  `mnt:[40265344xx]` — Android 17 clones a namespace per app. That is why a
  mount leaked into init's tree also showed up inside apps: the app namespaces
  were cloned *after* the leak.
* **`hidepid=2` on `/proc`.** An unprivileged app can only read `/proc/<pid>`
  of its own uid. Duck Detector cannot read root/uid-1000 processes' mountinfo,
  so a chroot hidden in its own namespace is invisible to it.
* **Android uid 1000 is literally named `system`.** `fire` is uid 1000, so
  `ls -l` showing `system:system` on fire's files is correct, not a bug.
* **Termux uid** is `u0_a199` = 10199 on this device.
* **Toybox limits.** `mount` has no propagation flags and no `--make-rslave`;
  `chroot` has no `--userspec`; `unshare` exists but only as
  `unshare -m ...`; `nsenter` exists and needs `--` before a command that has
  its own options.
* **util-linux lives in the chroot**: `mount` 2.42.4, `unshare` 2.42.4,
  `nsenter`, `setpriv`, plus `bindfs`. Run them from the host root through the
  chroot's loader:

  ```sh
  /data/local/tmp/archl/usr/lib/ld-linux-aarch64.so.1 \
      --library-path /data/local/tmp/archl/usr/lib \
      /data/local/tmp/archl/usr/bin/unshare --propagation slave --mount ...
  ```

* **SELinux blocks `adb push` into `/data/adb`.** Push to `/data/local/tmp`
  and `su -c cp` it into place.
* **`adb shell` and PTYs.** `adb shell <cmd>` allocates no PTY; bare
  `adb shell` does. When stdin is not a terminal you need `adb shell -t -t`.
* **Toybox `date +%s%N` returns garbage** (negative deltas). Measure timing on
  the host with real coreutils.

---

## 3. The problem: chroot mounts are visible to every app

Duck Detector's Mount card builds a signature per mount entry and flags a
token anywhere in it. From its scanner (`ProcMountViewScanner.kt`):

```kotlin
fun signature(): String =
    listOf(source, root, point, type, options, comparableSuperOptions()).joinToString(" ")
```

Tokens: `magisk`, `KSU`, `/adb/`.

Two separate failure modes were found:

1. **Token hit.** Vector's `dex2oat` bind mounts had `/adb/modules/...` in the
   **root** field → instant DANGER.
2. **Structural hit.** The chroot's own mounts (`/data/local/tmp/archl/dev`,
   `.../sys`, `.../proc`) were in init's namespace, so Duck's `zygote_next`
   isolated-service view saw "root-managed mount records" and reported a
   Mount DANGER even without any token match.

The chroot mounts contain no `magisk`/`KSU`/`/adb/` token — they were flagged
structurally. The fix was therefore not cosmetic: the mounts had to leave the
global namespace entirely.

**Mountify cannot help.** Mountify mounts module `system/` content at boot and
can spoof the device name of the mounts *it* creates. Chroot mounts are runtime
mounts made by a shell; no module can retroactively hide another namespace's
mounts. Hiding is a namespace property, not a mount-table edit.

---

## 4. The Linux model: namespaces, propagation, mountinfo

### 4.1 Mount namespaces

Every process has its own view of the mount tree. Creating a namespace copies
the tree; what happens afterwards depends on **propagation**.

| Type | Behaviour |
|---|---|
| `shared:N` | Peer group `N`. Mount/unmount events underneath are **replicated to every peer**. |
| `slave` / `rslave` (`master:N`) | **Receives** events from its master, **never sends its own back**. |
| `private` | Neither receives nor sends. |
| `unbindable` | Like private, and can never become shared. |

Reading it from `/proc/self/mountinfo` (field 7, after the options):

```
36 35 0:17 / /dev rw,nosuid,relatime shared:2 - tmpfs tmpfs rw,seclabel,...
 │  │  │   │  │              │          │ │ │
 │  │  │   │  │              │          │ │ └── super options
 │  │  │   │  │              │          │ └── source
 │  │  │   │  │              │          └── filesystem type
 │  │  │   │  │              └── separator
 │  │  │   │  └── propagation: shared:2 = peer in group 2
 │  │  │   └── mount point
 │  │  └── root of the filesystem within the mount
 │  └── major:minor
 └── mount id (parent id is the second column)
```

`shared:N` → I am a peer in group N. `master:N` → I am a slave of group N.

### 4.2 The rule that cost us a reboot

**Set propagation BEFORE you create any bind.**

Order A (wrong): bind first, fix propagation later.
Order B (right): unshare → set propagation → bind.

With order A the bind clones of `/dev` and `/sys` joined `/dev`'s existing
peer group, so their submounts propagated straight out into init. We measured
**24 leaked mount entries** in `/proc/self/mountinfo` after a single "harmless"
`mount --rbind /dev`.

### 4.3 The unmount that ate the host's `/dev/pts`

`umount -l "$CHROOT/dev/pts"` on a mount that is a **peer** of the host's
`/dev` propagates: the kernel replays "unmount `/dev/pts`" on every peer,
where that path resolves to the **host's** `/dev/pts`. Result:

```
error: failed to create pty master: No such device
```

`adb shell` died because `adbd` could not allocate a PTY. `/dev/binderfs`,
`/dev/usb-ffs/*`, `/dev/cgroup` submounts went with it.

* `-l` is not the cause — plain `umount` propagates too. `-l` only removes the
  "busy" safety net, so it *succeeds* at doing the damage.
* Recovery without a reboot:
  `mount -t devpts devpts /dev/pts -o mode=666,gid=5`
* Prevention: never leave peer-group clones in the global namespace. If they
  exist, unmount them **after** detaching them from the peer group, or reboot.
* `umount` on `shared:` mounts returns EBUSY → use `umount -l` (this bit us
  with Vector's redirect mounts; see Appendix A).

### 4.4 `realpath()` and mount roots

`Vector`'s daemon calls `realpath("bin/dex2oat32")` relative to its working
directory, then bind-mounts the resolved path. If a bind mount is placed over
the file *before* the daemon starts, `realpath()` resolves to the new source
and the resulting global mount has the **clean** root — no post-hoc remount
race. This is the same trick used for the chroot: fix the source, not the
symptom.

---

## 5. The three designs we tried

### Design 1 — global mounts (the old way) ❌

`service.d` → `mount --rbind /dev ...` in init's namespace.

* Result: `/data/local/tmp/archl/{dev,sys,proc}` visible to init and to every
  app namespace cloned afterwards.
* `su -mm` for `/sdcard` made it worse — that is an *explicit* global mount.
* `/dev/pts` peer-group hazard (section 4.3).
* Verdict: works, leaks, can break the phone.

### Design 2 — private namespace, per session ✅ (ephemeral)

```sh
unshare --propagation private --mount /system/bin/sh /data/local/tmp/chroot_ns_ephemeral.sh
```

* Everything inside is invisible outside; nothing propagates in.
* Kernel destroys the namespace and all its mounts when the last process
  exits → **no cleanup script ever needed**.
* Limitation: vold's `/sdcard` mounts appear *after* unlock, and a private
  namespace never receives them. Fine for a session started after unlock.

Measured (private namespace, 25 mounts inside):

```
inside namespace: 25 archl mounts
host /proc/self/mountinfo: 0
```

### Design 3 — slave namespace, persistent ✅ (shipped)

```sh
nsenter -t 1 -m -- <loader> ... unshare --propagation slave --mount \
    /system/bin/sh /data/local/tmp/chroot_ns_holder.sh
```

* A **slave** namespace still receives mount events from the global namespace,
  so `/sdcard` and the CE FUSE mounts show up after unlock.
* Mounts created inside never propagate out.

Measured (slave namespace, live):

| Test | Result |
|---|---|
| global mount created **after** ns creation | visible inside (`child_sees_prop_src=1`) |
| mount created **inside** the ns | **0** entries in global |
| `rbind /dev` inside the ns | **0** entries in global |
| fresh `devpts` over the cloned `/dev/pts` | global untouched, host `/dev/pts` mount id still 37 |
| bind of a real path inside the ns | **0** entries in global |
| host `/dev/pts`, `/dev/binderfs` | intact |

That is the whole reason the shipped design is *slave* and not *private*:
the boot-time namespace must see `/sdcard` appear later, while its own mounts
must never be seen by anyone else.

### Why `nsenter -t 1 -m` first

`service.d` scripts run in init's namespace today, but that is an
implementation detail of APatch, not a guarantee. Entering PID 1's mount
namespace explicitly makes the holder a slave of *init* no matter where the
boot script was started from. If `nsenter` is unavailable the boot script logs
a warning and continues with the current namespace (still hidden, but late
global mounts may not arrive).

---

## 6. The shipped architecture

```
boot
 └─ /data/adb/service.d/chroot_ns.sh
     ├─ wait for sys.boot_completed=1
     ├─ global, non-mount setup: WoWLAN, magiskpolicy, IPv6 EUI-64 loop
     └─ setsid nsenter -t 1 -m -- unshare --propagation slave --mount
           └─ chroot_ns_holder.sh        (stays alive as `sleep 2147483647`)
                ├─ remount /data exec (private copy of the mount object)
                ├─ rbind /dev, rbind /sys, bind /proc, /system, rbind /apex,
                │  /linkerconfig, vendor/product/odm/system_ext
                ├─ tmpfs /dev/shm
                ├─ bindfs /data  ->  $CHROOT/data   (fire owns everything)
                ├─ optional sshd (CHROOT_WITH_SSHD=1)
                ├─ write $PIDFILE
                └─ background CE watcher
                     └─ after sys.user.0.ce_available=true:
                        bind /sdcard, bind Documents/Fire,
                        bind Termux tmp + X11 socket

login
 └─ su --no-pty -c /data/local/tmp/chroot_ns_enter.sh
      └─ nsenter -t $PID -m -- chroot $CHROOT /usr/bin/setpriv --reuid=1000 ...
           └─ fire's login shell (zsh) in $HOME

stop
 └─ chroot_ns_stop.sh
      └─ kill every process whose /proc/<pid>/ns/mnt matches the holder
           └─ kernel destroys the namespace and every mount in it
```

Nothing in that tree is visible from init. Measured after a real reboot:

```
host / init archl mounts : 0
app namespaces archl     : 0
holder namespace archl   : 122  (invisible to everyone else)
host /dev/pts            : intact
host /dev/binderfs       : intact
direct login             : uid=1000(fire)  tty=/dev/pts/0
                           /sdcard visible, Water/Fire visible, bindfs /data visible
```

---

## 7. Every new file, line by line

### 7.1 `chroot_ns_boot.sh` → `/data/adb/service.d/chroot_ns.sh`

| Knob | Default | Meaning |
|---|---|---|
| `CHROOT_PATH` | `/data/local/tmp/archl` | rootfs location |
| `HOLDER` | `/data/local/tmp/chroot_ns_holder.sh` | script run inside the namespace |
| `PIDFILE` | `/data/local/tmp/chroot_ns.pid` | holder pid, read by the login helper |
| `LOG` | `/data/local/tmp/chroot_ns_boot.log` | boot log |

Sequence:

1. `while [ "$(getprop sys.boot_completed)" != "1" ]; do sleep 3; done`
2. Global tasks that are **not** mounts and must stay global:
   * `iw phy phy0 wowlan enable magic-packet` (wake from Doze for SSH)
   * `magiskpolicy --live 'allow untrusted_app_all magisk unix_stream_socket {...}'`
     (Termux:API clipboard). Path is probed: `/data/adb/ap/bin/magiskpolicy`
     first, `/data/adb/magisk/magiskpolicy` second.
   * IPv6 EUI-64 loop for `wlan0..wlan2`, `softap0`.
3. `rm -f "$PIDFILE" "${PIDFILE}.ce"` — never inherit a stale pid.
4. `setsid nsenter -t 1 -m -- <loader> ... unshare --propagation slave --mount
   /system/bin/sh "$HOLDER" &`
   `setsid` detaches the holder from the service shell so it survives the
   script exiting.
5. Wait up to 20 s for `$PIDFILE`, then log the holder pid.

`setsid` matters: without it the holder can be killed by the shell's exit
(SIGHUP) and the whole namespace would vanish a few seconds after boot.

### 7.2 `chroot_ns_holder.sh` (inside the namespace)

| Knob | Default | Meaning |
|---|---|---|
| `CHROOT_WITH_BINDFS` | `1` | bindfs `/data` → `$CHROOT/data` (fire owns everything) |
| `CHROOT_WITH_SSHD` | `0` | start sshd inside the namespace |
| `TERMUX_PREFIX` | `/data/data/com.termux/files` | source for the X11/tmp bridges |

Key details:

* **No fresh `devpts`.** `rbind /dev` shares the host's devpts instance, so an
  adb/Termux PTY (allocated by `adbd` on the host devpts) exists inside the
  chroot as the same `/dev/pts/N`. A separate devpts instance inside the chroot
  makes `tty`, job control and `/dev/tty` fail. This is the single most
  important line in the file — it is the reason direct login works.
* **`rbind /sys`, not `bind /sys`.** `/sys` has submounts (`fs/cgroup`,
  `fs/selinux`, `kernel/tracing`, `fs/bpf`, `fs/pstore`, `kernel/security`);
  a plain bind would leave the chroot without them.
* **`rbind /apex`** for the same reason (each apex is its own mount).
* **`mount -o remount,dev,suid,exec /data`** — per-mount flags, so the global
  `/data` mount object is untouched. Only done when `/data` lacks `exec`.
* **`mounted()`** helper: `awk -v p="$1" '$5==p {f=1} END {exit !f}'
  /proc/self/mountinfo`. Field 5 is the mount point. Idempotent mounts.
* **bindfs** runs the chroot's own binary through the chroot's loader, with
  `-o suid -u 1000 -g 1000`. It is a FUSE mount; it lives in this namespace.
* **sshd** is opt-in. It lives in the namespace, so `ssh fire@localhost` from
  the laptop still works, and `arch-shell` needs no change.
* **`echo $$ > "$PIDFILE"`** is written *after* the mounts, so a present pid
  file means "the environment is ready".
* **CE watcher**: waits for `sys.user.0.ce_available=true`, then binds
  `/sdcard` → `$CHROOT/sdcard`, `/data/media/0/Documents/Fire` →
  `$CHROOT/home/fire/Water/Fire`, Termux `usr/tmp` → `$CHROOT/termux-tmp` and
  `usr/tmp/.X11-unix` → `$CHROOT/tmp/.X11-unix`. It checks
  `[ -d "/proc/$HOLDER_PID" ]` each loop and exits if the holder died, so it
  cannot keep a dead namespace alive.
* **`exec sleep 2147483647`** keeps the namespace alive with the *same* pid,
  and makes the holder a single killable process.

### 7.3 `chroot_ns_enter.sh` (direct login)

| Knob | Default | Meaning |
|---|---|---|
| `PIDFILE` | `/data/local/tmp/chroot_ns.pid` | holder pid |
| `EPHEMERAL` | `/data/local/tmp/chroot_ns_ephemeral.sh` | fallback launcher |
| `EPHEMERAL_OPTS` | `--with-sdcard --with-fire` | mounts for the fallback session |

Logic:

1. Parse `-l`, `-c CMD`, `--`; anything else is treated as argv.
2. Read the holder pid. Missing/dead → **fall back to the ephemeral launcher**
   with `EPHEMERAL_OPTS`, so a direct login still works before the holder
   finished booting or after it was stopped.
3. Refuse to continue if the holder's namespace equals init's, or if we are
   already inside it (no nested namespaces).
4. Export a real Arch environment: `PATH`, `HOME=/home/fire`, `USER`, `LOGNAME`,
   `TERM`, and `SHELL` read from **`/etc/passwd` field 7** (not `$SHELL` from
   the environment — that describes the shell you *were*).
5. `exec nsenter -t "$PID" -m -- chroot "$CHROOT" /usr/bin/setpriv --reuid=1000
   --regid=1000 --init-groups "$@"` — drop privileges *inside* the chroot,
   because toybox `chroot` has no `--userspec`.

### 7.4 `chroot_ns_stop.sh`

Reads the holder pid, resolves its namespace inode, then:

```sh
for p in /proc/[0-9]*; do
    pns=$(readlink "$p/ns/mnt" 2>/dev/null) || continue
    [ "$pns" = "$HOLDER_NS" ] || continue
    kill "${p#/proc/}" 2>/dev/null
done
```

SIGTERM, one second later SIGKILL for anything left. That kills tmux, sshd,
bindfs, the CE watcher and the holder in one sweep; the kernel then destroys
the namespace and every mount in it. No `umount` needed, and no risk of
peeling a peer-group clone off the host.

Safety checks before killing: refuse if the holder's namespace is init's, and
refuse if the script itself is already inside it.

Performance note: iterating `/proc` and calling `readlink` per pid is a fork
per pid. In one shell it is a builtin-free loop but still ~1000 execs; the
same sweep with `readlink /proc/[0-9]*/ns/mnt` in one call is much faster.
Keep it in one loop, and never add a per-pid `readlink /proc/$p/root` busy
check (that variant measured **14.5 s** for 716 processes).

### 7.5 `chroot_ns_ephemeral.sh` (fallback)

Same body as the holder but:

* `unshare --propagation private` instead of `slave`;
* optional mounts: `--with-data`, `--with-sdcard`, `--with-fire`,
  `--with-termux-tmp`;
* `-c CMD` support;
* no pid file, no sshd, no CE watcher;
* dies with the last process, kernel removes the mounts.

### 7.6 `archl-ns` (Termux) and `~/.shortcuts/nvim`

`archl-ns` mirrors the old `archl` but calls `chroot_ns_enter.sh`:

```sh
exec su --no-pty -c "exec /data/local/tmp/chroot_ns_enter.sh -c $(quote "$CMD")"
```

`--no-pty` is essential: APatch's `su` allocates a **second** pty by default,
which leaves the chroot shell's output stuck until the outer pty receives
input. Termux:Widget's `nvim` shortcut uses the same call:

```sh
exec su --no-pty -c "exec /data/local/tmp/chroot_ns_enter.sh -c 'cd \"\$HOME/Water/Fire\" || exit 1; exec nvim'"
```

It calls the device helper directly instead of `archl-ns`, so it does not
depend on anything being in `PATH`.

---

## 8. Direct login paths and the TTY rules

| Entry point | Command | Notes |
|---|---|---|
| adb | `adb shell -t -t 'su --no-pty -c /data/local/tmp/chroot_ns_enter.sh'` | `-t -t` needed when stdin is not a tty |
| adb, one command | `adb shell -t -t 'su --no-pty -c "/data/local/tmp/chroot_ns_enter.sh -c id"'` | runs as fire |
| Termux | `archl-ns` / `archl-ns -c 'nvim'` | needs the script in `~/bin` |
| Termux widget | `~/.shortcuts/nvim` | opens nvim in `~/Water/Fire` |

TTY rules, all learned the hard way:

* `adb shell <cmd>` allocates **no** PTY; bare `adb shell` does. In scripts use
  `-t -t`. Symptom of a missing pty: `Remote PTY will not be allocated because
  stdin is not a terminal`, then `tty` prints `not a tty`.
* `su` without `--no-pty` allocates a second pty → output appears frozen.
* Inside the chroot the PTY must exist in the chroot's `/dev/pts`. That only
  works because the holder **shares the host devpts** via `rbind /dev`.
* `ttyname()` resolves through the process root. Inside the chroot the path is
  `/dev/pts/N` because the chroot's `/dev` is the shared host devpts.

Verified inside a direct session:

```
id=uid=1000(fire) gid=1000(fire) groups=...
tty=/dev/pts/0
ns=mnt:[4026534587]      <- the holder namespace
```

---

## 9. Verification cookbook

### Is anything leaking?

```sh
# init's namespace (must be 0)
grep -c archl /proc/1/mountinfo

# any app you can see (must be 0)
for p in $(ps -A -o PID,USER | awk '$2 ~ /^u0_a/ {print $1}' | head -6); do
    echo "$p $(grep -c archl /proc/$p/mountinfo 2>/dev/null) $(tr '\0' ' ' < /proc/$p/cmdline)"
done

# the holder itself (should be > 0: the mounts DO exist, just privately)
grep -c archl /proc/$(cat /data/local/tmp/chroot_ns.pid)/mountinfo
```

`/proc/<pid>/mountinfo` for another uid is unreadable by apps because of
`hidepid=2` — that is why the holder's mounts are invisible to Duck Detector.

### Is the host intact?

```sh
grep ' /dev/pts ' /proc/self/mountinfo        # must exist
grep ' /dev/binderfs ' /proc/self/mountinfo   # must exist
ls /dev/pts                                  # ptmx + numbered slaves
adb shell 'tty'                              # must not be "not a tty"
```

### Is the environment complete?

```sh
adb shell -t -t 'su --no-pty -c "/data/local/tmp/chroot_ns_enter.sh /bin/sh -c \"id; tty; ls /sdcard | head -3; ls /home/fire/Water/Fire | head -3\""'
```

Expect `uid=1000(fire)`, `tty=/dev/pts/N`, real `/sdcard` contents, real
`Water/Fire` contents.

### Boot log

```sh
adb shell 'su -c "cat /data/local/tmp/chroot_ns_boot.log"'
```

Good boot:

```
=== chroot_ns boot ... ===
boot completed at ...
WoWLAN magic-packet enabled
sepolicy applied via /data/adb/ap/bin/magiskpolicy
HH:MM:SS bindfs /data mounted
HH:MM:SS waiting for CE storage (holder NNNN)
HH:MM:SS holder ready (pid NNNN, ns mnt:[...])
holder pid NNNN
=== chroot_ns boot finished at ... ===
HH:MM:SS bound /sdcard
HH:MM:SS bound Water/Fire
HH:MM:SS bound termux-tmp
HH:MM:SS CE mounts done
```

`bound /sdcard` appears ~20 s after boot on this device — that is the CE
unlock, not a bug. Before unlock the chroot has no `/sdcard`.

---

## 10. Failure modes → cause → fix

| Symptom | Cause | Fix |
|---|---|---|
| Duck Mount DANGER, no `/adb/` token | chroot mounts in init's namespace | use the namespace scripts; never mount from a plain root shell |
| Duck Mount DANGER, `root=/adb/modules/...` | Vector's dex2oat mounts | Appendix A: `vector_hide_dex2oat.sh` |
| `adb shell` → "failed to create pty master" | host `/dev/pts` unmounted by a propagated unmount | `mount -t devpts devpts /dev/pts -o mode=666,gid=5`, or reboot; then fix the peer-group clones |
| `umount: ... Invalid argument` / EBUSY | mount is `shared:` | `umount -l` (lazy) |
| `umount ... No such file or directory` spam | parent already detached, children orphaned | unmount deepest-first; ignore ENOENT, then verify with `grep archl /proc/mounts` |
| Direct login: `tty` → "not a tty" | `adb shell` without pty, or `su` pty | `adb shell -t -t`, `su --no-pty` |
| Direct login: output frozen | `su` allocated a second pty | `su --no-pty` |
| Direct login: `tty` fails / no job control | chroot has its own devpts instance | drop the extra `mount -t devpts`, keep `rbind /dev` |
| `ls: command not found` | Android's `PATH=/system/bin` leaked in | export Arch `PATH` before `exec chroot` |
| Prompt shows `root` instead of `fire` | toybox `chroot` has no `--userspec` | `setpriv --reuid=1000 --regid=1000 --init-groups` inside the chroot |
| `$SHELL` is not the running shell | `$SHELL` describes the previous shell | read field 7 of `/etc/passwd` for uid 1000 |
| Chroot mirrors itself (41 mounts) | `mount --rbind /data $CHROOT/data` while `$CHROOT` is inside `/data` | plain `bind` for `/data`, or bindfs |
| `/sdcard` empty inside the chroot | CE not unlocked yet, or namespace is private | wait for `sys.user.0.ce_available=true`; use a **slave** namespace |
| `bindfs` fails | `/dev/fuse` missing or FUSE denied | ensure `rbind /dev`; run bindfs via the chroot's loader |
| Holder gone after boot | service script exited and took the child with it | `setsid` the holder; check the boot log |
| Holder dies when the boot script ends | SIGHUP | `setsid` |
| Namespace not visible to the holder | mount propagation mismatch | `unshare --mount --propagation slave` before any bind |
| `chroot` needs `/bin/sh` but host has none | inside chroot the root is the chroot | always use the chroot's own `/bin/sh` |
| Stale pid file | holder crashed | `rm -f $PIDFILE`; the stop script removes it too |
| `unshare`/`mount` "not found" from host | util-linux only exists inside the chroot | run via `<chroot>/usr/lib/ld-linux-aarch64.so.1 --library-path ...` |
| `nsenter: Unknown option 'c'` | toybox nsenter parsed the child's flags | put `--` before the command |
| `adb push` to `/data/adb/...` fails | SELinux | push to `/data/local/tmp`, then `su -c cp` |
| Termux widget does not appear | widget list cached | restart Termux / re-add the widget |
| 15 s teardown | per-pid `readlink /proc/$p/root` loop | batch the readlinks or use `awk` on mountinfo |

---

## 11. Rules and anti-patterns

**Do**

* Create the namespace, set propagation, *then* bind.
* Use `--propagation slave` for anything that must survive until after
  unlock; `--propagation private` for disposable sessions.
* Share the host devpts; never mount a second one.
* Use `su --no-pty` for every interactive entry point.
* Read the login shell from `/etc/passwd`.
* Verify with `grep -c archl /proc/1/mountinfo` after every change.
* Let the kernel do the cleanup: kill the namespace's processes instead of
  unmounting peer-group clones.

**Don't**

* Don't `mount` from a plain root shell and hope it stays local.
* Don't `umount`/`umount -l` a mount that is still in the host's peer group.
* Don't use `su -mm` for chroot mounts — that is a global mount by design.
* Don't mount a fresh `devpts` if you want adb/Termux logins to work.
* Don't run the old `chroot_min.sh` / `chroot_bare.sh` / `chroot_unmount.sh`
  against this setup; they mount in the caller's namespace.
* Don't run `chroot_sshd.sh` and `chroot_ns.sh` at the same time.
* Don't trust `$SHELL`, don't trust `adb shell` for pty tests, and don't trust
  toybox `mount` for propagation flags.

---

## 12. Appendix A: ReVanced + Vector hiding (same session)

Different problem, same theme: **make the offending mount invisible, or make
the source clean before anyone can see it.**

### 12.1 YouTube / YT Music ReVanced

* Old-style ReVanced modules (`com.google.android.youtube-revanced`) get
  **uninstalled by Package Manager on reboot**: the patched APK (wrong
  signature) is visible in the global namespace at boot, so PM sees a
  signature mismatch and deletes the package.
* Fix: j-hc **morphe** modules (`youtube-morphe-jhc`,
  `music-morphe-jhc-arm64`) + **rvmm-zygisk-mount**. rvmm hooks
  `preAppSpecialize` and bind-mounts the patched APK **inside each app's own
  mount namespace**. PM only ever sees the stock APK → no uninstall, and the
  mount is invisible to every other process.
* Flash order on a fresh phone: morphe-youtube → morphe-music → rvmm, **no
  reboot in between**, then one reboot.
* YouTube and YT Music must **not** be in APatch's exclude list
  (`package_config`), or the zygisk hook never fires.

### 12.2 Vector (LSPosed fork) dex2oat mounts

Vector replaces the AOT compiler so it can instrument compiled code. Its
daemon does it in `doMountNative` (JNI): it forks, `setns(/proc/1/ns/mnt)`
(joins **init's** namespace), and bind-mounts
`$MODDIR/bin/dex2oat{32,64}` over `/apex/com.android.art/bin/dex2oat{32,64}`
with **shared** propagation. The mountinfo then carries `/adb/` in both the
root and the point field → Duck DANGER. There is no per-app way to fix this:
dex2oat must be global.

Fix (new file, `android/vector_hide_dex2oat.sh`, installed as
`/data/adb/post-fs-data.d/vector_hide_dex2oat.sh`):

1. **post-fs-data, before the daemon starts:** copy the wrappers to
   `/data/local/vector-bin/`, `chcon u:object_r:dex2oat_exec:s0`, then bind
   them over `$MODDIR/bin/dex2oat*`. The daemon's `realpath("bin/dex2oat32")`
   now resolves to `/local/vector-bin/dex2oat32`, so the global apex mounts
   get the clean root from the start — no race, no remount.
2. **service stage, after the daemon has mounted:** lazy-unmount the two
   redirect mounts (their *target* path contains `/adb/`), because the scanner
   checks the whole signature, not just the root field.

The lazy unmount is mandatory:

```sh
umount -l "$SRC/dex2oat32"   # shared:37 -> plain umount returns EBUSY and fails
umount -l "$SRC/dex2oat64"
```

The cleanup script self-deletes and is recreated by the post-fs-data script
each boot.

Result: global `/adb/` token count **0**, Duck Mount card clean, and Vector
still works.

### 12.3 Things that are not fixable (do not chase these)

* **Duck TEE DANGER** — a Motorola Edge 20 KeyMint 3+ firmware quirk
  (`RSA_OAEP_MGF_DIGEST` omitted). Attestation itself is aligned; Tricky Store
  cannot fix it. Unrelated to root hiding.
* **Duck LSPosed warning** — comes from **APatch's** sepolicy patches
  (`system_server → system_server:process execmem` allowed,
  `untrusted_app → magisk:binder call` allowed). Vector's own rule
  (`untrusted_app → lsposed_file:file read`) is **denied**, i.e. clean.
* **Custom ROM / ADB / SELinux / system-property warnings** — expected on a
  rooted LineageOS device.
* **`MOUNT_DEVICE_NAME="APatch"`** in the mountify config — cosmetic only;
  mountify cannot hide runtime mounts (see section 3).
* **APatch "Hide SELinux modification"** (`/data/adb/ap/selinux_hide`) — must
  **not** exist on this 5.4 non-GKI kernel; it breaks `setexeccon`.

---

## 13. Appendix B: path / uid / namespace reference

| Thing | Value |
|---|---|
| Chroot rootfs | `/data/local/tmp/archl` (Arch Linux ARM64) |
| Termux prefix | `/data/data/com.termux/files` (uid 10199 = `u0_a199`) |
| Fire's data | `/data/media/0/Documents/Fire` → `/home/fire/Water/Fire` inside the chroot |
| fire | uid 1000, gid 1000 (= Android `system`), shell `/usr/bin/zsh` |
| Holder pid file | `/data/local/tmp/chroot_ns.pid` |
| Boot log | `/data/local/tmp/chroot_ns_boot.log` |
| Vector wrappers | `/data/local/vector-bin/dex2oat{32,64}` |
| Vector hide script | `/data/adb/post-fs-data.d/vector_hide_dex2oat.sh` |
| rvmm patched APKs | `/data/adb/rvhc/*.apk`, map in `/data/adb/modules/rvmm-zygisk-mount/procs_map` |
| init mount namespace | `mnt:[4026533299]` (constant for this boot) |
| app mount namespaces | distinct per app, e.g. `mnt:[4026534403]`+ |
| util-linux in chroot | `mount`/`unshare`/`nsenter` 2.42.4, `setpriv`, `bindfs` |
| loader trick | `<chroot>/usr/lib/ld-linux-aarch64.so.1 --library-path <chroot>/usr/lib <binary>` |

Useful one-liners:

```sh
# which namespace am I in?
readlink /proc/self/ns/mnt

# what does the holder see that nobody else does?
grep archl /proc/$(cat /data/local/tmp/chroot_ns.pid)/mountinfo | head

# propagation of a mount (shared: = peer, master: = slave, nothing = private)
grep ' /data ' /proc/self/mountinfo

# one-shot private namespace, no leftovers
unshare --propagation private --mount /system/bin/sh -c 'echo hidden'
```
