# Release Helper Specification

**Status:** Implemented and verified

## Problem statement

Releasing a merged change currently requires a maintainer to manually keep
`VERSION`, `CHANGELOG.md`, the release commit, and the `v*` tag in sync. A
mistake causes the tag workflow to fail validation before it can publish the
tested archive and Homebrew formula.

## Goals

- Let a maintainer publish a patch release from an already merged `main` with
  one explicit command: `./scripts/release.sh 0.1.9`.
- Refuse unsafe release state before changing tracked files or creating a
  release ref.
- Keep the existing tag-triggered GitHub Actions workflow as the only system
  that builds, releases, and updates `ghaschel/homebrew-tap`.

## Out of scope

| Excluded capability | Reason |
| --- | --- |
| Building release artifacts locally | GitHub Actions already builds and gates the supported archive. |
| Changing the Homebrew formula locally | The existing workflow renders, audits, tests, and pushes it after the release asset exists. |
| Automatically choosing a version | A maintainer must explicitly choose the semantic version being published. |
| Recovering a failed remote push automatically | The script must leave its local commit and tag inspectable so the maintainer can resolve the remote problem deliberately. |

## User stories

### P1: Prepare and publish a verified release

**User story:** As a maintainer, I want to run one guarded command after a
change has merged to `main` so that the correct version, changelog, commit,
and tag reach GitHub together and trigger the existing Homebrew release flow.

**Acceptance criteria:**

1. WHEN the maintainer runs `scripts/release.sh N.N.N` from a clean local
   `main` that equals `origin/main` THEN the script SHALL require `N.N.N` to
   have three numeric components and SHALL reject an existing local or remote
   `vN.N.N` tag.
2. WHEN the preflight checks pass THEN the script SHALL run `make test` before
   changing `VERSION`, `CHANGELOG.md`, Git history, or tags.
3. WHEN the maintainer confirms the publish prompt THEN the script SHALL set
   `VERSION` to `N.N.N`, rename the `## Unreleased` changelog heading to
   `## N.N.N`, commit those files as `chore(release): prepare N.N.N`, and
   create `vN.N.N`.
4. WHEN the release commit and tag exist locally THEN the script SHALL push
   `main` and `vN.N.N` together with `git push --atomic`, allowing the existing
   `v*` workflow to perform the GitHub release and Homebrew-tap update.

**Independent test:** `tests/release_script_test.sh` uses a temporary bare
Git remote and a stub `make` command to prove a confirmed release updates the
metadata, creates the expected commit and tag, and atomically publishes both
refs.

### P1: Avoid accidental publication

**User story:** As a maintainer, I want a clear cancellation path and useful
preflight failures so that I do not publish an unintended or stale release.

**Acceptance criteria:**

1. WHEN the checkout has tracked or untracked changes, is not on `main`, or
   does not equal `origin/main` THEN the script SHALL exit nonzero without
   changing tracked release metadata, commits, or tags.
2. WHEN the maintainer answers anything other than `y` or `Y` to the publish
   prompt THEN the script SHALL exit successfully without changing tracked
   release metadata, commits, or tags.
3. WHEN the argument is missing or invalid THEN the script SHALL print usage
   and exit with status 64.

**Independent test:** `tests/release_script_test.sh` confirms a declined
prompt does not create a commit or tag, and an invalid version exits with
usage status 64.

## Edge cases

- WHEN the remote advances between the initial fetch and the final push THEN
  the atomic push SHALL fail rather than publish a tag that is no longer based
  on the remote `main` tip.
- WHEN the final push fails THEN the script SHALL report that the local commit
  and tag were retained for manual inspection; it SHALL not delete or rewrite
  Git history.
- WHEN `CHANGELOG.md` has no `## Unreleased` heading THEN the script SHALL
  fail before creating a release commit or tag.

## Requirement traceability

| ID | Requirement | Evidence | Status |
| --- | --- | --- | --- |
| REL-01 | Validate version, branch, clean tree, upstream, and unused tag | `tests/release_script_test.sh` | Verified |
| REL-02 | Run the complete project test gate before metadata changes | `tests/release_script_test.sh` | Verified |
| REL-03 | Commit version and changelog, tag, and atomically push | `tests/release_script_test.sh` | Verified |
| REL-04 | Allow a declined confirmation without release mutations | `tests/release_script_test.sh` | Verified |
| REL-05 | Document the supported maintainer command | `README.md`, `.spec/STATE.md` | Verified |

## Success criteria

- [x] `./scripts/release.sh 0.1.9` is a documented, tested maintainer path
  from merged `main` to the existing tag-triggered release workflow.
- [x] A release cannot start from a dirty, stale, wrong-branch, invalid-version,
  or already-tagged checkout.
- [x] Declining the final prompt leaves tracked release state untouched.

