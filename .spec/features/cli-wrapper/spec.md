# CLI Wrapper Specification

**Release:** 0.1.7
**Status:** Shipped and verified

## Problem statement

UHARC is a Windows executable, so macOS users need a stable local command that locates the bundled runtime, runs it with the correct architecture, and preserves UHARC's existing command-line interface.

## Goals

- [x] Provide the familiar `uharc` command without requiring Node.js, Bun, npm, or a separate Windows runtime installation.
- [x] Preserve ordinary UHARC argument handling exactly, including no arguments and arguments containing spaces.
- [x] Make supported macOS architecture behavior and Rosetta requirements explicit.

## Out of scope

| Excluded capability | Reason |
| --- | --- |
| Reimplementing UHARC in a native macOS language | This project wraps the supplied UHARC executable. |
| Native Apple Silicon Wibo execution | The shipped runtime is x86_64 only. |
| Full completion of every UHARC option | The completion covers the common command and archive/file positions only. |

## User stories

### P1: Invoke UHARC through a familiar command

**User story:** As a macOS UHARC user, I want to run `uharc` with the same arguments I would use on Windows so that I can create, list, test, and extract archives without learning a replacement tool.

**Acceptance criteria:**

1. WHEN the user runs `uharc` with no arguments THEN the wrapper SHALL invoke `wibo uharc.exe` with no UHARC arguments.
2. WHEN the user supplies ordinary UHARC arguments THEN the wrapper SHALL forward every argument unchanged after the `uharc.exe` argument.
3. WHEN an argument contains spaces THEN the wrapper SHALL forward it as one argument.
4. WHEN the script is launched through a Homebrew-style symlink THEN the wrapper SHALL resolve the actual script before locating `libexec/muharc`.

**Independent test:** `tests/wrapper_test.sh` logs and compares the exact forwarded argument vector, including a space-containing argument, no arguments, and a Cellar-style symlink launcher.

### P1: Use wrapper-owned help, version, and completion output

**User story:** As a command-line user, I want predictable wrapper metadata so that I can identify the installed package and configure zsh completion.

**Acceptance criteria:**

1. WHEN the user runs `uharc --help` alone THEN the wrapper SHALL print its usage and wrapper options.
2. WHEN the user runs `uharc --version` alone THEN the wrapper SHALL print `uharc <bundled-version>` from runtime metadata.
3. WHEN the user runs `uharc --completion zsh` THEN the wrapper SHALL write the bundled `_uharc` zsh completion source to standard output.
4. WHEN a wrapper option is combined with UHARC arguments or used incorrectly THEN the wrapper SHALL return exit status 64 with usage guidance.

**Independent test:** `tests/wrapper_test.sh` asserts help, version, and the `#compdef uharc` completion header.

### P1: Explain Rosetta requirements clearly

**User story:** As an Apple Silicon user, I want a direct error if Rosetta is unavailable so that I know exactly how to enable the x86_64 runtime.

**Acceptance criteria:**

1. WHEN the host reports `arm64` and `arch -x86_64 true` fails THEN the wrapper SHALL exit 69 and print the `softwareupdate --install-rosetta --agree-to-license` command.
2. WHEN Rosetta is available on an `arm64` host THEN the wrapper SHALL execute Wibo through `arch -x86_64`.
3. WHEN the host is not `arm64` THEN the wrapper SHALL execute Wibo directly.

**Independent test:** the release workflow runs the packaged x86_64 Wibo runtime under Rosetta on `macos-15`; the wrapper's error branch is a small platform guard not exercised by the Intel local test.

## Edge cases

- WHEN the packaged Wibo executable or `uharc.exe` is missing THEN the wrapper SHALL exit 70 and direct the user to reinstall with Homebrew.
- WHEN `VERSION` or `_uharc` is missing for a wrapper-owned option THEN the wrapper SHALL exit 70 and identify the missing packaged metadata.

## Requirement traceability

| ID | Requirement | Evidence | Status |
| --- | --- | --- | --- |
| CLI-01 | Forward UHARC arguments unchanged | `tests/wrapper_test.sh` | Verified |
| CLI-02 | Support no-argument invocation | `tests/wrapper_test.sh` | Verified |
| CLI-03 | Resolve the Homebrew symlink launcher | `tests/wrapper_test.sh` | Verified |
| CLI-04 | Provide help, version, and zsh completion output | `tests/wrapper_test.sh` | Verified |
| CLI-05 | Invoke x86_64 Wibo through Rosetta on Apple Silicon | `.github/workflows/release.yml`, `tests/release_workflow_test.sh` | Verified |
| CLI-06 | Diagnose a missing or incomplete runtime | `bin/uharc` guarded error paths | Implemented |

## Success criteria

- [x] `make test` covers wrapper metadata and argument forwarding.
- [x] A Homebrew-installed `uharc --version` reports the package version in the release workflow.
- [x] The packaged runtime completes the Unicode archive integration test under Rosetta.
