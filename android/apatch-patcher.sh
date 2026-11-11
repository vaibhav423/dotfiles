#!/usr/bin/env bash
#
# apatch-patcher.sh - patch an Android boot image with KernelPatch (APatch)
#
# Workflow:
#   kptools unpack boot.img      -> kernel, ramdisk, ...
#   mv kernel kernel-orig
#   kptools -p --image kernel-orig --skey KEY --kpimg kpimg-android --out kernel
#   kptools repack boot.img      -> new-boot.img
#
# kpimg-android is downloaded from the latest KernelPatch release unless
# a local copy is supplied with -k/--kpimg.
#
# Requires: kptools, curl (only for the initial download)

set -euo pipefail

PROG=${0##*/}
KPIMG_URL=${KPIMG_URL:-https://github.com/bmax121/KernelPatch/releases/latest/download/kpimg-android}
DEFAULT_SKEY=vaibhav1
CACHE_DIR=${XDG_CACHE_HOME:-$HOME/.cache}/apatch-patcher
CACHED_KPIMG=$CACHE_DIR/kpimg-android

OUT=""
SKEY=${APATCH_SKEY:-$DEFAULT_SKEY}
KPIMG=""
KPATCH=""
REFRESH=0
KEEP_WORK=0
BOOT=""

WORKDIR=""
DL_TMP=""
cleanup() {
    [[ -n $DL_TMP ]] && rm -f -- "$DL_TMP"
    if [[ -n $WORKDIR && -d $WORKDIR ]]; then
        if (( KEEP_WORK )); then
            printf '\n[*] Work directory kept: %s\n' "$WORKDIR"
        else
            rm -rf -- "$WORKDIR"
        fi
    fi
}
trap cleanup EXIT

die()  { printf '[!] %s\n' "$*" >&2; exit 1; }
log()  { printf '[*] %s\n' "$*"; }
ok()   { printf '[+] %s\n' "$*"; }
step() { printf '\n==> %s\n' "$*"; }

usage() {
    cat <<EOF
Usage: $PROG [options] <boot.img>

Patch an Android boot image with KernelPatch (APatch) and write a patched image.

Options:
  -o, --out PATH       Output image (default: <boot>.patched.img)
  -s, --skey KEY       Superkey stored in the image (default: $DEFAULT_SKEY)
  -k, --kpimg PATH     Use this kpimg instead of downloading kpimg-android
      --refresh-kpimg  Re-download the latest kpimg-android
      --kpatch PATH    Embed a kpatch binary into the image (kptools -K)
  -w, --keep-work      Keep the temporary unpack/patch directory
  -h, --help           Show this help

Environment:
  APATCH_SKEY          Default superkey (overridden by -s)
  KPIMG_URL            Alternative kpimg download URL

Examples:
  $PROG boot.img
  $PROG -s 'my secret key' -o boot-patched.img boot.img
  $PROG -k ./kpimg-android init_boot.img

Notes:
  * Do NOT flash over the running slot blindly; keep a copy of the stock image.
  * init_boot.img / vendor_boot.img usually contain no kernel and will fail.
  * Re-running on an already patched image updates the existing patch.
EOF
}

need_arg() { [[ $# -ge 2 && -n $2 ]] || die "option $1 requires an argument"; }

while [[ $# -gt 0 ]]; do
    case $1 in
        -o|--out)          need_arg "$@"; OUT=$2; shift 2 ;;
        -s|--skey)         need_arg "$@"; SKEY=$2; shift 2 ;;
        -k|--kpimg)        need_arg "$@"; KPIMG=$2; shift 2 ;;
        --kpatch)          need_arg "$@"; KPATCH=$2; shift 2 ;;
        --refresh-kpimg)   REFRESH=1; shift ;;
        -w|--keep-work)    KEEP_WORK=1; shift ;;
        -h|--help)         usage; exit 0 ;;
        --)                shift; break ;;
        -*)                die "unknown option: $1 (see --help)" ;;
        *)
            [[ -z $BOOT ]] || die "only one boot image may be given (got '$BOOT' and '$1')"
            BOOT=$1; shift ;;
    esac
