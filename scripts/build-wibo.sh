#!/bin/sh

set -eu

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
output=

usage() {
  printf '%s\n' 'Usage: scripts/build-wibo.sh --output PATH'
}

while [ "$#" -gt 0 ]; do
  case $1 in
    --output)
      [ "$#" -ge 2 ] || { usage >&2; exit 64; }
      output=$2
      shift 2
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 64
      ;;
  esac
done

[ -n "$output" ] || { usage >&2; exit 64; }

case $output in
  /*) ;;
  *) output=$PWD/$output ;;
esac

for tool in git cmake ninja python3; do
  command -v "$tool" >/dev/null 2>&1 || {
    printf 'build-wibo: missing required tool: %s\n' "$tool" >&2
    exit 69
  }
done

. "$project_root/sources/wibo.lock"
scratch=$(mktemp -d "${TMPDIR:-/tmp}/muharc-wibo.XXXXXX")
trap 'rm -rf "$scratch"' EXIT HUP INT TERM

git clone "$WIBO_REPOSITORY" "$scratch/wibo"
git -C "$scratch/wibo" checkout --detach "$WIBO_COMMIT"
[ "$(git -C "$scratch/wibo" rev-parse HEAD)" = "$WIBO_COMMIT" ] || {
  printf '%s\n' 'build-wibo: pinned Wibo revision verification failed' >&2
  exit 65
}
git -C "$scratch/wibo" apply --check "$project_root/patches/wibo-uharc.patch"
git -C "$scratch/wibo" apply "$project_root/patches/wibo-uharc.patch"

cmake -S "$scratch/wibo" -B "$scratch/build" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_OSX_ARCHITECTURES=x86_64 \
  -DWIBO_ENABLE_WINE_DLLS=NO \
  -DWIBO_ENABLE_TESTS=OFF
cmake --build "$scratch/build" --parallel

mkdir -p "$(dirname -- "$output")"
cp "$scratch/build/wibo" "$output"
chmod +x "$output"
