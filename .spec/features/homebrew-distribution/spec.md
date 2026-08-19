# Homebrew Distribution Specification

**Release:** 0.1.7
**Status:** Shipped and verified

## Problem statement

Users need one reproducible Homebrew installation that exposes `uharc`, bundles the compatibility runtime and notices, installs zsh completion, and is not published to the public tap until the exact generated formula has been tested.

## Goals

- [x] Install with `brew install ghaschel/tap/muharc` and expose `uharc`.
- [x] Deliver one checksummed macOS x86_64 archive containing the wrapper, runtime, completion, license, notice, and changelog.
- [x] Gate a final GitHub release and tap update behind archive, Rosetta, formula-audit, installation, and archive smoke tests.

## Out of scope

| Excluded capability | Reason |
| --- | --- |
| Homebrew core submission | The formula belongs in `ghaschel/homebrew-tap`. |
| Building Wibo on an end-user machine | Releases contain the built runtime. |
| A universal or native arm64 archive | The runtime is intentionally x86_64. |
| Representing UHARC's license as an SPDX license | The distributed executable has separate non-commercial terms. |

## User stories

### P1: Install and use the packaged command

**User story:** As a Homebrew user, I want a single formula installation so that `uharc` works without build tools or JavaScript tooling.

**Acceptance criteria:**

1. WHEN Homebrew installs `ghaschel/tap/muharc` THEN it SHALL install `bin/uharc` and `libexec/muharc` from the release archive.
2. WHEN Homebrew installs the formula THEN it SHALL install `_uharc` in `share/zsh/site-functions`.
3. WHEN the formula test runs THEN `uharc --version` SHALL report the tagged version.
4. WHEN Homebrew audits the formula THEN the formula SHALL use `license :cannot_represent` for the bundled UHARC license terms.

**Independent test:** the release workflow renders the formula, runs `brew audit --strict ghaschel/tap/muharc`, installs it from the staged tap checkout, and runs `uharc --version` plus an archive create/test smoke test.

### P1: Release only a tested formula and archive

**User story:** As a maintainer, I want each tag to produce a tested archive before the public tap and GitHub release are finalized so that users do not receive a formula pointing to a broken asset.

**Acceptance criteria:**

1. WHEN a `v*` tag is pushed THEN the workflow SHALL verify that its version equals `VERSION`, has a matching changelog section, and is an ancestor of `main`.
2. WHEN the release archive is built THEN it SHALL use `macos-15-intel`, contain the required package files, and be uploaded as an artifact.
3. WHEN the archive is available THEN the workflow SHALL create or resume a non-draft prerelease and upload the archive before rendering the formula.
4. WHEN the staged formula is ready THEN the workflow SHALL commit it locally, tap that local checkout, audit it, install it, and smoke-test it before pushing the tap change.
5. WHEN the tap update succeeds THEN the workflow SHALL promote the prerelease to a final GitHub release.

**Independent test:** `tests/release_workflow_test.sh` asserts release serialization, local-tap installation, Rosetta setup, audit/install commands, relative UHARC smoke paths, and the commit-before-tap order.

### P1: Verify Apple Silicon compatibility before publishing

**User story:** As an Apple Silicon user, I want releases to be exercised under Rosetta so that the stated compatibility path is tested rather than assumed.

**Acceptance criteria:**

1. WHEN a release archive is built THEN the workflow SHALL install Rosetta in a separate `macos-15` ARM job.
2. WHEN the Rosetta job runs THEN it SHALL execute the packaged `libexec/muharc/wibo --version` with `arch -x86_64`.
3. WHEN the formula smoke job runs on ARM THEN it SHALL independently install Rosetta before it invokes the formula-installed command.

**Independent test:** `.github/workflows/release.yml` and `tests/release_workflow_test.sh` require the Rosetta commands and the packaged runtime invocation.

## Edge cases

- WHEN a release tag does not match `VERSION` or `CHANGELOG.md` THEN validation SHALL fail before a prerelease is created.
- WHEN a generated formula would replace a newer formula version THEN the workflow SHALL fail rather than downgrade the tap.
- WHEN no formula content changes THEN the workflow SHALL skip the tap push and continue to publish the already-tested matching release.
- WHEN testing an archive in the formula job THEN the smoke test SHALL use relative archive and input paths because UHARC does not accept slash-prefixed macOS absolute paths in that position.

## Requirement traceability

| ID | Requirement | Evidence | Status |
| --- | --- | --- | --- |
| BREW-01 | Install wrapper, runtime, and completion from a formula | `templates/muharc.rb.tmpl` | Verified |
| BREW-02 | Mark unrepresentable UHARC licensing accurately | `templates/muharc.rb.tmpl`, `NOTICE` | Verified |
| BREW-03 | Produce an x86_64 release archive | `Makefile`, `.github/workflows/release.yml` | Verified |
| BREW-04 | Validate tag, version, changelog, and branch ancestry | `.github/workflows/release.yml` | Verified |
| BREW-05 | Smoke-test the archive under Rosetta | `.github/workflows/release.yml`, `tests/release_workflow_test.sh` | Verified |
| BREW-06 | Audit and install the staged local tap formula | `.github/workflows/release.yml`, `tests/release_workflow_test.sh` | Verified |
| BREW-07 | Promote only after the tap test succeeds | `.github/workflows/release.yml` | Verified |

## Success criteria

- [x] Release `v0.1.7` contains `muharc-0.1.7-macos-x86_64.tar.gz` and a final GitHub release.
- [x] The formula points at that release asset with SHA-256 verification.
- [x] The release workflow completed its Intel package, Rosetta, staged-formula, and publish gates.
