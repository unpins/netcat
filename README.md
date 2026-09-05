# netcat

[OpenBSD netcat](https://salsa.debian.org/debian/netcat-openbsd) — the networking "Swiss-army knife": read and write data across TCP and UDP connections, over IPv4 and IPv6. A single self-contained binary, built natively for Linux, macOS, and Windows.

[![CI](https://github.com/unpins/netcat/actions/workflows/netcat.yml/badge.svg)](https://github.com/unpins/netcat/actions)
![Linux](https://img.shields.io/badge/Linux-✓-success?logo=linux&logoColor=white)
![macOS](https://img.shields.io/badge/macOS-✓-success?logo=apple&logoColor=white)
![Windows](https://img.shields.io/badge/Windows-✓-success?logo=windows&logoColor=white)

Part of the [unpins](https://unpins.org) catalog; install it with [`unpin`](https://github.com/unpins/unpin): `unpin install netcat`.

One binary. The program is `nc`; `netcat` runs the same thing.

## Usage

Run it with [unpin](https://github.com/unpins/unpin):

```bash
unpin netcat -l -p 1234              # listen on port 1234
unpin netcat example.com 80          # connect to a host and port
unpin netcat -6 ::1 8080             # over IPv6
unpin netcat -z -v example.com 20-25 # scan a port range
```

To install it onto your PATH:

```bash
unpin install netcat
```

Installing gives you both `nc` and `netcat`.

## Build locally

```bash
nix build github:unpins/netcat
./result/bin/nc -h
```

Or run directly:

```bash
nix run github:unpins/netcat -- -l -p 1234
```

The first invocation will offer to add the [unpins.cachix.org](https://unpins.cachix.org) substituter so most pulls come pre-built.

## Manual download

The [Releases](https://github.com/unpins/netcat/releases) page has standalone binaries for manual download.

## Coming from GNU netcat

Releases up to and including 0.7.1 shipped GNU netcat. This is the OpenBSD `nc`
that Linux distributions ship, so a few flags differ:

- **`-e cmd` is gone.** Upstream removed it: it hands a shell to whoever
  connects. Pipe a program in and out instead, or use `socat`.
- **`-L` (tunnel) is gone.** `-k` keeps listening for the next connection.
- **`-o` / `-x` no longer hex-dump.** `-x` is now the proxy address and `-O`
  the send buffer size; pipe through `xxd` or `hexdump -C` for a dump.
- **IPv6 works**, with `-6` to force it and `-4` to force IPv4.
- New: `-U` for unix sockets, `-X`/`-x` for SOCKS and HTTP proxies, `-k` to
  keep listening, `-T` for the IP type-of-service, `-q` for a linger timeout.

`-l`, `-p`, `-u`, `-w`, `-z`, `-v`, `-n`, `-s`, `-i` and `-r` mean what they
did before, including the `nc -l -p PORT` spelling.

## Build notes

- **Platforms:** Linux (x86_64, i686, ARM64, ARM 32-bit, POWER, RISC-V), macOS (Intel and Apple Silicon), Windows.
- **Windows:** through [Cosmopolitan](https://github.com/jart/cosmopolitan), not mingw — `nc` is a BSD-sockets program and mingw has no `<sys/socket.h>` (Winsock uses a different API), so the cross fails outright. Cosmopolitan's libc supplies the POSIX sockets layer.
- **Portability shims:** the Debian sources are written for Linux with libbsd. Three small pieces are supplied here — `b64_ntop` (proxy authentication, absent from musl and Cosmopolitan), the socket flags macOS does not have (`SOCK_CLOEXEC`, `SOCK_NONBLOCK`, `accept4`), and `strtonum` plus `arc4random_uniform` for the Cosmopolitan build, which does not link libbsd at all.
- **Man pages:** embedded in the binary, read with `unpin man netcat`.
