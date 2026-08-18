#!/bin/sh

set -eu

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
workflow=$project_root/.github/workflows/release.yml

grep -Fq 'group: muharc-release-mutation' "$workflow" || {
  printf '%s\n' 'FAIL: release runs must serialize tap and GitHub-release mutations' >&2
  exit 1
}

grep -Fq 'repository: ghaschel/homebrew-tap' "$workflow" || {
  printf '%s\n' 'FAIL: the tap must be checked out as a staged local repository' >&2
  exit 1
}

grep -Fq 'name: Publish GitHub release' "$workflow" || {
  printf '%s\n' 'FAIL: publishing the GitHub release must happen after the tap smoke test' >&2
  exit 1
}

grep -Fq 'GH_REPO: ${{ github.repository }}' "$workflow" || {
  printf '%s\n' 'FAIL: release-management jobs must target this repository explicitly' >&2
  exit 1
}

grep -Fq 'sudo softwareupdate --install-rosetta --agree-to-license' "$workflow" || {
  printf '%s\n' 'FAIL: the ARM smoke job must install Rosetta 2' >&2
  exit 1
}

rosetta_install_count=$(grep -Fc 'sudo softwareupdate --install-rosetta --agree-to-license' "$workflow")
[ "$rosetta_install_count" -ge 2 ] || {
  printf '%s\n' 'FAIL: the isolated Homebrew formula smoke job must also install Rosetta 2' >&2
  exit 1
}

grep -Fq '/usr/bin/arch -x86_64 "$task_dir/libexec/muharc/wibo" --version' "$workflow" || {
  printf '%s\n' 'FAIL: the ARM smoke job must execute the packaged x86_64 runtime' >&2
  exit 1
}

grep -Fq 'brew tap ghaschel/tap "$GITHUB_WORKSPACE/tap"' "$workflow" || {
  printf '%s\n' 'FAIL: the publish job must tap its local formula checkout' >&2
  exit 1
}

grep -Fq 'brew audit --strict ghaschel/tap/muharc' "$workflow" || {
  printf '%s\n' 'FAIL: the publish job must audit the tap-qualified formula name' >&2
  exit 1
}

grep -Fq 'HOMEBREW_NO_INSTALL_FROM_API=1 brew install --build-from-source ghaschel/tap/muharc' "$workflow" || {
  printf '%s\n' 'FAIL: the publish job must install the prepared local tap checkout' >&2
  exit 1
}

commit_line=$(grep -n 'git -C tap commit -m "muharc $VERSION"' "$workflow" | head -n 1 | cut -d: -f1)
tap_line=$(grep -n 'brew tap ghaschel/tap "$GITHUB_WORKSPACE/tap"' "$workflow" | head -n 1 | cut -d: -f1)
[ -n "$commit_line" ] && [ -n "$tap_line" ] && [ "$commit_line" -lt "$tap_line" ] || {
  printf '%s\n' 'FAIL: the generated formula must be committed before Homebrew taps it' >&2
  exit 1
}

printf '%s\n' 'PASS: release workflow installs and exercises Rosetta 2'
