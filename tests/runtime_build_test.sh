#!/bin/sh

set -eu

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
stage=$(mktemp -d "${TMPDIR:-/tmp}/muharc-runtime-build-test.XXXXXX")
trap 'rm -rf "$stage"' EXIT HUP INT TERM

[ -x "$project_root/scripts/build-wibo.sh" ] || {
  printf '%s\n' 'FAIL: scripts/build-wibo.sh is not executable' >&2
  exit 1
}

"$project_root/scripts/build-wibo.sh" --output "$stage/wibo"

[ -x "$stage/wibo" ] || {
  printf '%s\n' 'FAIL: build did not produce an executable Wibo runtime' >&2
  exit 1
}

file "$stage/wibo" | grep -q 'x86_64' || {
  printf '%s\n' 'FAIL: Wibo runtime is not a macOS x86_64 executable' >&2
  exit 1
}

printf '%s\n' 'PASS: clean Wibo clone, patch, and x86_64 build'
