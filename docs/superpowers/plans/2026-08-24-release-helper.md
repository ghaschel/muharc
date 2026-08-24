# Release Helper Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (- [ ]) syntax for tracking.

**Goal:** Provide one safe maintainer command that turns an already merged
main commit into a validated, tagged, and pushed release that activates the
existing GitHub/Homebrew pipeline.

**Architecture:** A POSIX-shell helper owns only local release preparation:
preflight, full test gate, metadata update, commit, tag, and atomic Git push.
GitHub Actions remains responsible for artifacts, prerelease, Homebrew formula
validation, tap update, and final publication. A hermetic shell integration
test supplies a temporary bare Git remote and fake make executable, avoiding
network access and an expensive Wibo build while exercising the actual helper.

**Tech Stack:** POSIX sh, Git, Make, existing shell-test conventions.

**Spec:** .spec/features/release-helper/spec.md

## Global Constraints

- The maintainer invokes the helper after merging to main and supplies an
  explicit numeric semantic version such as 0.1.9 (without a v prefix).
- Homebrew packaging remains exclusively in the existing v* GitHub Actions
  workflow; do not add Node.js, Bun, npm, or a local formula mutation path.
- The helper must prompt before it creates the release commit, tag, or remote
  push; cancellation must leave tracked files and refs unchanged.
- main and its version tag must be pushed with git push --atomic.
- Preserve an inspectable local commit and tag if the final remote push fails.

---

### Task 1: Define the release-helper contract with a failing integration test

**Files:**

- Create: tests/release_script_test.sh
- Modify: .spec/features/release-helper/spec.md

**Interfaces:**

- Consumes: the executable scripts/release.sh VERSION interface declared by the
  feature spec.
- Produces: a temporary-repository test harness that later tasks run directly
  and through make test.

- [x] **Step 1: Write the failing test**

Create a POSIX-shell test that makes a local clone of the repository, points
it at a temporary bare origin, and places this executable earlier in PATH:

~~~sh
#!/bin/sh
printf '%s\n' "$*" >> "$MUHARC_TEST_MAKE_LOG"
exit 0
~~~

Run the requested release with printf 'y\n' piped to scripts/release.sh 0.1.9
and assert all of the following:

~~~sh
test "$(tr -d '\r\n' < VERSION)" = 0.1.9
grep -Fxq '## 0.1.9' CHANGELOG.md
git log -1 --format=%s | grep -Fxq 'chore(release): prepare 0.1.9'
git rev-parse -q --verify refs/tags/v0.1.9 >/dev/null
git --git-dir="$stage/origin.git" rev-parse -q --verify refs/tags/v0.1.9 >/dev/null
grep -Fxq test "$MUHARC_TEST_MAKE_LOG"
~~~

In separate fresh clones, assert a declined n response leaves VERSION and the
ref tips unchanged, and assert 0.1 exits with status 64 and usage text.

- [x] **Step 2: Run test to verify it fails**

Run: ./tests/release_script_test.sh

Expected: FAIL because scripts/release.sh does not exist yet.

- [x] **Step 3: Keep the acceptance criteria precise**

Confirm the failing assertions cover REL-01 through REL-04 without asserting
implementation details other than the documented commit message and atomic
remote result.

- [x] **Step 4: Commit**

~~~sh
git add tests/release_script_test.sh .spec/features/release-helper/spec.md
git commit -m "test(release): define release helper behavior"
~~~

### Task 2: Implement and register the guarded POSIX release helper

**Files:**

- Create: scripts/release.sh
- Modify: Makefile
- Test: tests/release_script_test.sh

**Interfaces:**

- Consumes: scripts/release.sh VERSION, a clean checked-out main, Git remote
  origin, VERSION, CHANGELOG.md, and make test.
- Produces: a chore(release): prepare VERSION commit, vVERSION tag, and an
  atomic push only after confirmation.

- [x] **Step 1: Run the existing failing test**

