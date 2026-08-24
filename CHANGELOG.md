# Changelog

## 0.1.9

- Make UHARC's interactive overwrite prompt accept a bare `Y`, without a
  trailing Return, through Wibo's console-input compatibility layer.

## 0.1.8

- Make Wibo's exact Windows `*.*` directory wildcard include dotless entries,
  so UHARC `-r+` recursively archives their contents when passed a quoted
  wildcard pattern.

## 0.1.7

- Run the Homebrew archive smoke test from its temporary directory so UHARC
  receives relative archive and input paths instead of slash-prefixed switches.

## 0.1.6

- Resolve the Homebrew `bin/uharc` symlink before locating the bundled
  runtime in the Cellar, and cover the real global-bin-to-Cellar layout.

## 0.1.5

- Commit the generated formula in the temporary tap checkout before auditing,
  so Homebrew audits and installs that exact unpublished formula.

## 0.1.4

- Audit and install the generated formula through its temporary Homebrew tap,
  using Homebrew's supported named-formula interface.

## 0.1.3

- Normalize the archive smoke test runtime path before changing its working
  directory, so packaged releases are exercised correctly under Rosetta 2.

## 0.1.2

- Install and verify Rosetta 2 on the Apple Silicon release runner before
  executing the packaged x86_64 runtime.

## 0.1.1

- Run Wibo runtime and Homebrew smoke tests on Apple Silicon under Rosetta 2;
  current native Intel macOS runners crash before the guest can start.

## 0.1.0

- Initial macOS Homebrew wrapper for UHARC, with a bundled x86_64 Wibo runtime.
- UTF-8 compatibility coverage for spaces, accented text, CJK, and emoji paths.
