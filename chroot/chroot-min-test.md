# Arch Linux ARM chroot on Android — reference

Minimal chroot launcher for the Arch ARM rootfs at `/data/local/tmp/archl`, replacing
the heavyweight `chroot_sshd.sh`. Drops to user `fire` (uid 1000), runs fire's real
login shell, and mounts only what basic binaries need.

| File | Purpose |
|---|---|
| `scripts/chroot_min.sh` | Enter the chroot |
| `scripts/chroot_unmount.sh` | Tear the mounts back down |

---

## Table of contents

1. [Quick start](#1-quick-start)
2. [The scripts](#2-the-scripts)
3. [Configuration](#3-configuration)
4. [How it works](#4-how-it-works)
5. [Mount namespaces and propagation](#5-mount-namespaces-and-propagation-the-core-concept)
6. [The `/dev/pts` incident](#6-the-devpts-incident-why-adb-shell-broke)
7. [The fix](#7-the-fix)
8. [Implementation traps](#8-implementation-traps)
9. [Regression testing](#9-regression-testing)
10. [Every bug hit along the way](#10-every-bug-hit-along-the-way)
11. [Performance notes](#11-performance-notes)
12. [Troubleshooting](#12-troubleshooting)
13. [Known caveats](#13-known-caveats)
14. [Appendix: running this rootfs on an x86_64 PC](#14-appendix-running-this-rootfs-on-an-x86_64-pc)

---

## 1. Quick start

```sh
# deploy
adb push scripts/chroot_min.sh     /data/local/tmp/chroot_min.sh
adb push scripts/chroot_unmount.sh /data/local/tmp/chroot_unmount.sh
adb shell 'chmod 755 /data/local/tmp/chroot_min.sh /data/local/tmp/chroot_unmount.sh'

# enter (interactive, as fire)
sh /data/local/tmp/chroot_min.sh

# one-shot command, as fire
sh /data/local/tmp/chroot_min.sh /bin/ls -la

# also expose /data inside (opt-in; mirrors the chroot inside itself)
sh /data/local/tmp/chroot_min.sh --with-data

# see what would be detached, touch nothing
sh /data/local/tmp/chroot_unmount.sh -n

# tear down
sh /data/local/tmp/chroot_unmount.sh
```

Expected prompt: `fire@localhost:~$` (zsh, in `$HOME`). You should land in `/home/fire`,
not `/`.

Verify you are actually running zsh and it loaded your config:

```sh
echo $0      # -> /usr/bin/zsh
tty         # -> /dev/pts/N
ls          # -> your files, not "command not found"
```

---

## 2. The scripts

### `scripts/chroot_min.sh`

```sh
#!/system/bin/sh
# Minimal chroot launcher -> drops to user `fire`
# Usage: sh chroot_min.sh [--with-data] [cmd...]
#        --with-data  also bind /data in (mirrors the chroot inside itself; off by default)

CHROOT_PATH="/data/local/tmp/archl"
UID_FIRE=1000
GID_FIRE=1000

WITH_DATA=""
for arg in "$@"; do
    case "$arg" in
        --with-data) WITH_DATA=1 ;;
        *) break ;;
    esac
done
[ "$WITH_DATA" ] && shift

# is $CHROOT_PATH/$1 a mountpoint?
is_mounted() {
    awk -v p="$CHROOT_PATH/$1" '$2==p { f=1 } END { exit !f }' /proc/mounts
}

# bind $1 -> $CHROOT_PATH/$2, skip if already there. $3 = r for recursive.
bind() {
    is_mounted "$2" && return 0
    mkdir -p "$CHROOT_PATH/$2"
    if [ "$3" = "r" ]; then
        mount --rbind "$1" "$CHROOT_PATH/$2"
    else
        mount --bind "$1" "$CHROOT_PATH/$2"
    fi
}

# /data must allow exec or nothing inside can run
case ",$(awk '$2=="/data" { print $4; exit }' /proc/mounts)," in
    *,exec,*) ;;
    *) mount -o remount,dev,suid,exec /data ;;
esac

bind /dev  dev r   # rbind: needs submounts (dev/pts, binderfs, usb-ffs)
bind /sys  sys
bind /proc proc
[ -n "$WITH_DATA" ] && bind /data data

# CRITICAL: /dev and /data are shared-peer-group mounts on Android, so an
# --rbind clone lands in the SAME peer group. Unmounting inside the chroot then
# propagates back out and takes the HOST's mount with it (this is exactly how
# /dev/pts got torn off the host). Re-slave them so events flow in only.
# toybox mount has no propagation flags, so borrow util-linux's mount from
# inside the chroot -- propagation is a property of the mount object, so it
# applies globally no matter where you change it.
# NOTE: --make-rslave takes exactly ONE target; passing several gives
# "mount: bad usage" and silently changes nothing.
if [ -x "$CHROOT_PATH/usr/bin/mount" ]; then
    for t in /dev /sys /proc; do
        chroot "$CHROOT_PATH" /usr/bin/mount --make-rslave "$t" 2>/dev/null \
            || echo "warning: could not make $t a slave mount" >&2
    done
    if [ -n "$WITH_DATA" ]; then
        chroot "$CHROOT_PATH" /usr/bin/mount --make-rslave /data 2>/dev/null \
            || echo "warning: could not make /data a slave mount" >&2
    fi
fi

if ! is_mounted dev/pts; then
    mkdir -p "$CHROOT_PATH/dev/pts"
    mount -t devpts devpts "$CHROOT_PATH/dev/pts"
fi

# Android's PATH (/system/bin) is useless inside; set the Arch one before dropping privs
PATH=/usr/local/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
HOME=/home/fire
USER=fire
LOGNAME=fire
TERM="${TERM:-xterm-256color}"

# fire's real login shell from /etc/passwd.
# Do NOT trust $SHELL -- that env var says what you *were*, not what is running.
LOGIN_SHELL="$(awk -F: -v u="$UID_FIRE" '$3==u { print $7; exit }' "$CHROOT_PATH/etc/passwd")"
[ -x "$CHROOT_PATH$LOGIN_SHELL" ] || LOGIN_SHELL=/bin/bash
SHELL="$LOGIN_SHELL"
export PATH HOME USER LOGNAME SHELL TERM

# chroot starts you in /, so cd home first; -l makes it a login shell (reads .zshrc)
if [ "$#" -eq 0 ]; then
    set -- /bin/sh -c 'cd "$HOME" || cd /; exec "$SHELL" -l'
fi

# toybox chroot has no --userspec, so drop privileges inside the chroot instead
if [ -x "$CHROOT_PATH/usr/bin/setpriv" ]; then
    exec chroot "$CHROOT_PATH" /usr/bin/setpriv \
        --reuid="$UID_FIRE" --regid="$GID_FIRE" --init-groups "$@"
else
    exec chroot "$CHROOT_PATH" "$@"
fi
```

### `scripts/chroot_unmount.sh`

```sh
#!/system/bin/sh
# Tear down chroot_min.sh's bind-mounts. Lazy detach, safe to re-run.
# Usage: sh chroot_unmount.sh [-n]     -n = list only, touch nothing

CHROOT_PATH="/data/local/tmp/archl"

if [ "$1" = "-n" ]; then
    DRYRUN=1
else
    DRYRUN=""
    # dev/pts before dev: it's a child of the /dev rbind
    for m in dev/pts dev sys proc data; do
        umount -l "$CHROOT_PATH/$m" 2>/dev/null
    done
fi

# sweep: submounts from an rbind outlive a lazy parent detach, and their
# paths are then unreachable -- so this is the only way to clear them.
# deepest first, one awk instead of a fork per PID.
targets=$(awk -v p="$CHROOT_PATH" '
    $2 == p || index($2, p "/") == 1 {
        n = gsub(/\//, "/", $2)
        print n "\t" $2
    }' /proc/mounts | sort -rn | cut -f2)

if [ -z "$targets" ]; then
    echo "clean"
    exit 0
fi

echo "$targets" | while read -r m; do
    [ -n "$m" ] || continue
    if [ -n "$DRYRUN" ]; then
        echo "would detach: $m"
    else
        umount -l "$m" 2>/dev/null || echo "FAILED $m" >&2
    fi
done

if [ -z "$DRYRUN" ]; then
    left=$(awk -v p="$CHROOT_PATH" '$2 == p || index($2, p "/") == 1' /proc/mounts)
    [ -n "$left" ] && { echo "still mounted:" >&2; echo "$left" >&2; }
fi
exit 0
```

---

## 3. Configuration

Both scripts hardcode these at the top:

| Variable | Value | Meaning |
|---|---|---|
| `CHROOT_PATH` | `/data/local/tmp/archl` | The rootfs location |
| `UID_FIRE` | `1000` | Drop to this uid inside the chroot |
| `GID_FIRE` | `1000` | Drop to this gid |

`fire` must exist in the chroot's `/etc/passwd` (field 3 = uid, field 7 = shell) and
`/etc/group`:

```
/etc/passwd: fire:x:1000:1000::/home/fire:/usr/bin/zsh
/etc/group:  fire:x:1000:
```

> **On Android, uid 1000 is literally named `system`.** So `ls -l` showing
> `system:system` on fire's files is *correct*, not a bug. Verify with
> `find /data/local/tmp/archl/home/fire -maxdepth 1 ! -user 1000 | wc -l` → expect `0`.

Required inside the rootfs:

| Binary | Package | Used for |
|---|---|---|
| `/usr/bin/setpriv` | `util-linux` | Dropping to uid 1000 (toybox `chroot` has no `--userspec`) |
| `/usr/bin/mount` | `util-linux` | `mount --make-rslave` (toybox `mount` has no propagation flags) |

Both were confirmed present (`setpriv` 133344 bytes, util-linux `mount` 2.42.4).
If either is missing the script degrades: no privilege drop (runs as root), or no
propagation fix (host breakage risk returns — see [Known caveats](#13-known-caveats)).

---

## 4. How it works

`chroot_min.sh`, in order:

1. **Parse flags.** `--with-data` is optional; everything after it is the command.
2. **`/data` must allow `exec`.** Android mounts `/data` `nosuid,nodev` with no `exec`,
   so nothing inside the chroot could execute at all. Remounted once, only if needed:
   ```sh
   mount -o remount,dev,suid,exec /data
   ```
3. **Bind `/dev` (rbind), `/sys`, `/proc`**, each skipped if already mounted.
4. **Break the peer groups** (see [§7](#7-the-fix)). This must happen *after* the binds
   and *before* anything unmounts.
5. **Mount a fresh `devpts`** at `$CHROOT/dev/pts` for the interactive terminal.
6. **Export a real Arch environment** — `PATH`, `HOME`, `USER`, `LOGNAME`, `TERM`.
7. **Resolve the login shell** from `/etc/passwd`, not `$SHELL`.
8. **`exec chroot`** → `setpriv` → login shell in `$HOME`.

`chroot_unmount.sh`:

1. Hardcoded lazy unmounts: `dev/pts`, `dev`, `sys`, `proc`, `data`.
2. A sweep of anything left in `/proc/mounts`, deepest-first.

---

## 5. Mount namespaces and propagation: the core concept

### Mount namespace

Every process has its **own view** of the mount tree. Mounting inside one does not
appear in another.

| Command | Namespace |
|---|---|
| `adb shell` | **global** (where `adbd` lives) |
| `su -c "..."` | **Magisk/APatch's** namespace |
| a process already inside the chroot | the same one you invoked from |

This is why mount state can look inconsistent depending on how you check it. Always
check from the same namespace you mounted in.

### Propagation types

A mount has a **propagation type** deciding whether mount/unmount events happening
*beneath* it get forwarded to other copies of it.

| Type | Behaviour |
|---|---|
| `shared` | Member of a **peer group**. Any mount/unmount under it is **replicated to every peer**. |
| `slave` (`rslave`) | **Receives** events from its master, but **never sends its own back up**. |
| `private` | Neither receives nor sends. |
| `unbindable` | Like private, and can never be made shared. |

Android's `init` deliberately sets up many shared trees (`/`, `/system`, `/dev`,
`/data`, `/storage`, `/vendor`, …) so runtime mounts propagate system-wide.

### Reading propagation from mountinfo

`/proc/mounts` is the old, lossy format. `/proc/self/mountinfo` has what you need:

```
36 35   0:17   /     /dev   rw,nosuid,relatime   shared:2   -   tmpfs   tmpfs   ...
│ │    │      │      │       │                   │          │ │      │
│    │    │      │      │       │                   │          │ │      └─ super options
│    │    │      │      │       │                   │          │    └─ source
│    │    │      │      │       │                   │          └─ filesystem type
│    │    │      │      │       │                   └─ separator
│    │    │      │      │       │                   └─ propagation: "shared:2" = peer in group 2
│    │    │      │      └─ mount options
│    │    │      └─ mountpoint
│    │    └─ root of the filesystem within the mount
│    └─ major:minor
└─ parent mount ID
```
(first field is this mount's own ID)

- `shared:N` → I am a peer in group N
- `master:N` → I am a slave of group N (**fixed**)

---

## 6. The `/dev/pts` incident: why `adb shell` broke

### Symptom

```
$ adb shell
error: failed to create pty master: No such device
```

### The evidence

```
crw-rw-rw- 1 root root    5,   2 /dev/ptmx      <- device node, present
drwxr-xr-x 2 root root   40 1970-04-03 /dev/pts <- link count 2 = EMPTY DIR
```

```
$ grep -E "pts|ptmx" /proc/mounts
APatch /debug_ramdisk/pts devpts rw,seclabel,relatime,mode=600,ptmxmode=000 0 0
```

Only APatch's own debug-ramdisk devpts. **`/dev/pts` was never mounted.** A healthy
devpts contains `ptmx` plus numbered slaves; link count `2` means zero
subdirectories. The `1970-04-03` timestamp is the mountpoint dir's creation time on
the underlying tmpfs — never repopulated.

### Why it took down the shell

A pseudo-terminal is a **master/slave pair**:

- **`/dev/ptmx`** — the *clone device*. Opening it allocates a new master pty. It lives
  on the `/dev` tmpfs, so it survived.
- **`/dev/pts/N`** — the *slave*, what your shell actually reads and writes. Allocated
  by the **devpts** filesystem, which must be mounted at `/dev/pts`.

`posix_openpt()` does: open `/dev/ptmx` → `grantpt()` → `unlockpt()` → `ptsname()`.
With no devpts at `/dev/pts` there is nowhere to allocate the slave, so it returns
**`ENXIO`** — strerror "No such device or address", which people shorten to "No such
device".

**Who printed it:** `adbd`, on the device, in `SetUpPty()`:

```c
fd = posix_openpt(O_RDWR | O_CLOEXEC);
if (fd < 0) {
  error("failed to create pty master: %s", strerror(errno));
```

`error()` writes to stderr, which adbd mirrors back over the adb connection — hence
the message on your terminal.

**Why only bare `adb shell`:** `adb shell <cmd>` is *non-interactive*, so adbd skips
`SetUpPty()` entirely. This matters when testing — a repair that works may still look
broken because you never exercised the pty path.

### The root cause

```
36   35 0:17 / /dev                    rw,nosuid,relatime  shared:2 - tmpfs
1258 115 0:17 / .../archl/dev           rw,nosuid,relatime  shared:2 - tmpfs
```

Both `shared:2`. **Same peer group.** The chain:

1. `mount --rbind /dev "$CHROOT_PATH/dev"` clones `/dev` **and every submount under it**.
2. Because the **source** `/dev` is shared, the clone becomes a **peer in the same
   group**. Two copies of `/dev` mirroring each other.
3. `umount -l "$CHROOT_PATH/dev/pts"` — unmount events **propagate to every peer**. The
   kernel replays "unmount `$CHROOT/dev/pts`" on the peer (the host's `/dev`), where
   that path resolves to `/dev/pts`. **Host `/dev/pts` destroyed.**

Note this happens with plain `umount` too. `-l` does not cause it — it just removes the
"busy" safety net, so it succeeds even when something still holds the mount.

---

## 7. The fix

```sh
for t in /dev /sys /proc; do
    chroot "$CHROOT_PATH" /usr/bin/mount --make-rslave "$t"
done
```

`--make-rslave` flips the chroot's mount from `shared:2` → `master:2`.

| Before | After |
|---|---|
| `shared:2` | `master:2` |

New semantics:

- Host mounts something new into `/dev` → **chroot sees it** (still inherits — useful,
  e.g. new `usb-ffs` nodes)
- Chroot unmounts something → **stops at the boundary**, host untouched

Exactly right for a bind-mounted view: one-way inheritance, no feedback loop.

Proof the same object was mutated in place:

```
before: 1258 115 0:17 / /data/local/tmp/archl/dev  ...  shared:2
after:  1258 115 0:17 / /data/local/tmp/archl/dev  ...  master:2
```

Same mount ID.

---

## 8. Implementation traps

### Trap A — toybox has no propagation flags

Android replaces coreutils with **toybox**, one stripped-down static binary. Its
`mount` does not implement propagation:

```
$ mount -o rslave /data/local/tmp/pt
mount: bad /etc/fstab: No such file or directory
```

toybox did not recognise `rslave` as a flag, treated it as a *device name*, failed,
then fell back to reading `/etc/fstab` — which Android does not have.

**Workaround:** use util-linux's `mount` from *inside* the chroot.

**Why crossing the namespace boundary works:** propagation flags live on the **mount
object in the kernel**, not in any namespace's *view* of it. Namespaces hold
references to shared mount objects. So mutating it from a chrooted process modifies the
same object the host references.

### Trap B — `--make-rslave` takes exactly ONE target

```sh
mount --make-rslave /dev /sys /proc     # -> mount: bad usage, rc=1
```

An early version of this script passed all three and wrapped it in `2>/dev/null`, so it
**failed completely silently** and a regression test caught it by finding the host's
`/dev/pts` destroyed again. Hence the explicit warning:

```sh
chroot "$CHROOT_PATH" /usr/bin/mount --make-rslave "$t" 2>/dev/null \
    || echo "warning: could not make $t a slave mount" >&2
```

**Lesson:** never suppress stderr on an operation whose failure is silent *and*
catastrophic. Suppressing output to hide noise is fine; suppressing it to hide a
nonzero exit is how an `rc=1` survives review.

### Trap C — toybox `chroot` cannot drop privileges

From AOSP `toys/other/chroot.c`:

```c
void chroot_main(void)
{
  char *binsh[] = {"/bin/sh", "-i", 0};
  if (chdir(*toys.optargs) || chroot(".")) { ... }
  if (toys.optargs[1]) xexec(toys.optargs+1);
  else xexec(binsh);
}
```

15 lines. **No `-u`, no `--userspec`.** Privileges must be dropped *after* chrooting,
hence `setpriv` inside.

### Trap D — toybox `umount` has no `-R`

```
usage: umount [-a [-t TYPE[,TYPE...]]] [-vrfD] [DIR...]
```

No recursive flag, so `chroot_unmount.sh` enumerates `/proc/mounts` itself and orders by
path depth.

---

## 9. Regression testing

Never eyeball this class of bug — write the test. Mount, unmount, assert the host is
intact:

```sh
#!/system/bin/sh
C=/data/local/tmp/archl

# clean slate, or you can't tell a fix from leftover luck
umount -l "$C/dev/pts"; umount -l "$C/dev"
umount -l "$C/sys"; umount -l "$C/proc"; umount -l "$C/data"

echo "host /dev/pts before: $(grep -c ' /dev/pts ' /proc/mounts) mount(s)"

sh /data/local/tmp/chroot_min.sh /bin/true
grep -E " $C/(dev|sys|proc) " /proc/self/mountinfo | sed 's/ - .*//'

sh /data/local/tmp/chroot_unmount.sh

grep " /dev/pts "   /proc/mounts >/dev/null && echo "PASS: host /dev/pts intact" \
                                     || echo "FAIL: host /dev/pts destroyed"
grep archl          /proc/mounts >/dev/null && echo "FAIL: leftover chroot mounts" \
                                     || echo "PASS: no leftover chroot mounts"
grep " /dev "       /proc/mounts >/dev/null && echo "PASS: host /dev intact" \
                                     || echo "FAIL: host /dev destroyed"
```

Expected:

```
===1. chroot_min.sh (mount) ===
3145 115 0:17 / /data/local/tmp/archl/dev      ...  master:2
3147 3145 0:18 / /data/local/tmp/archl/dev/pts  ...  master:3
4172 115 0:19 / /data/local/tmp/archl/sys       ...  master:5
4204 115 0:5  / /data/local/tmp/archl/proc      ...  master:4
=== 2. chroot_unmount.sh ===
clean
=== 3. HOST INTEGRITY ===
PASS: host /dev/pts intact
PASS: no leftover chroot mounts
PASS: host /dev intact
```

**Every mount must read `master:N`, never `shared:N`.** If you see `shared:`, the
propagation fix silently failed and the host is exposed.

### Testing `adb shell` properly

`adb shell 'cmd'` never allocates a pty, so it cannot validate this class of fix. Drive
bare `adb shell` through a real pty on the host:

```sh
python3 - <<'EOF'
import os, pty, select, time
pid, fd = pty.fork()
if pid == 0:
    os.execvp("adb", ["adb", "shell"])
out = b""
def pump(t=2.0):
    global out
    end = time.time() + t
    while time.time() < end:
        r,_,_ = select.select([fd],[],[],0.2)
        if r:
            try:
                d = os.read(fd, 1024)
                if not d: return
                out += d
            except OSError: return
pump(2.5)
os.write(fd, b"tty\n");    pump(1.5)
os.write(fd, b"exit\n");  pump(1.0)
os.waitpid(pid, 0)
print(out.decode(errors="replace").replace("\r",""))
EOF
```

Healthy output:

```
berlin:/ # tty
/dev/pts/0
berlin:/ # exit
```

---

## 10. Every bug hit along the way

### `ls: command not found`

`chroot` passes the **environment** straight through. Android's shell exports
`PATH=/system/bin`. Inside the chroot that directory does not exist, so `PATH` resolved
to nothing.

A shell still started because the script passed an **absolute path** (`/bin/bash`), which
the kernel resolves against the new root. But `ls` is a bare word, so it went through
`PATH` and died.

**Fix:** export a real Arch `PATH` before `exec`.

### Prompt showed `root` instead of `fire`

toybox `chroot` has no `--userspec` ([Trap C](#trap-c--toybox-chroot-cannot-drop-privileges)).
Dropped to uid 1000 with `setpriv` inside the chroot instead.

`ls -l` showing `system:system` for fire's files is *correct* — Android names uid 1000
`system`. See [§3](#3-configuration).

### `echo $SHELL` did not match the running shell

`$SHELL` is an **environment variable** describing your *login* shell. It does **not**
report the running process. An early version set `SHELL=/usr/bin/zsh` but ran
`/bin/bash`, so you got a bash prompt (`$`) and bash never read `.zshrc`.

**Fix:** read field 7 of `/etc/passwd` for the target uid — the authoritative answer:

```sh
awk -F: -v u="$UID_FIRE" '$3==u { print $7; exit }' "$CHROOT_PATH/etc/passwd"
```

### Chroot mirrored inside itself (41 mounts instead of 5)

```sh
mount --rbind /data "$CHROOT/data"     # $CHROOT is INSIDE /data
```

`--rbind` is recursive, so it cloned **every submount under `/data`** — including the
chroot's own `dev`, `proc`, `sys` mounts:

```
/data/local/tmp/archl/data/local/tmp/archl/dev/pts
/data/local/tmp/archl/data/local/tmp/archl/sys/fs/cgroup
...41 entries
```

**Fix:** plain `--bind` for `/data` (clones the tree, not the nested mounts), and made
it opt-in via `--with-data` since a chroot of a directory *inside* `/data` will always
show that directory in its listing.

### `ENOENT` cascade during unmount

Lazy-unmounting a parent that still has children **orphans** them: they remain in
`/proc/mounts`, but their paths no longer resolve, so every subsequent `umount` returns
`ENOENT`. This produced a wall of misleading `FAILED` lines even though the cleanup had
actually succeeded.

**Fix:** unmount **deepest-first**, ordered by path depth (slash count).

### `umount` failed on `dev/pts` — not a real failure

```
umount: /data/local/tmp/archl/dev/pts: No such file or directory
```

The directory had already gone away as the tree unwound. The error text was misleading;
the end state was correct. **Lesson:** when a teardown script reports failures, verify
final state with `grep archl /proc/mounts` before assuming it broke something.

---

## 11. Performance notes

| Operation | Time |
|---|---|
| `chroot_min.sh` (mount + enter) | ~0.45s |
| `chroot_unmount.sh` | ~0.17s |
| per-PID `readlink` loop (**removed**) | **14.50s** |
| mount enumeration (`awk`) | 0.05s |

### The 15-second unmount

An early unmount script began with a busy check:

```sh
for p in /proc/[0-9]*; do
    readlink "$p/root" 2>/dev/null
done
```

One **fork + exec per process**. This device had **716 processes** → 14.5 seconds.

The `umount` calls were never the problem — the *warning* was. And since `umount -l`
cannot be blocked anyway, there was nothing to guard. The loop was removed entirely.

If you ever need such a check cheaply, batch it into **one** process rather than one per
PID:

```sh
readlink /proc/[0-9]*/root 2>/dev/null | grep -c '^/data/local/tmp/archl$'
```

(`toybox date +%s%N` does **not** work — it returns garbage and produces negative deltas.
Use `time`, or `date +%s%N` from a real coreutils host.)

---

## 12. Troubleshooting

### `adb shell` → "failed to create pty master: No such device"

```sh
grep ' /dev/pts ' /proc/mounts || echo "DEAD"
ls /dev/pts                       # expect: ptmx plus numbered slaves
```

Repair:

```sh
su -c 'mount -t devpts devpts /dev/pts -o mode=666,gid=5'
```

### Confirm a healthy devpts

```sh
ls -l /dev/ptmx    # crw-rw-rw- 5, 2  (present)
ls /dev/pts       # must contain ptmx + numbered slaves, NOT be empty
grep ' /dev/pts ' /proc/mounts   # must exist
```

A link count of `2` on `/dev/pts` means it is an empty directory, not a mount.

### Check chroot mount propagation

```sh
grep -E " $CHROOT/(dev|sys|proc) " /proc/self/mountinfo
```

Every one must show `master:N`. Any `shared:N` means the fix silently failed.

### "warning: could not make ... a slave mount"

`/usr/bin/mount` (util-linux) is missing or failing inside the rootfs:

```sh
su -c 'chroot /data/local/tmp/archl /usr/bin/mount --make-rslave /dev'
```

Run it **without** extra arguments — several targets gives `bad usage`.

### Shell starts but zsh config is ignored

```sh
echo $0     # must be /usr/bin/zsh, NOT bash
grep '^fire:' /data/local/tmp/archl/etc/passwd
```

If `$0` is wrong, `/etc/passwd` field 7 for uid 1000 is wrong. `~/.config/zshrc` is a
symlink into `~/Water/crap/dotfiles/chroot/zshrc/`.

### `ls` inside works but env looks wrong

```sh
echo $PATH $HOME $USER
```

If `PATH=/system/bin`, the export block did not run.

### Useful reference

```sh
# what is this mount, and is it shared?
grep ' /dev ' /proc/self/mountinfo        # shared:N = peer, master:N = slave

# all mounts under the chroot, deepest first
awk -v p=/data/local/tmp/archl '$2==p||index($2,p"/")==1{n=gsub(/\//,"/",$2);print n"\t"$2}' \
    /proc/mounts | sort -rn | cut -f2

# break a peer relationship (ONE target at a time)
mount --make-rslave /some/path

# repair a dead /dev/pts
mount -t devpts devpts /dev/pts -o mode=666,gid=5
```

---

## 13. Known caveats

### `chroot_sshd.sh` still has the `/dev/pts` bug

The original boot script still does:

```sh
mount --rbind /dev "$CHROOT_PATH/dev"
```

with **no `make-rslave`**. If you run it from `/data/adb/service.d/`, the hazard
returns and the host's `/dev/pts` can be torn off again. **Apply the same fix before
using it**, or retire it in favour of `chroot_min.sh`.

Its other heavy parts (FBE wait loop, `bindfs` for `/data`, Termux X11 socket bridge,
`/sdcard` binds, sshd daemon) are all deliberately omitted here.

### `/dev/pts` is not persistent across reboots

The repair is a runtime mount. If the shell breaks after a restart, that is why —
re-run the repair line from [§12](#12-troubleshooting).

### The repair used `mode=666`

On production Android `adbd` runs as the `shell` user, not root, so `mode=600`
root-owned (what APatch uses for its own `/debug_ramdisk/pts`) would still fail to hand
out ptys. Your `/dev/ptmx` is already `666`, so this is not materially weaker. To
tighten:

```sh
su -c 'umount /dev/pts; mount -t devpts devpts /dev/pts -o mode=620,gid=5'
```

**Verify `adb shell` still works afterwards.**

### Not mounted

`/vendor`, `/product`, `/odm`, `/apex`, `/system`, `/linkerconfig`, `/sdcard` are
deliberately absent. A binary with a missing linker will fail — bind the one partition it
needs. That is usually the only reason the original mounted them.

### `--with-data` is discouraged

`$CHROOT` lives *inside* `/data`, so binding `/data` in makes the chroot appear within
itself. It works, but is confusing to debug. Left available for compatibility.

---

## 14. Appendix: running this rootfs on an x86_64 PC

Host: Arch Linux x86_64. Relevant facts already established:

- `qemu-system-aarch64` **is** installed — but it is the wrong tool (full-system VM)
- `qemu-user` is **not** installed; `qemu-user-static` 11.1.2 is in `extra`
- `binfmt_misc` is mounted and `enabled`

### There is no fast way to do this, and the reason is hard

**KVM requires the guest architecture to match the host.** KVM is a hardware
virtualization API for running guest code natively; it exists only for same-arch
(x86-on-x86, ARM-on-ARM). Running ARM64 on an x86_64 host has **no hardware
acceleration available at all**, so every emulation option runs on QEMU's TCG — a
software JIT that rewrites ARM instructions into x86 code. That is a hard ceiling, not a
configuration mistake.

### Ranked by actual speed

| # | Method | Speed | Notes |
|---|---|---|---|
| 1 | **Native x86_64 Arch** | **100%** | Not emulation. Rebuild your setup for x86_64. |
| 2 | **The phone itself** | **100%** | Real ARM silicon, already has this rootfs. |
| 3 | **`qemu-user` + binfmt_misc** | **~5-20x slower** | Best *emulation* option. |
| 4 | **`qemu-system` TCG VM** | ~10-30x slower | Worse — see below. |
| 5 | **`proot -q`** | ~20-50x slower | Adds path translation on top. |

**Why #4 loses to #3:** a full-system VM must emulate an entire guest kernel under TCG,
so every syscall costs a VM exit *plus* guest-kernel emulation. `qemu-user` is a thin
syscall-translation shim with no guest kernel. Counterintuitive given the name, but
user-mode is faster for chroot.

### Steps

```sh
# 1. install user-mode emulation (you only have qemu-system-*)
sudo pacman -S qemu-user-static

# 2. register the binfmt handlers (binfmt_misc is already mounted)
sudo systemd-binfmt
ls /proc/sys/fs/binfmt_misc/          # expect qemu-aarch64

# 3. pull the rootfs -- MUST unmount first, or tar reads through the binds
adb shell su -c 'sh /data/local/tmp/chroot_unmount.sh'
adb exec-out su -c 'tar -C /data/local/tmp -cf - archl' | tar -C ~ -xf -
adb exec-out su -c 'chown -R $(id -u):$(id -g) ~/archl'

# 4. mount pseudo-filesystems and enter
sudo mkdir -p ~/archl/{dev,proc,sys}
sudo mount -t proc proc ~/archl/proc
sudo mount --rbind /dev ~/archl/dev
sudo mount --rbind /sys ~/archl/sys
sudo cp /etc/resolv.conf ~/archl/etc/resolv.conf   # DNS won't work otherwise
sudo chroot ~/archl /bin/bash
```

### Caveats

- **Expect 5-20x slowdown.** Syscall translation, not JIT magic. Fine for config edits
  and package management, painful for builds.
- **`mount` of ARM-specific filesystems will not work** — the host kernel has no ARM disk
  drivers. Bind mounts, `tmpfs`, and `proc` are fine, since those are host-native.
- **No systemd.** It wants to be PID 1 and will fight the emulation. Use shells and `sshd`.
- **Networking just works** — user-mode shares the host stack directly, no slirp needed
  (unlike `qemu-system`).
- **NSS lookups work**, so `su`, `sshd`, `getent` resolve normally.

### Rootless alternative

```sh
sudo pacman -S proot
proot -q qemu-aarch64 -r ~/archl -b /dev -b /proc -b /sys -w / /bin/bash
```

Slower again, and no `mount` at all, but nothing touches the host and there is no
bind-mount cleanup to do.

### For actually building things

Cross-compiling on x86_64 is faster than emulating ARM **and** gives correct results —
you produce ARM binaries without ever executing ARM code. `aarch64-linux-gnu-gcc` with
an `aarch64` sysroot, optionally with `distcc`, is typically the right answer for build
workloads and sidesteps emulation entirely.

### Why not use the already-installed `qemu-system-aarch64`

It is the *better* tool if you want a faithful, fast Arch ARM environment: build a disk
image (`truncate` + `mkfs.ext4` + copy rootfs), get a kernel and initramfs
(`linux-aarch64`), and boot with `-M virt -cpu cortex-a72 -nographic`. More setup, but
real performance and a real kernel. Worth it if you plan to compile there rather than
poke around.