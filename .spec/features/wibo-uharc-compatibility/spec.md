# Wibo UHARC Compatibility Specification

**Release:** Next patch release
**Status:** Console-input change verified locally; pending release

## Problem statement

The UHARC 0.6b Windows executable calls Windows APIs that are absent or insufficient in the pinned Wibo revision. Without a deliberately small compatibility patch, UHARC cannot reliably execute on macOS or preserve UTF-8 archive paths.

## Goals

- [x] Build the same patched Wibo source revision on every maintainer and release machine.
- [x] Implement only the Windows API behavior UHARC requires, with explicit error handling for unsupported inputs.
- [x] Model guest narrow strings as UTF-8 so spaces, accented text, CJK text, and emoji round-trip without filename or content changes.
- [x] Require an end-to-end UHARC regression before extending the patch.

## Out of scope

| Excluded capability | Reason |
| --- | --- |
| General-purpose Windows emulation | `muharc` only needs UHARC's exercised API surface. |
| Historic ACP/OEM code-page emulation | The supported model is UTF-8, code page 65001. |
| Full `FormatMessageA` flag support | Only the `FORMAT_MESSAGE_FROM_STRING` insert path required by the fixture is implemented. |
| Native arm64 Wibo guest execution | The release ships an x86_64 runtime. |

## User stories

### P1: Reproduce the patched runtime

**User story:** As a maintainer, I want the exact Wibo source and patch verified before compilation so that a release can be reproduced and audited.

**Acceptance criteria:**

1. WHEN `make runtime` runs THEN it SHALL clone Wibo from the repository and detach at the commit recorded in `sources/wibo.lock`.
2. WHEN the checkout does not resolve to the pinned commit THEN the build SHALL stop before compilation.
3. WHEN the patch cannot apply cleanly THEN the build SHALL stop before compilation.
4. WHEN compilation starts THEN it SHALL target macOS x86_64 with `-DWIBO_ENABLE_WINE_DLLS=NO`. The script also passes `-DWIBO_ENABLE_TESTS=OFF`, which the pinned CMake logs as unused; fixture tests are controlled by `WIBO_ENABLE_FIXTURE_TESTS` and skip without a MinGW toolchain.

**Independent test:** `tests/runtime_build_test.sh` runs a clean build script invocation and asserts an executable x86_64 Wibo result.

### P1: Preserve Unicode archive paths and contents

**User story:** As a user archiving macOS files, I want Unicode names to survive create, list, test, and extract operations so that no names or bytes change.

**Acceptance criteria:**

1. WHEN UHARC uses ACP, OEMCP, or a conversion API THEN the patched runtime SHALL use UTF-8 code page 65001 semantics.
2. WHEN UTF-8 is converted to UTF-16 or back THEN the runtime SHALL handle supplementary-plane characters through surrogate pairs and replace malformed sequences with U+FFFD.
3. WHEN the archive fixture includes a space, `résumé`, `日本語`, and `emoji-📦` names THEN archive create, list, test, and extract SHALL complete.
4. WHEN files are extracted THEN their names and contents SHALL compare byte-for-byte with the fixtures.

**Independent test:** `tests/uharc_integration_test.sh` performs the full round trip and compares every extracted fixture.

### P1: Recurse through Windows-style wildcards

**User story:** As a user archiving a directory tree with UHARC, I want `-r+`
with a literal `*.*` pattern to discover dotless directories so that every
matching nested file reaches the archive.

**Acceptance criteria:**

1. WHEN UHARC calls `FindFirstFileA` with the exact pattern `*.*` THEN the patched runtime SHALL match every directory entry, including dotless names.
2. WHEN a zsh user passes a wildcard intended for UHARC THEN the documentation SHALL require a quoted literal pattern such as `'input/*.*'`.
3. WHEN `uharc a -r+ recursive.uha 'input/*.*'` receives files in dotless nested directories THEN archive list, test, extract, and byte comparison SHALL include every fixture.

**Independent test:** `tests/uharc_integration_test.sh` constructs dotless nested directories, performs the quoted recursive wildcard round trip, and compares every extracted file.

### P1: Confirm an archive overwrite from console input

**User story:** As a UHARC user, I want a bare `Y` at an overwrite prompt to
start compression so that I can confirm an existing archive without passing
`-y+` or pressing Return.

**Acceptance criteria:**

