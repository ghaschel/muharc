# Wibo UHARC Compatibility Patch

`muharc` builds Wibo from the exact revision in [`sources/wibo.lock`](../sources/wibo.lock), then applies [`patches/wibo-uharc.patch`](../patches/wibo-uharc.patch). This document is the maintenance contract for that patch; it is not a claim that Wibo is a complete Windows implementation.

## Build contract

`scripts/build-wibo.sh` is the only supported build path. It:

1. clones `decompals/wibo` and detaches at `e8f4795ca29e4eb3fdd57e39d3a7490c8eef185b`;
2. verifies that `HEAD` equals that pinned commit;
3. runs `git apply --check` and applies the checked-in patch;
4. builds macOS `x86_64` Wibo with Ninja and `-DWIBO_ENABLE_WINE_DLLS=NO`; and
5. copies the resulting executable to the requested output path.

The build is intentionally reproducible at the source-and-patch level. It does not download a prebuilt Wibo runtime, and no Wine CRT DLLs are bundled.

`scripts/build-wibo.sh` currently also passes `-DWIBO_ENABLE_TESTS=OFF`. The pinned Wibo CMake project does not define that option and reports it as unused. Its fixture-test option is `WIBO_ENABLE_FIXTURE_TESTS` (which requires an i686 MinGW toolchain); in the maintained macOS build, that toolchain is absent and CMake skips the fixtures. This warning is documented here so a future Wibo refresh can replace the unused option deliberately rather than treating it as active test control.

## Compatibility model

The guest narrow-string model is **UTF-8**, not the active locale or a historical Windows single-byte code page.

- `GetACP()` and `GetOEMCP()` return `65001`.
- `GetCPInfo()` accepts `0`, `1`, and `65001`, reports `MaxCharSize = 4`, and rejects other code pages.
- `WideCharToMultiByte()` and `MultiByteToWideChar()` accept the same code pages, convert between UTF-8 and UTF-16, size their destination buffers correctly, and return `ERROR_INVALID_PARAMETER` or `ERROR_INSUFFICIENT_BUFFER` for invalid inputs.
- `wideStringToString()`, `stringToWideString()`, and `stringToUtf16()` encode and decode surrogate pairs. Invalid UTF-8 or unpaired UTF-16 surrogates become U+FFFD.
- `AreFileApisANSI()` reports true; `SetFileApisToANSI()` and `SetFileApisToOEM()` preserve the fixed UTF-8 model rather than changing a global code page.
- `CharToOemA()` is an identity copy because ANSI and OEM are both UTF-8 in this model.

This is the behavior that makes macOS filenames with spaces, accents, CJK characters, and emoji round-trip through UHARC.

## Patched API surface

