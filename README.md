# netcat

[GNU netcat](https://netcat.sourceforge.net/) — the networking "Swiss-army knife": read and write data across TCP/UDP connections. A single self-contained binary, built natively for Linux, macOS, and Windows.

[![CI](https://github.com/unpins/netcat/actions/workflows/netcat.yml/badge.svg)](https://github.com/unpins/netcat/actions)
![Linux](https://img.shields.io/badge/Linux-✓-success?logo=linux&logoColor=white)
![macOS](https://img.shields.io/badge/macOS-✓-success?logo=apple&logoColor=white)
![Windows](https://img.shields.io/badge/Windows-✓-success?logo=windows&logoColor=white)

Part of the [unpins](https://unpins.org) catalog; install it with [`unpin`](https://github.com/unpins/unpin): `unpin install netcat`.

One binary (`netcat`) with `nc` as an alias (netcat does not switch on the command name — the alias just invokes the same binary).

## Usage

Run the `netcat` program with [unpin](https://github.com/unpins/unpin):

```bash
unpin netcat -l -p 1234            # listen on port 1234
unpin netcat example.com 80        # connect to a host:port
```

To install it onto your PATH:

```bash
unpin install netcat
```

Installing also creates the `nc` command alongside `netcat`.

## Build locally

```bash
nix build github:unpins/netcat
./result/bin/netcat --version
```

Or run directly:

```bash
nix run github:unpins/netcat -- --version
```

The first invocation will offer to add the [unpins.cachix.org](https://unpins.cachix.org) substituter so most pulls come pre-built.

## Manual download

The [Releases](https://github.com/unpins/netcat/releases) page has standalone binaries for manual download.

## Build notes

- **Platforms:** Linux, macOS, Windows.
- **GNU variant:** we ship GNU netcat 0.7.1, not the OpenBSD/traditional one — those need a `b64_ntop` libresolv shim to link static against musl, whereas GNU netcat builds clean static-musl and cross-compiles to mingw.
- **Windows:** mingw cross — a self-contained PE32+ `.exe`.
- **Man pages:** embedded in the binary, read with `unpin man netcat`.
