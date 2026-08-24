#!/bin/sh

set -eu

usage() {
  printf '%s\n' 'Usage: scripts/release.sh VERSION' >&2
}

fail() {
  printf '%s\n' "release: $*" >&2
  exit 1
}

if [ "$#" -ne 1 ] || ! printf '%s\n' "$1" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
  usage
  exit 64
fi

release_version=$1
project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
cd "$project_root"

[ "$(git branch --show-current)" = main ] ||
  fail 'checkout main before preparing a release'
[ -z "$(git status --porcelain)" ] ||
  fail 'working tree is not clean'

git remote get-url origin >/dev/null 2>&1 ||
  fail 'origin remote is required'
git fetch --quiet --tags origin '+refs/heads/main:refs/remotes/origin/main'

head_commit=$(git rev-parse HEAD)
remote_main=$(git rev-parse refs/remotes/origin/main)
[ "$head_commit" = "$remote_main" ] ||
  fail 'local main does not match origin/main'

if git rev-parse -q --verify "refs/tags/v$release_version" >/dev/null; then
  fail "tag v$release_version already exists"
fi

current_version=$(tr -d '\r\n' < VERSION)
[ "$current_version" != "$release_version" ] ||
  fail "VERSION is already $release_version"
grep -Fxq '## Unreleased' CHANGELOG.md ||
  fail 'CHANGELOG.md is missing the ## Unreleased heading'

make test

[ -z "$(git status --porcelain)" ] ||
  fail 'make test changed the working tree'

printf 'Publish main and v%s? [y/N] ' "$release_version" >&2
IFS= read -r answer || answer=
case $answer in
  y|Y) ;;
  *) exit 0 ;;
esac

temporary_changelog=$(mktemp "${TMPDIR:-/tmp}/muharc-release-changelog.XXXXXX")
cleanup() {
  rm -f "$temporary_changelog"
}
trap cleanup EXIT HUP INT TERM

awk -v version="$release_version" '
  $0 == "## Unreleased" {
    print "## " version
    replaced = 1
    next
  }
  { print }
  END {
    if (!replaced) {
      exit 1
    }
  }
' CHANGELOG.md > "$temporary_changelog" ||
  fail 'could not prepare CHANGELOG.md'

mv "$temporary_changelog" CHANGELOG.md
temporary_changelog=

printf '%s\n' "$release_version" > VERSION
git add VERSION CHANGELOG.md
git commit -m "chore(release): prepare $release_version"
git tag "v$release_version"

if ! git push --atomic origin main "refs/tags/v$release_version"; then
  printf '%s\n' "release: push failed; local main and v$release_version were retained for inspection" >&2
  exit 1
fi

