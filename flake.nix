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
    let
      lib = unpins-lib.lib;
      # netcat_flag_count() counts the ports asked for by shifting each byte of
      # the flagset left and adding up the top bit -- as `ret -= (c >> 7)` on a
      # plain `char`. That is only a count where `char` is SIGNED: the shift is
      # arithmetic there, the top bit reads back as -1, and subtracting it adds
      # one. Where `char` is unsigned -- aarch64, armv7l, ppc64le and riscv64,
      # four of the nine targets we publish -- the same shift yields +1 and the
      # count comes back NEGATIVE. (Not aarch64-darwin: Apple's arm64 keeps
      # `char` signed, unlike AAPCS64 -- measured on the Mac, where clang
      # defines no __CHAR_UNSIGNED__ for -arch arm64.)
      #
      # It fails silently and completely: `total_ports` is then -1, so the
      # `== 0` guard that would have printed "No ports specified" does not fire,
      # `left_ports = -1` makes `while (left_ports > 0)` skip every port, and
      # netcat exits 1 having never called socket(). Measured: `--version` and
      # `--help` work, and every connect, listen and scan does nothing at all.
      # Only `--version` is smoked in CI, which is why this shipped.
      #
      # Cast to unsigned before the shift and add: same count on either kind of
      # char, no dependence on the sign of a plain `char` at all.
      flagCountFix = ''
        substituteInPlace src/flagset.c \
          --replace-fail 'ret -= (c >> 7);' 'ret += (((unsigned char) c) >> 7);'
      '';
    in
    lib.mkStandaloneFlake {
      inherit self;
      name = "netcat";
      binName = "netcat";
      # netcat takes a hostname; on a host with no reachable resolver (Android,
      # a barebones container) musl's getaddrinfo just fails. Opt into the
      # catalog's DNS fallback, which stays dormant until the user configures
      # one -- same as curl/links/rsync/whois.
      dnsFallback = true;
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
        (pkgs.pkgsStatic.netcat-gnu.overrideAttrs (oa: {
            postPatch = (oa.postPatch or "") + flagCountFix;
            # Off, and measured: `make check` walks every subdirectory and
            # every one says "Nothing to be done". GNU netcat 0.7.1 (2004)
            # ships no tests at all — automake generates the target, the
            # tarball has nothing for it to run. Leaving doCheck on would look
            # like coverage and be a no-op.
            doCheck = false;
            # GNU netcat 0.7.1's configure is autoconf-2.13-era (2003) and
            # predates --docdir/--localedir. The engine adds a `module` output,
            # which flips nixpkgs' multiple-outputs hook out of its single-output
            # early-return and makes it pass those dir flags → configure aborts
            # ("unrecognized option: --docdir"). setOutputFlags=false stops the
            # hook emitting any --*dir; --prefix alone still installs into $out.
            setOutputFlags = false;
          }));
      windowsBuild = pkgs:
        ((lib.cosmoStaticCross pkgs).netcat-gnu.overrideAttrs (oa: {
          # x86_64 has a signed char, so this target was never broken -- applied
          # anyway so every artifact is built from the same source.
          postPatch = (oa.postPatch or "") + flagCountFix;
        }));
    };
}
