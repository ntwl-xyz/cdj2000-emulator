#!/usr/bin/env python3
"""Run the exported SH-4 QEMU in the compose qemu-runtime service."""
from __future__ import annotations
import os
from pathlib import Path
import subprocess
import sys

REPO = Path(__file__).resolve().parents[1]

def main() -> int:
    qemu_args = sys.argv[1:]
    run_log = None
    media: list[Path] = []
    index = 0
    while index < len(qemu_args):
        arg = qemu_args[index]
        if arg == "-D" and index + 1 < len(qemu_args):
            run_log = Path(qemu_args[index + 1]).resolve()
            index += 2
            continue
        if arg in {"-bios", "-kernel", "-dtb", "-initrd"} and index + 1 < len(qemu_args):
            media.append(Path(qemu_args[index + 1]).resolve(strict=True))
            index += 2
            continue
        if arg == "-drive" and index + 1 < len(qemu_args):
            spec = qemu_args[index + 1]
            if "file=" in spec:
                path = spec.split("file=", 1)[1].replace(",,", ",")
                media.append(Path(path).resolve(strict=True))
            index += 2
            continue
        index += 1
    if run_log is None:
        print("QEMU args must include -D RUN-DIR/main.log so the run files can be mounted", file=sys.stderr)
        return 2
    run_dir = run_log.parent
    if not run_dir.is_dir():
        print(f"QEMU run directory does not exist: {run_dir}", file=sys.stderr)
        return 2
    mounts = [run_dir]
    for path in media:
        if path not in mounts:
            mounts.append(path)
    command = [
        "docker", "compose", "-f", str(REPO / "compose.qemu.yaml"),
        "run", "--rm", "--no-deps", "-T",
    ]
    for path in mounts:
        volume = f"{path}:{path}" + (":ro" if path.is_file() else "")
        command.extend(("--volume", volume))
    # QEMU's board model reads CDJ_* settings from its process environment.
    # Forward the launcher's sanitized settings through Compose so input, panel
    # scheduling, tracing and other run-local behavior also work in Docker.
    for name, value in os.environ.items():
        if name.startswith("CDJ_"):
            command.extend(("--env", f"{name}={value}"))
    command.append("qemu-runtime")
    command.extend(qemu_args)
    return subprocess.run(command, cwd=REPO, check=False).returncode

if __name__ == "__main__":
    raise SystemExit(main())
