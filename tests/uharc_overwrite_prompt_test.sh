#!/bin/sh

set -eu

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
runtime_dir=${MUHARC_RUNTIME_DIR:-$project_root/build/runtime}
runtime_dir=$(CDPATH= cd -- "$runtime_dir" && pwd -P) || {
  printf '%s\n' 'FAIL: runtime is missing; run make runtime first' >&2
  exit 1
}
wibo=$runtime_dir/wibo
uharc_exe=$runtime_dir/uharc.exe

[ -x "$wibo" ] && [ -f "$uharc_exe" ] || {
  printf '%s\n' 'FAIL: runtime is missing; run make runtime first' >&2
  exit 1
}

python3 - "$wibo" "$uharc_exe" <<'PY'
import errno
import os
import platform
import pty
import select
import subprocess
import sys
import tempfile
import termios
import time
from pathlib import Path


wibo = Path(sys.argv[1])
uharc_exe = Path(sys.argv[2])


def command(*args):
    invocation = [str(wibo), str(uharc_exe), *args]
    if platform.machine() == "arm64":
        return ["/usr/bin/arch", "-x86_64", *invocation]
    return invocation


def run(stage, *args):
    completed = subprocess.run(
        command(*args), cwd=stage, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT
    )
    if completed.returncode != 0:
        raise AssertionError(
            f"UHARC {' '.join(args)} failed with {completed.returncode}:\n{completed.stdout}"
        )


def drain(master, output):
    while True:
        readable, _, _ = select.select([master], [], [], 0)
        if not readable:
            return output
        try:
            chunk = os.read(master, 4096)
        except OSError as error:
            if error.errno == errno.EIO:
                return output
            raise
        if not chunk:
            return output
        output += chunk


def confirm_overwrite_with_bare_y(stage):
    master, slave = pty.openpty()
    original_terminal_attributes = termios.tcgetattr(slave)
    process = subprocess.Popen(
        command("a", "overwrite.uha", "input.txt"),
        cwd=stage,
        stdin=slave,
        stdout=slave,
        stderr=slave,
        close_fds=True,
    )
    os.close(slave)
    output = b""
    try:
        # The archive already exists, so UHARC must wait for the confirmation
        # path before it can rewrite it. Send only Y, deliberately omitting a
        # newline; UHARC uses console input events for this prompt.
        time.sleep(0.25)
        if process.poll() is not None:
            output = drain(master, output)
            raise AssertionError(
                f"UHARC exited before its overwrite prompt ({process.returncode}):\n"
                f"{output.decode(errors='replace')}"
            )
        os.write(master, b"Y")

        deadline = time.monotonic() + 8
        while process.poll() is None and time.monotonic() < deadline:
            readable, _, _ = select.select([master], [], [], 0.1)
            if readable:
                output = drain(master, output)

        output = drain(master, output)
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
            raise AssertionError(
                "UHARC did not accept bare Y at the overwrite prompt:\n"
                f"{output.decode(errors='replace')}"
            )
        if process.returncode != 0:
            raise AssertionError(
                f"UHARC overwrite exited with {process.returncode}:\n"
                f"{output.decode(errors='replace')}"
            )
        restored_terminal_attributes = termios.tcgetattr(master)
        if restored_terminal_attributes[3] != original_terminal_attributes[3]:
            raise AssertionError("UHARC left the terminal's local-mode flags changed after confirmation")
    finally:
        os.close(master)


with tempfile.TemporaryDirectory(prefix="muharc-overwrite-prompt-") as temporary_directory:
    stage = Path(temporary_directory)
    input_file = stage / "input.txt"
    input_file.write_text("original archive content\n", encoding="utf-8")
    run(stage, "a", "-y+", "overwrite.uha", "input.txt")

    input_file.write_text("replacement archive content\n", encoding="utf-8")
    confirm_overwrite_with_bare_y(stage)
    run(stage, "t", "overwrite.uha")

    output_directory = stage / "extract"
    output_directory.mkdir()
    run(output_directory, "x", "../overwrite.uha")
    extracted = (output_directory / "input.txt").read_text(encoding="utf-8")
    if extracted != "replacement archive content\n":
        raise AssertionError(f"archive retained old content after confirmation: {extracted!r}")
PY

printf '%s\n' 'PASS: UHARC accepts bare Y at the overwrite prompt'