1. WHEN UHARC calls `PeekConsoleInputA` on a valid console input handle THEN the runtime SHALL report one buffered key event when a byte is available without consuming it from UHARC's view.
2. WHEN UHARC calls `ReadConsoleInputA` for that event THEN the runtime SHALL return a `KEY_EVENT` containing that byte and consume it.
3. WHEN the input handle is a TTY THEN the runtime SHALL temporarily disable canonical input so `Y` is available without a newline, then restore its original terminal mode after the read and before normal Wibo process exit.
4. WHEN an existing `.uha` archive is replaced through a real pseudo-terminal that writes only `Y` THEN UHARC SHALL complete and extraction SHALL contain the replacement content.

**Independent test:** `tests/uharc_overwrite_prompt_test.sh` creates an archive, changes the source file, writes bare `Y` through a pseudo-terminal, tests and extracts the archive, and checks the terminal's local-mode flags.

### P1: Supply the minimal API surface UHARC exercises

**User story:** As a maintainer, I want each compatibility shim to have defined success and failure behavior so that additional APIs do not become untracked emulation scope.

**Acceptance criteria:**

1. WHEN UHARC calls the required file, console, process, user, NLS, and string APIs THEN the patched runtime SHALL provide the documented compatibility behavior in `docs/wibo-uharc-compatibility.md`.
2. WHEN an API receives an unsupported code page, invalid handle, null input, or inadequate output buffer THEN it SHALL return a Windows-style failure and set the documented error where the shim supports it.
3. WHEN a new API is proposed THEN a failing end-to-end UHARC case SHALL exist before the patch grows, and its behavior SHALL be added to the patch documentation.

**Independent test:** the Unicode integration test exercises the runtime end-to-end; the Wibo `test_formatmessage` fixture is retained in the patch for the isolated ABI-sensitive `FormatMessageA` path when upstream fixture tests are enabled.

## Edge cases

- WHEN `MultiByteToWideChar` or `WideCharToMultiByte` receives a code page other than `0`, `1`, or `65001` THEN it SHALL fail with `ERROR_INVALID_PARAMETER`.
- WHEN a destination buffer is too small for `FormatMessageA` or character conversion THEN the shim SHALL fail without writing a truncated success result.
- WHEN `FormatMessageA` is called with flags other than the implemented source-string path THEN its pre-existing Wibo behavior remains outside this patch's guarantee.
- WHEN a UTF-16 sequence has an unpaired surrogate or UTF-8 input is malformed THEN conversion SHALL use U+FFFD rather than preserving invalid code units.
- WHEN `ReadConsoleInputA` receives a nonzero length with a null output buffer THEN it SHALL fail with `ERROR_INVALID_PARAMETER`.
- WHEN a console input handle is invalid THEN `PeekConsoleInputA` and `ReadConsoleInputA` SHALL fail with `ERROR_INVALID_HANDLE`.

## Requirement traceability

| ID | Requirement | Evidence | Status |
| --- | --- | --- | --- |
| WIBO-01 | Pin, verify, and patch the Wibo checkout | `sources/wibo.lock`, `scripts/build-wibo.sh`, `tests/runtime_build_test.sh` | Verified |
| WIBO-02 | Build x86_64 without Wine CRT DLLs | `scripts/build-wibo.sh`, `tests/runtime_build_test.sh` | Verified |
| WIBO-03 | Use UTF-8 ACP/OEMCP and code-page information | `patches/wibo-uharc.patch`, `tests/uharc_integration_test.sh` | Verified |
| WIBO-04 | Convert UTF-8 and UTF-16 safely, including emoji | `patches/wibo-uharc.patch`, `tests/fixtures/unicode/emoji-📦.txt` | Verified |
| WIBO-05 | Provide UHARC-required narrow API shims | `patches/wibo-uharc.patch`, `docs/wibo-uharc-compatibility.md` | Implemented |
| WIBO-06 | Preserve Unicode names and contents through a UHARC round trip | `tests/uharc_integration_test.sh` | Verified |
| WIBO-07 | Keep `FormatMessageA` ABI handling covered by a fixture | `patches/wibo-uharc.patch`, Wibo fixture tests | Implemented |
| WIBO-08 | Match Win32 `*.*` for recursive discovery of dotless directories | `patches/wibo-uharc.patch`, `tests/uharc_integration_test.sh` | Verified |
| WIBO-09 | Accept a bare `Y` from UHARC's overwrite prompt while restoring TTY state | `patches/wibo-uharc.patch`, `tests/uharc_overwrite_prompt_test.sh` | Verified locally |

## Success criteria

- [x] `make runtime` produces a patched x86_64 Wibo executable from a clean clone.
- [x] `make test` archives, lists, tests, extracts, and byte-compares every Unicode fixture.
- [x] `make test` includes a quoted `*.*` recursive round trip through dotless directories.
- [x] `make test` accepts bare `Y` for an existing archive overwrite and restores pseudo-terminal flags.
- [x] The release workflow runs the same archive suite through Rosetta.
