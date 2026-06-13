{
  description = "GNU netcat (netcat + nc) as a single self-contained binary";

  nixConfig = {
    extra-substituters = [ "https://unpins.cachix.org" ];
    extra-trusted-public-keys = [ "unpins.cachix.org-1:DDaShjbZ8VvcqxeTcAU3kV9vxZQBlyb7V/uLBHfTynI=" ];
  };

  inputs.unpins-lib.url = "github:unpins/nix-lib";

  # GNU netcat 0.7.1. We ship the GNU variant (not OpenBSD/traditional) because
  # those don't link static against musl without a libresolv b64_ntop shim,
  # whereas GNU netcat builds clean static-musl.
  # One binary (`netcat`) with `nc` as an UNPIN_META alias (netcat doesn't
  # switch on argv[0] — the alias just invokes the same binary).
  #
  # Windows via Cosmopolitan, NOT mingw: GNU netcat is a BSD-sockets program
  # (`#include <sys/socket.h>`), and the mingw cross has no `<sys/socket.h>`
  # (Winsock uses a different header/API) → fails at `core.c`. cosmocc provides
  # the POSIX sockets layer for a single .exe.
  outputs = { self, unpins-lib }:
    let lib = unpins-lib.lib;
    in
    lib.mkStandaloneFlake {
      inherit self;
      name = "netcat";
      binName = "netcat";
      smoke = [ "--version" ];
      smokePattern = "GNU Netcat";
      build = pkgs:
        lib.withAliases pkgs { primary = "netcat"; aliases = [ "nc" ]; }
          pkgs.pkgsStatic.netcat-gnu;
      windowsBuild = pkgs:
        lib.withAliases pkgs { primary = "netcat.exe"; aliases = [ "nc" ]; }
          (lib.cosmoStaticCross pkgs).netcat-gnu;
    };
}
