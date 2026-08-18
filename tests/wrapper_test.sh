#!/bin/sh

set -eu

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
stage=$(mktemp -d "${TMPDIR:-/tmp}/muharc-wrapper-test.XXXXXX")
stage=$(CDPATH= cd -- "$stage" && pwd -P)
trap 'rm -rf "$stage"' EXIT HUP INT TERM

fail() {
  printf '%s\n' "FAIL: $*" >&2
  exit 1
}

assert_equal() {
  expected=$1
  actual=$2
  description=$3
  [ "$expected" = "$actual" ] || fail "$description\nexpected: $expected\nactual:   $actual"
}

mkdir -p "$stage/bin" "$stage/libexec/muharc"
cp "$project_root/bin/uharc" "$stage/bin/uharc"
cp "$project_root/assets/completions/_uharc" "$stage/libexec/muharc/_uharc"
printf '%s\n' '0.0.0-test' > "$stage/libexec/muharc/VERSION"
touch "$stage/libexec/muharc/uharc.exe"

cat > "$stage/libexec/muharc/wibo" <<'EOF'
#!/bin/sh
printf '%s\n' "$@" > "$MUHARC_TEST_LOG"
EOF
chmod +x "$stage/bin/uharc" "$stage/libexec/muharc/wibo"

version=$($stage/bin/uharc --version)
assert_equal 'uharc 0.0.0-test' "$version" '--version reports the bundled version'

help=$($stage/bin/uharc --help)
case $help in
  *'Usage: uharc'*) ;;
  *) fail '--help describes the command' ;;
esac

completion=$($stage/bin/uharc --completion zsh)
case $completion in
  '#compdef uharc'*) ;;
  *) fail '--completion zsh writes zsh completion source' ;;
esac

args_log="$stage/args.log"
MUHARC_TEST_LOG=$args_log "$stage/bin/uharc" a 'with spaces' --mystery
expected_args=$(printf '%s\n' "$stage/libexec/muharc/uharc.exe" a 'with spaces' --mystery)
actual_args=$(cat "$args_log")
assert_equal "$expected_args" "$actual_args" 'arguments are forwarded unchanged after uharc.exe'

MUHARC_TEST_LOG=$args_log "$stage/bin/uharc"
expected_args=$(printf '%s\n' "$stage/libexec/muharc/uharc.exe")
actual_args=$(cat "$args_log")
assert_equal "$expected_args" "$actual_args" 'no arguments invokes UHARC unchanged'

printf '%s\n' 'PASS: wrapper behavior'
