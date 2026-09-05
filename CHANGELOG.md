# Changelog

## [Unreleased]

### Changed

- **This is now OpenBSD netcat, not GNU netcat.** GNU netcat 0.7.1 is from
  2004 and has no IPv6 at all: `netcat ::1 80` answers `Couldn't resolve host`,
  on a program whose entire job is talking to a host. The `nc` that Linux
  distributions ship is the OpenBSD one, and that is what this is now.

  The program is `nc`; `netcat` still runs it. `-l`, `-p`, `-u`, `-w`, `-z`,
  `-v`, `-n`, `-s`, `-i` and `-r` keep their meanings, `nc -l -p PORT`
  included. Four things move:

  - `-e cmd` is gone. Upstream removed it — it hands a shell to whoever
    connects.
  - `-L` (tunnel) is gone; `-k` keeps listening for the next connection.
  - `-o` and `-x` no longer hex-dump. `-x` is now the proxy address, `-O` the
    send buffer size.
  - IPv6 works, with `-6` and `-4` to force a family. Also new: `-U` for unix
    sockets, `-X`/`-x` for SOCKS and HTTP proxies, `-T` for the type-of-service
    byte, `-q` for a linger timeout.

  The README has the full list.

### Fixed

- netcat did nothing at all on ARM64, ARM 32-bit, POWER and RISC-V. Every
  connection, listen and port scan exited straight away, without a message and
  without opening a socket; only `--version` and `--help` worked. The count of
  ports to try came back negative on those machines, so the loop that opens
  connections ran zero times.
- On Linux, hostnames now resolve on a machine whose DNS resolver is missing or
  unreachable — Android, or a container with no `/etc/resolv.conf` — once you
  point unpins at a name server. Before, `netcat <host> <port>` stopped at
  `Couldn't resolve host` without opening a connection.
