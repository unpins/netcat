# Changelog

## [Unreleased]

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