done
[[ $# -eq 0 ]] || { [[ -z $BOOT ]] || die "unexpected argument: $1"; BOOT=$1; }

[[ -n $BOOT ]] || { usage >&2; exit 1; }
[[ -f $BOOT ]] || die "boot image not found: $BOOT"
[[ -r $BOOT ]] || die "boot image is not readable: $BOOT"

# ---------------------------------------------------------------- dependencies
command -v kptools >/dev/null 2>&1 || die "kptools not found in PATH (install it from the KernelPatch releases)"
command -v curl    >/dev/null 2>&1 || [[ -n $KPIMG ]] || die "curl not found and no -k/--kpimg given"

log "kptools: $(kptools -v 2>/dev/null | head -n1 || echo unknown)"

# --------------------------------------------------------------------- output
if [[ -z $OUT ]]; then
    case $BOOT in
        *.img) OUT=${BOOT%.img}.patched.img ;;
        *)     OUT=$BOOT.patched.img ;;
    esac
fi
mkdir -p -- "$(dirname -- "$OUT")" || die "cannot create output directory for: $OUT"

# Never overwrite the input image.
boot_real=$(realpath -m -- "$BOOT")
out_real=$(realpath -m -- "$OUT")
[[ $boot_real != "$out_real" ]] || die "output path is the same as the input image: $OUT"

# ----------------------------------------------------------------------- kpimg
get_kpimg() {
    if [[ -n $KPIMG ]]; then
        [[ -f $KPIMG ]] || die "kpimg not found: $KPIMG"
        [[ -s $KPIMG ]] || die "kpimg is empty: $KPIMG"
        ok "Using local kpimg: $KPIMG"
        return
    fi

    if (( ! REFRESH )) && [[ -s $CACHED_KPIMG ]]; then
        ok "Using cached kpimg: $CACHED_KPIMG"
        KPIMG=$CACHED_KPIMG
        return
    fi

    mkdir -p -- "$CACHE_DIR"
    local tmp=$CACHE_DIR/.kpimg.$$
    DL_TMP=$tmp
    log "Downloading kpimg-android (latest KernelPatch release)"
    log "  $KPIMG_URL"
    if ! curl -fL --retry 3 --connect-timeout 20 -o "$tmp" "$KPIMG_URL"; then
        rm -f -- "$tmp"
        die "failed to download kpimg-android (use -k to supply one offline)"
    fi
    [[ -s $tmp ]] || { rm -f -- "$tmp"; die "downloaded kpimg-android is empty"; }
    mv -f -- "$tmp" "$CACHED_KPIMG"
    DL_TMP=""
    ok "Saved kpimg to: $CACHED_KPIMG ($(wc -c <"$CACHED_KPIMG") bytes)"
    KPIMG=$CACHED_KPIMG
}

step "Checking kpimg"
get_kpimg
kptools -l -k "$KPIMG" >/dev/null 2>&1 || log "warning: kptools could not read kpimg metadata; continuing"

# ------------------------------------------------------------------ work area
WORKDIR=$(mktemp -d "${TMPDIR:-/tmp}/apatch-patcher.XXXXXX") || die "cannot create work directory"
cp -- "$BOOT" "$WORKDIR/boot.img" || die "cannot copy boot image to work directory"
ok "Working in: $WORKDIR"

pushd "$WORKDIR" >/dev/null

step "Unpacking boot image"
if ! kptools unpack boot.img; then
    die "kptools unpack failed (is this a supported boot image?)"
fi
[[ -f kernel ]] || die "unpack did not produce a 'kernel' file (init_boot/vendor_boot images have no kernel)"

mv -- kernel kernel-orig || die "cannot rename kernel to kernel-orig"
ok "Original kernel saved as kernel-orig"

step "Patching kernel"
patch_args=(-p --image kernel-orig --skey "$SKEY" --kpimg "$KPIMG" --out kernel)
[[ -n $KPATCH ]] && patch_args+=(--kpatch "$KPATCH")
if ! kptools "${patch_args[@]}"; then
    die "kptools patch failed"
fi
[[ -s kernel ]] || die "patch did not produce a kernel image"
ok "Kernel patched"

step "Repacking boot image"
if ! kptools repack boot.img; then
    die "kptools repack failed"
fi
[[ -f new-boot.img ]] || die "repack did not produce new-boot.img"

step "Writing output"
mv -f -- new-boot.img "$out_real" || die "cannot write output image: $OUT"
popd >/dev/null

if command -v sha256sum >/dev/null 2>&1; then
    ok "Patched image: $OUT"
    ok "SHA256: $(sha256sum -- "$out_real" | awk '{print $1}')"
else
    ok "Patched image: $OUT"
fi

if [[ -n $KPATCH ]]; then
    ok "Embedded kpatch: $KPATCH"
fi
ok "Superkey: $SKEY"
printf '\n[i] Keep the stock image safe. Flash with fastboot, e.g.:\n'
printf '      fastboot flash boot %q\n' "$OUT"
