#!/bin/sh

set -eu

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
stage=$(mktemp -d "${TMPDIR:-/tmp}/muharc-release-script-test.XXXXXX")
trap 'rm -rf "$stage"' EXIT HUP INT TERM

fail() {
  printf '%s\n' "FAIL: $*" >&2
  exit 1
}

prepare_repo() {
  task_name=$1
  task_repo=$stage/$task_name-repo
  task_origin=$stage/$task_name-origin.git
  task_bin=$stage/$task_name-bin

  git clone -q "$project_root" "$task_repo"
  git -C "$task_repo" switch -q main
  git -C "$task_repo" config user.name 'muharc test'
  git -C "$task_repo" config user.email 'muharc-test@example.invalid'

  if [ -f "$project_root/scripts/release.sh" ] &&
    ! git -C "$task_repo" ls-files --error-unmatch scripts/release.sh >/dev/null 2>&1; then
    cp "$project_root/scripts/release.sh" "$task_repo/scripts/release.sh"
    chmod +x "$task_repo/scripts/release.sh"
    git -C "$task_repo" add scripts/release.sh
    git -C "$task_repo" commit -q -m 'test: stage release helper'
  fi

  git init -q --bare "$task_origin"
  git -C "$task_repo" remote set-url origin "$task_origin"
  git -C "$task_repo" push -q -u origin main

  mkdir "$task_bin"
  printf '%s\n' '#!/bin/sh' 'printf "%s\n" "$*" >> "$MUHARC_TEST_MAKE_LOG"' 'exit 0' > "$task_bin/make"
  chmod +x "$task_bin/make"
}

prepare_repo confirmed
confirmed_repo=$task_repo
confirmed_origin=$task_origin
confirmed_bin=$task_bin
confirmed_log=$stage/confirmed-make.log

printf 'y\n' | (
  cd "$confirmed_repo"
  PATH="$confirmed_bin:$PATH" MUHARC_TEST_MAKE_LOG="$confirmed_log" ./scripts/release.sh 0.1.9
) || fail 'confirmed release failed'

test "$(tr -d '\r\n' < "$confirmed_repo/VERSION")" = '0.1.9' ||
  fail 'confirmed release did not update VERSION'
grep -Fxq '## 0.1.9' "$confirmed_repo/CHANGELOG.md" ||
  fail 'confirmed release did not publish the changelog section'
git -C "$confirmed_repo" log -1 --format=%s |
  grep -Fxq 'chore(release): prepare 0.1.9' ||
  fail 'confirmed release did not create the expected commit'
git -C "$confirmed_repo" rev-parse -q --verify refs/tags/v0.1.9 >/dev/null ||
  fail 'confirmed release did not create the local tag'
git --git-dir="$confirmed_origin" rev-parse -q --verify refs/tags/v0.1.9 >/dev/null ||
  fail 'confirmed release did not push the tag'
test "$(git -C "$confirmed_repo" rev-parse HEAD)" = "$(git --git-dir="$confirmed_origin" rev-parse refs/heads/main)" ||
  fail 'confirmed release did not atomically publish main'
grep -Fxq 'test' "$confirmed_log" ||
  fail 'confirmed release did not run make test'

prepare_repo declined
declined_repo=$task_repo
declined_origin=$task_origin
declined_bin=$task_bin
declined_log=$stage/declined-make.log
declined_head=$(git -C "$declined_repo" rev-parse HEAD)

printf 'n\n' | (
  cd "$declined_repo"
  PATH="$declined_bin:$PATH" MUHARC_TEST_MAKE_LOG="$declined_log" ./scripts/release.sh 0.1.9
) || fail 'declined release failed'

test "$(tr -d '\r\n' < "$declined_repo/VERSION")" = '0.1.8' ||
  fail 'declined release changed VERSION'
test "$(git -C "$declined_repo" rev-parse HEAD)" = "$declined_head" ||
  fail 'declined release changed main'
if git -C "$declined_repo" rev-parse -q --verify refs/tags/v0.1.9 >/dev/null; then
  fail 'declined release created a local tag'
fi
if git --git-dir="$declined_origin" rev-parse -q --verify refs/tags/v0.1.9 >/dev/null; then
  fail 'declined release pushed a tag'
fi

prepare_repo invalid
invalid_repo=$task_repo
invalid_bin=$task_bin
set +e
invalid_output=$(
  cd "$invalid_repo" &&
    PATH="$invalid_bin:$PATH" MUHARC_TEST_MAKE_LOG="$stage/invalid-make.log" ./scripts/release.sh 0.1 2>&1
)
invalid_status=$?
set -e
test "$invalid_status" -eq 64 ||
  fail 'invalid version did not exit 64'
case $invalid_output in
  *'Usage: scripts/release.sh VERSION'*) ;;
  *) fail 'invalid version did not print usage guidance' ;;
esac

printf '%s\n' 'PASS: release helper behavior'
