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

## Building and testing

Maintainers need Xcode Command Line Tools plus `cmake`, `ninja`, and `python`
(for Wibo's build-time generator only):

```sh
brew install cmake ninja python
make runtime
make test
make dist VERSION=0.1.0
```

The Wibo source is fetched at the exact revision in `sources/wibo.lock`; its
UHARC-specific patch is checked in at `patches/wibo-uharc.patch`. The release
gate archives, lists, tests, and extracts UTF-8 paths containing spaces,
accents, CJK, and emoji.

## License

The wrapper code is MIT licensed. UHARC is separately proprietary freeware for
non-commercial use only; see [NOTICE](NOTICE).
