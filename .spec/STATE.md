# Project State

**Last updated:** 2026-08-19
**Current work:** No active feature; recursive `*.*` wildcard compatibility is verified locally and queued for `0.1.8`

## Recent decisions

### AD-001: Publish `muharc`, expose `uharc` (2026-08-18)

**Decision:** The Homebrew formula is named `muharc`; its installed executable is `uharc`.

**Reason:** Existing UHARC users expect the `uharc` command, while the wrapper needs a distinct package name.

**Trade-off:** Homebrew users install `ghaschel/tap/muharc`, but documentation must explain the different package and command names.

**Impact:** The formula installs `bin/uharc`; completion declares `#compdef uharc`.

### AD-002: Ship an x86_64 Wibo runtime (2026-08-18)

**Decision:** Build only an x86_64 macOS Wibo executable. Intel Macs run it directly; Apple Silicon invokes it through Rosetta 2.

**Reason:** Wibo has no supported native macOS arm64 guest-runtime path for this UHARC release.

**Trade-off:** Apple Silicon users need Rosetta 2; native arm64 support is not provided.

**Impact:** The wrapper detects a missing Rosetta installation, and the release workflow smoke-tests the packaged runtime under Rosetta.

### AD-003: Pin and patch Wibo in source control (2026-08-18)

**Decision:** Build from `decompals/wibo@e8f4795ca29e4eb3fdd57e39d3a7490c8eef185b` and apply `patches/wibo-uharc.patch` during every build.

**Reason:** UHARC requires Windows APIs and UTF-8 behavior not provided by that pinned revision.

**Trade-off:** Upstream Wibo updates require refreshing the patch and the compatibility suite.

**Impact:** `scripts/build-wibo.sh` verifies the checkout, checks patch applicability, and builds with Wine CRT DLLs disabled.

### AD-004: Treat guest ANSI and OEM strings as UTF-8 (2026-08-18)

**Decision:** Wibo reports UTF-8 code page 65001 for ACP and OEMCP, with explicit UTF-8/UTF-16 conversion.

**Reason:** The release requires lossless archive paths containing accents, CJK text, and emoji on macOS filesystems.

**Trade-off:** This is a deliberate compatibility model, not an emulation of historic Windows code pages.

**Impact:** Only code pages `0`, `1`, and `65001` are accepted by the patched conversions.

### AD-005: Test a staged release before updating the public tap (2026-08-18)

**Decision:** The tag workflow creates a GitHub prerelease, installs the generated formula from a local checkout of `ghaschel/homebrew-tap`, pushes the formula only after that test, then promotes the release.

**Reason:** The formula must download the release archive, but an untested formula must not reach the public tap.

**Trade-off:** Release automation requires the `HOMEBREW_TAP_TOKEN` secret with write access to the tap.

**Impact:** Release jobs serialize tap and GitHub-release mutations.

## Active blockers

None.

## Lessons learned

### L-001: Resolve the Homebrew launcher symlink before locating `libexec` (2026-08-18)

**Context:** Homebrew exposes the Cellar script through a symlink in its global `bin` directory.

**Problem:** Resolving the runtime relative to the symlink location could not find the packaged Wibo files.

**Solution:** `bin/uharc` follows symlinks before calculating `../libexec/muharc`.

**Prevents:** A formula installation that reports a missing runtime even though its Cellar package is complete.

### L-002: Use relative UHARC paths in formula smoke tests (2026-08-18)

**Context:** Homebrew formula tests run in a temporary macOS directory.

**Problem:** UHARC interprets slash-prefixed Unix absolute paths as option-like input rather than archive paths.

**Solution:** Change to the temporary directory and pass `input.txt` and `smoke.uha` as relative paths.

**Prevents:** A false failure in an otherwise valid formula installation.

### L-003: The pinned Wibo revision uses a different fixture-test option (2026-08-19)

**Context:** A clean `make test` build reports that `-DWIBO_ENABLE_TESTS=OFF` is unused.

**Problem:** That cache variable is passed by `scripts/build-wibo.sh`, but the pinned Wibo CMake file defines `WIBO_ENABLE_FIXTURE_TESTS` instead. Fixture tests are currently skipped because the required MinGW toolchain is unavailable.

**Solution:** Document the actual option and skip condition. Do not represent `WIBO_ENABLE_TESTS` as an effective fixture-test control.

**Prevents:** Misleading maintenance guidance when Wibo's test configuration or the build environment changes.

### L-004: Windows `*.*` is not a POSIX glob (2026-08-19)

**Context:** UHARC starts recursive discovery with `FindFirstFileA("*.*")`.

**Problem:** Wibo matched `*.*` literally, excluding dotless directory names,
and unquoted zsh input expanded before UHARC could perform its own search.

**Solution:** Make the exact Wibo pattern `*.*` match every directory entry,
as Win32 does, and document that zsh users must quote the intended UHARC
pattern.

**Prevents:** Recursive archives silently omitting files stored under dotless
directories.

## Deferred ideas

- [ ] Native Apple Silicon Wibo support — requires a supported arm64 Wibo guest-runtime implementation and a release-compatible UHARC test suite.
- [ ] Expand the Wibo patch only when an end-to-end UHARC regression proves an additional API is necessary.

## Todos

- [ ] Keep `.spec/features/` current when a released capability or compatibility promise changes.
- [ ] Review the Wibo pin and patch whenever moving to a newer upstream Wibo commit.

## Preferences

**Model guidance shown:** never
