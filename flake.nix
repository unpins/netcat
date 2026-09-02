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

      # Build via the unpin-llvm engine + emit a bitcode multicall module.
      # The engine compiles every Linux arch with `clang -target` (no nixpkgs
      # gcc cross toolchain, no qemu) and self-folds darwin the same way;
      # Windows stays on cosmo below (engine covers Linux + darwin only).
      engine = "unpin-llvm";
      multicall = {
        inferLinkInputs = true;
        programs = [{
          name = "netcat";
          # The page installs as netcat.1; there is no nc.1.
          aliases = [ { name = "nc"; noMan = true; } ];
        }];
      };
      # Upstream nixpkgs attr is `netcat-gnu` (binary is `netcat`); name it so
      # the engine's stdenv override targets the attr `build` actually uses.
      pkgsAttr = "netcat-gnu";
      build = pkgs:
        (pkgs.pkgsStatic.netcat-gnu.overrideAttrs (_: {
            # GNU netcat 0.7.1's configure is autoconf-2.13-era (2003) and
            # predates --docdir/--localedir. The engine adds a `module` output,
            # which flips nixpkgs' multiple-outputs hook out of its single-output
            # early-return and makes it pass those dir flags → configure aborts
            # ("unrecognized option: --docdir"). setOutputFlags=false stops the
            # hook emitting any --*dir; --prefix alone still installs into $out.
            setOutputFlags = false;
          }));
      windowsBuild = pkgs:
        (lib.cosmoStaticCross pkgs).netcat-gnu;
    };
}