| Area | Added or changed behavior | Guardrails |
| --- | --- | --- |
| File API mode | Implements `AreFileApisANSI`, `SetFileApisToANSI`, and `SetFileApisToOEM` with the fixed UTF-8 behavior. | No mutable legacy-code-page state is emulated. |
| File enumeration | Treats the exact Win32 legacy wildcard `*.*` as every directory entry, including dotless names. | Other wildcard patterns retain Wibo's existing case-insensitive matching. The shell must pass the pattern literally, for example `'directory/*.*'` in zsh. |
| Process priority | Implements `SetPriorityClass` as a successful no-op for the current process and a nonzero class. | Other handles or a zero class fail with `ERROR_INVALID_PARAMETER`. |
| Narrow string conversion | Replaces byte-cast conversion with UTF-8/UTF-16 conversion. | Only code pages `0`, `1`, and `65001` are accepted. |
| NLS code pages | Reports UTF-8 ACP/OEMCP and UTF-8 code-page metadata. | Unsupported code pages fail with `ERROR_INVALID_PARAMETER`. |
| Console output | Adds `WriteConsoleA` for stdout/stderr and `SetConsoleTitleA` as a valid no-op title update. | Invalid console handles fail; null title input fails. |
| Console input | Implements `PeekConsoleInputA` and `ReadConsoleInputA` for one buffered `KEY_EVENT` byte. TTY input temporarily disables canonical mode, so UHARC can accept a single `Y` without Return. | Invalid handles fail with `ERROR_INVALID_HANDLE`; a null read buffer with a nonzero length fails with `ERROR_INVALID_PARAMETER`. The original terminal mode is restored after the read and again before Wibo's normal process exit. This is not a general keyboard-event implementation. |
| User32 helpers | Adds `CharToOemA` and ASCII-only `CharUpperA`. | `CharToOemA` rejects null pointers; `CharUpperA` leaves non-ASCII case behavior outside the promise. |
| `FormatMessageA` | Enables the declaration and implements `FORMAT_MESSAGE_FROM_STRING` with `%1`–`%9` ANSI string inserts. | Other `FormatMessageA` flag combinations are not newly guaranteed; a missing argument or insufficient buffer fails. |
| Trampoline generation | Treats C array pointees as opaque in generated helper prototypes. | This preserves the outer pointer ABI without depending on the host spelling of `va_list`. |

## `FormatMessageA` provenance

The `FormatMessageA` declaration, minimal source-string insert implementation, fixture, CMake registration, and array-pointee trampoline handling are carried from the approach in [Wibo PR #139](https://github.com/decompals/wibo/pull/139). That PR explains why 64-bit Clang may represent `va_list` as an array and why the generated helper must preserve the outer pointer ABI as an opaque pointer. It is open as of this document's date, so this repository retains the necessary changes in its own patch instead of assuming an upstream release contains them.

The local fixture, `test/test_formatmessage.c`, verifies reordered `%2` then `%1` ANSI inserts through a real guest `va_list`. The maintained macOS build skips Wibo fixture tests because it has no MinGW toolchain, so the fixture documents and protects the isolated ABI behavior when fixture tests are enabled; the release gate instead proves the complete UHARC path.

## Regression coverage

| Promise | Test | What it proves |
| --- | --- | --- |
| Patch applies to a clean pinned checkout and produces x86_64 Wibo | `tests/runtime_build_test.sh` | The build script clones, verifies, patches, and compiles Wibo. |
| Wrapper reaches the packaged runtime correctly | `tests/wrapper_test.sh` | Argument forwarding, metadata, and Homebrew symlink resolution. |
| Relative runtime locations work | `tests/uharc_integration_path_test.sh` | The integration suite accepts a relative `MUHARC_RUNTIME_DIR`. |
| Unicode archive round trip | `tests/uharc_integration_test.sh` | UHARC creates, lists, tests, extracts, and byte-compares space, accented, CJK, and emoji fixtures. |
| Recursive wildcard round trip | `tests/uharc_integration_test.sh` | A quoted `input/*.*` with `-r+` includes and extracts files from dotless nested directories. |
| Interactive overwrite confirmation | `tests/uharc_overwrite_prompt_test.sh` | A real pseudo-terminal sends only `Y` to an existing archive's prompt, verifies the replacement archive, and checks the TTY local-mode flags are restored. |
| Release automation preserves the compatibility gates | `tests/release_workflow_test.sh` | Rosetta installation, x86_64 runtime execution, local-tap audit/install, and relative-path smoke behavior remain required. |
| Apple Silicon delivery path | `.github/workflows/release.yml` `rosetta-smoke` job | The release archive runs under Rosetta on a macOS ARM runner. |

Run the maintained suite with:

```sh
make test
```

## Rules for changing the patch

1. Start with a failing end-to-end UHARC test that demonstrates the needed behavior. Use the Unicode integration fixture set when the change affects paths or data fidelity.
2. Add the smallest API or behavior change that makes that test pass. Do not add general Windows-emulation features speculatively.
3. For ABI-sensitive or independently testable Wibo behavior, add or extend a Wibo fixture in the patch as well.
4. Update this document's API table, the relevant feature spec in [`.spec/features/wibo-uharc-compatibility/spec.md`](../.spec/features/wibo-uharc-compatibility/spec.md), and its requirement traceability.
5. Run `make test`. When changing the pinned Wibo revision, also run `tests/runtime_build_test.sh` from a clean working tree and confirm `git apply --check` succeeds through the build script.

If the patch grows beyond UHARC-proven compatibility behavior, split the concern into a separately specified Wibo-maintenance feature before continuing.
