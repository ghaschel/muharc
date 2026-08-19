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

# UHARC discovers directories by searching for *.*. Windows treats that
# wildcard as every entry, including dotless directory names; Wibo must do
# the same or UHARC's -r+ switch never descends into them.
mkdir -p "$stage/recursive/input/00008/deeper" "$stage/recursive/input/00031"
printf '%s\n' 'root file' > "$stage/recursive/input/LICENSE.txt"
printf '%s\n' 'first nested file' > "$stage/recursive/input/00008/first.npz"
printf '%s\n' 'deeper nested file' > "$stage/recursive/input/00008/deeper/second.npz"
printf '%s\n' 'second directory file' > "$stage/recursive/input/00031/third.npz"
(
  cd "$stage/recursive"
  run_wibo a -r+ recursive.uha 'input/*.*'
  run_wibo l recursive.uha
  run_wibo t recursive.uha
  mkdir -p output/input
  (
    cd output
    run_wibo x ../recursive.uha
  )
)

for recursive_fixture in "$stage"/recursive/input/LICENSE.txt "$stage"/recursive/input/00008/first.npz \
  "$stage"/recursive/input/00008/deeper/second.npz "$stage"/recursive/input/00031/third.npz; do
  relative_path=${recursive_fixture#"$stage/recursive/"}
  cmp "$recursive_fixture" "$stage/recursive/output/$relative_path" || {
    printf 'FAIL: recursive extraction changed or omitted: %s\n' "$relative_path" >&2
    exit 1
  }
done

printf '%s\n' 'PASS: UHARC Unicode archive/list/test/extract round trip'
