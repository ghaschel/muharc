# muharc

`muharc` packages the non-commercial UHARC 0.6b Windows executable for macOS.
Homebrew installs the familiar `uharc` command:

```sh
brew install ghaschel/tap/muharc
```

Intel Macs run it natively. Apple Silicon uses Rosetta 2; install it with
`softwareupdate --install-rosetta --agree-to-license` if needed.

`uharc --help`, `uharc --version`, and `uharc --completion zsh` are wrapper
options. Every other argument is passed unchanged to UHARC.

## Recursive input

UHARC uses Windows-style wildcards. To let UHARC, rather than zsh, interpret a
recursive `*.*` input pattern, quote it:

```sh
uharc a -r+ archive.uha 'directory/*.*'
```

Without quotes, zsh expands the pattern before `uharc` starts; it cannot then
discover or recurse into the matching directories itself.

## Building and testing

Maintainers need Xcode Command Line Tools plus `cmake`, `ninja`, and `python`
(for Wibo's build-time generator only):

```sh
brew install cmake ninja python
make runtime
make test
make dist VERSION=0.1.8
```

The Wibo source is fetched at the exact revision in `sources/wibo.lock`; its
UHARC-specific patch is checked in at `patches/wibo-uharc.patch`. The release
gate archives, lists, tests, and extracts UTF-8 paths containing spaces,
accents, CJK, and emoji.

## Publishing a release

After a change has merged to `main`, run:

```sh
git switch main
git pull --ff-only
./scripts/release.sh 0.1.9
```

The helper requires a clean, up-to-date `main`, runs `make test`, and asks for
confirmation before it updates the version and changelog, creates the release
commit and tag, and atomically pushes both. A successful push triggers the
existing GitHub Actions workflow, which builds the archive and tests and
updates the Homebrew tap. Any response other than `y` or `Y` cancels before
tracked release state changes.

## Maintainer specifications

The shipped 0.1.8 behavior is captured in durable feature specifications:

- [CLI wrapper](.spec/features/cli-wrapper/spec.md)
- [Homebrew distribution](.spec/features/homebrew-distribution/spec.md)
- [Release helper](.spec/features/release-helper/spec.md)
- [Wibo UHARC compatibility](.spec/features/wibo-uharc-compatibility/spec.md)
- [Project decisions and deferred work](.spec/STATE.md)

The [Wibo compatibility patch guide](docs/wibo-uharc-compatibility.md)
documents the pinned source, UTF-8 model, patched API surface, upstream
`FormatMessageA` provenance, regression coverage, and rules for future patch
changes.

## License

The wrapper code is MIT licensed. UHARC is separately proprietary freeware for
non-commercial use only; see [NOTICE](NOTICE).
