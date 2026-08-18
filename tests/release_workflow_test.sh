#!/bin/sh

set -eu

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
workflow=$project_root/.github/workflows/release.yml

grep -Fq 'sudo softwareupdate --install-rosetta --agree-to-license' "$workflow" || {
  printf '%s\n' 'FAIL: the ARM smoke job must install Rosetta 2' >&2
  exit 1
}

grep -Fq '/usr/bin/arch -x86_64 "$task_dir/libexec/muharc/wibo" --version' "$workflow" || {
  printf '%s\n' 'FAIL: the ARM smoke job must execute the packaged x86_64 runtime' >&2
  exit 1
}

printf '%s\n' 'PASS: release workflow installs and exercises Rosetta 2'
