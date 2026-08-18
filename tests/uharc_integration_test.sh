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
stage=$(mktemp -d "${TMPDIR:-/tmp}/muharc-uharc-test.XXXXXX")
trap 'rm -rf "$stage"' EXIT HUP INT TERM

run_wibo() {
  if [ "$(uname -m)" = arm64 ]; then
    /usr/bin/arch -x86_64 "$wibo" "$uharc_exe" "$@"
  else
    "$wibo" "$uharc_exe" "$@"
  fi
}

[ -x "$wibo" ] && [ -f "$uharc_exe" ] || {
  printf '%s\n' 'FAIL: runtime is missing; run make runtime first' >&2
  exit 1
}

cp -R "$project_root/tests/fixtures/unicode" "$stage/input"
(
  cd "$stage"
  run_wibo a unicode.uha input/*
  run_wibo l unicode.uha
  run_wibo t unicode.uha
  mkdir -p output/input
  (
    cd output
    run_wibo x ../unicode.uha
  )
)

for fixture in "$project_root"/tests/fixtures/unicode/*; do
  name=$(basename "$fixture")
  cmp "$fixture" "$stage/output/input/$name" || {
    printf 'FAIL: extracted fixture changed: %s\n' "$name" >&2
    exit 1
  }
done

printf '%s\n' 'PASS: UHARC Unicode archive/list/test/extract round trip'
