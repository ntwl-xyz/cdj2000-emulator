#!/bin/sh
# Build QEMU using this repository's patching/configuration script and export
# the executable plus non-glibc runtime libraries into the mounted /out dir.
set -eu

REPO=/src
QEMU_SRC=/work/qemu-src
QEMU_REF=${QEMU_REF:-v11.0.0}
OUT=/out

if [ ! -f "$REPO/scripts/build-qemu-sh4.sh" ]; then
    echo "mount the cdj2000-emulator repository at /src" >&2
    exit 2
fi
mkdir -p "$QEMU_SRC" "$OUT/lib"
if [ ! -f "$QEMU_SRC/hw/sh4/meson.build" ]; then
    rmdir "$QEMU_SRC" 2>/dev/null || true
    git clone --depth 1 --branch "$QEMU_REF" https://gitlab.com/qemu-project/qemu.git "$QEMU_SRC"
elif [ "$(git -C "$QEMU_SRC" describe --tags --exact-match 2>/dev/null || true)" != "$QEMU_REF" ]; then
    git -C "$QEMU_SRC" fetch --depth 1 origin "refs/tags/$QEMU_REF:refs/tags/$QEMU_REF"
    git -C "$QEMU_SRC" checkout --force --detach "$QEMU_REF"
fi

sh "$REPO/scripts/build-qemu-sh4.sh" "$QEMU_SRC"
BIN="$QEMU_SRC/build/qemu-system-sh4"
[ -x "$BIN" ] || { echo "QEMU build did not produce $BIN" >&2; exit 1; }

# Match Debian's host glibc at runtime and bundle the other shared libraries
# QEMU needs, so the exported binary also works on a minimal Debian host.
cp "$BIN" "$OUT/qemu-system-sh4.tmp"
chmod 0755 "$OUT/qemu-system-sh4.tmp"
mv -f "$OUT/qemu-system-sh4.tmp" "$OUT/qemu-system-sh4"
ldd "$OUT/qemu-system-sh4" | awk '
    /=> \/.*\.so/ { print $3 }
    /^\// && /\.so/ { print $1 }
' | while IFS= read -r library; do
    [ -f "$library" ] || continue
    case "$library" in
        /lib/*/libc.so.*|/lib/*/libm.so.*|/lib/*/libpthread.so.*|/lib/*/librt.so.*|/lib/*/ld-linux*.so.*|/usr/lib/*/libc.so.*|/usr/lib/*/libm.so.*|/usr/lib/*/libpthread.so.*|/usr/lib/*/librt.so.*|/usr/lib/*/ld-linux*.so.*) continue ;;
    esac
    cp -L "$library" "$OUT/lib/"
done
cat > "$OUT/qemu-system-sh4-run" <<'WRAPPER'
#!/bin/sh
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
export LD_LIBRARY_PATH="$HERE/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
exec "$HERE/qemu-system-sh4" "$@"
WRAPPER
chmod 0755 "$OUT/qemu-system-sh4-run"

"$OUT/qemu-system-sh4-run" -M help >/dev/null
echo "exported QEMU to $OUT/qemu-system-sh4"
echo "set CDJ_QEMU=$OUT/qemu-system-sh4-run when launching the emulator"
