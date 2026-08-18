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

grep -Fq 'brew tap ghaschel/tap "$task_tap"' "$workflow" || {
  printf '%s\n' 'FAIL: the publish job must tap its local formula checkout' >&2
  exit 1
}

grep -Fq 'brew audit --strict ghaschel/tap/muharc' "$workflow" || {
  printf '%s\n' 'FAIL: the publish job must audit the tap-qualified formula name' >&2
  exit 1
}

grep -Fq 'HOMEBREW_NO_INSTALL_FROM_API=1 brew install ghaschel/tap/muharc' "$workflow" || {
  printf '%s\n' 'FAIL: the publish job must install the prepared local tap checkout' >&2
  exit 1
}

printf '%s\n' 'PASS: release workflow installs and exercises Rosetta 2'
