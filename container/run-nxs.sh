#!/bin/sh
# Build the Blackfin GUI board and run the complete NXS stack in this container.
set -eu

mkdir -p /tmp/.cache/fontconfig /work/build /work/bin
CDJ_BUILD_DIR=/work/build CDJ_BIN_DIR=/work/bin \
    sh /src/scripts/build-cdj-gui-run.sh
export CDJ_GUI_RUN=/work/bin/cdj-gui-run
export CDJ_QEMU=/out/qemu-system-sh4-run
exec /opt/uv-python/bin/python -m tools.cdj_main.nxs_vm "$@"
