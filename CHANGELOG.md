# Changelog

## 0.1.2

- Install and verify Rosetta 2 on the Apple Silicon release runner before
  executing the packaged x86_64 runtime.

## 0.1.1

- Run Wibo runtime and Homebrew smoke tests on Apple Silicon under Rosetta 2;
  current native Intel macOS runners crash before the guest can start.

## 0.1.0

- Initial macOS Homebrew wrapper for UHARC, with a bundled x86_64 Wibo runtime.
- UTF-8 compatibility coverage for spaces, accented text, CJK, and emoji paths.