Run: ./tests/release_script_test.sh

Expected: FAIL because the helper is missing.

- [x] **Step 2: Implement the minimum helper**

Create scripts/release.sh as executable POSIX shell. It must:

~~~sh
set -eu
# Require exactly one ^[0-9]+\.[0-9]+\.[0-9]+$ argument or exit 64.
# Require the current branch to equal main and the porcelain status to be empty.
# Fetch origin/main and tags; require HEAD == origin/main and no vVERSION tag.
make test
printf 'Publish main and v%s? [y/N] ' "$release_version" >&2
IFS= read -r answer || answer=
case $answer in y|Y) ;; *) exit 0 ;; esac
# Replace only the Unreleased changelog heading with the requested version.
git add VERSION CHANGELOG.md
git commit -m "chore(release): prepare $release_version"
git tag "v$release_version"
git push --atomic origin main "refs/tags/v$release_version"
~~~

Use mktemp plus a trap while rewriting CHANGELOG.md; on an atomic-push failure,
print a message that the local commit and tag remain available for inspection.
Do not add an automation escape hatch that skips tests or bypasses the
confirmation prompt.

- [x] **Step 3: Register the regression test**

Append ./tests/release_script_test.sh to the existing test recipe after the
workflow test and before the expensive UHARC runtime integration tests.

- [x] **Step 4: Run targeted tests to verify they pass**

Run: ./tests/release_script_test.sh

Expected: PASS: release helper behavior.

- [x] **Step 5: Run the project gate**

Run: make test

Expected: all wrapper, workflow, release-helper, and UHARC integration tests
pass.

- [x] **Step 6: Commit**

~~~sh
git add scripts/release.sh Makefile tests/release_script_test.sh
git commit -m "feat(release): add guarded release helper"
~~~

### Task 3: Document the maintainer release path and finalize traceability

**Files:**

- Modify: README.md
- Modify: .spec/STATE.md
- Modify: .spec/features/release-helper/spec.md
- Modify: docs/superpowers/plans/2026-08-24-release-helper.md

**Interfaces:**

- Consumes: the tested scripts/release.sh VERSION command from Task 2.
- Produces: maintainer instructions and feature state that accurately describe
  its validation, confirmation, and GitHub Actions hand-off.

- [x] **Step 1: Add concise README instructions**

Add a Publishing a release section containing exactly this supported flow:

~~~sh
git switch main
git pull --ff-only
./scripts/release.sh 0.1.9
~~~

Explain that the command runs make test, asks before creating the release
commit and tag, atomically pushes main and v0.1.9, and that the existing tag
workflow builds the archive and updates the Homebrew tap.

- [x] **Step 2: Update persistent state and traceability**

Record a release-helper decision in .spec/STATE.md, set REL-01 through REL-05
to Verified in the feature spec, and mark all plan checkboxes complete only
after the final gate succeeds.

- [x] **Step 3: Verify documentation references the real interface**

Run: rg -n 'release\.sh|0\.1\.9|push --atomic|REL-0[1-5]' README.md .spec docs/superpowers/plans/2026-08-24-release-helper.md

Expected: references use scripts/release.sh 0.1.9, describe confirmation, and
do not claim local artifact or formula publication.

- [x] **Step 4: Commit**

~~~sh
git add README.md .spec/STATE.md .spec/features/release-helper/spec.md \
  docs/superpowers/plans/2026-08-24-release-helper.md
git commit -m "docs(release): document guarded publish flow"
~~~

## Self-review

- Spec coverage: REL-01 and REL-04 map to Task 1 and Task 2; REL-02 and
  REL-03 map to Task 2; REL-05 maps to Task 3. No release artifact, formula,
  or workflow redesign is included.
- Placeholder scan: no task contains TBD-style instructions; each test,
  command, behavior, file path, and commit message is explicit.
- Interface consistency: every task uses the same public interface,
  scripts/release.sh VERSION, and the release ref is consistently vVERSION.
