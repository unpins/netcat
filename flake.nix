{
  description = "OpenBSD netcat (nc + netcat) as a single self-contained binary";

  nixConfig = {
    extra-substituters = [ "https://unpins.cachix.org" ];
    extra-trusted-public-keys = [ "unpins.cachix.org-1:DDaShjbZ8VvcqxeTcAU3kV9vxZQBlyb7V/uLBHfTynI=" ];
  };

  inputs.unpins-lib.url = "github:unpins/nix-lib";

  # OpenBSD netcat, as Debian ships it (netcat-openbsd 1.234). It replaces GNU
  # netcat 0.7.1, which is from 2004 and has NO IPv6 at all -- `nc ::1 22` there
  # answers `Couldn't resolve host`, on a binary whose whole job is speaking to
  # a host. This variant is the `nc` most systems mean, and the one the manual
  # documents.
  #
  # One binary. `nc` is the program (that is the name upstream, the man page and
  # the usage line all use); `netcat` stays as an alias so the old name keeps
  # working.
  #
  # Windows via Cosmopolitan, NOT mingw: nc is a BSD-sockets program
  # (`#include <sys/socket.h>`) and the mingw cross has no `<sys/socket.h>`
  # (Winsock is a different header and API). cosmocc provides the POSIX sockets
  # layer for a single .exe.
  outputs = { self, unpins-lib }:
    let
      lib = unpins-lib.lib;
      # The source edits live in ./*.patch, each with its reason in the header.
      # They are applied in postPatch, after nixpkgs' own postPatch has run the
      # Debian series: `patches =` would apply them before it, against a tree
      # they do not match.
      #
      # b64.patch: musl and cosmopolitan have no b64_ntop, the missing function
      # that kept this package on GNU netcat.
      b64Shim = ''
        cp ${./unpin-b64.h} unpin-b64.h
        patch -p1 < ${./b64.patch}
      '';
      # Debian's port is written for Linux + libbsd. unpin-bsd-compat.h fills
      # what each of our other platforms is missing; on Linux every block in it
      # compiles away.
      compatShim = ''
        cp ${./unpin-bsd-compat.h} unpin-bsd-compat.h
      '';
      # linux + darwin: libbsd is there, the socket flags are not.
      nativePatch = b64Shim + compatShim + ''
        patch -p1 < ${./native.patch}
      '';
      # cosmo: no libbsd at all.
      cosmoPatch = b64Shim + compatShim + ''
        patch -p1 < ${./cosmo.patch}
      '';
      manBoth = ''
        cp $out/share/man/man1/nc.1 $out/share/man/man1/netcat.1
      '';
    in
    lib.mkStandaloneFlake {
      inherit self;
      name = "netcat";
      binName = "nc";
      # nc takes a hostname; on a host with no reachable resolver (Android, a
      # barebones container) musl's getaddrinfo just fails. Opt into the
      # catalog's DNS fallback, which stays dormant until the user configures
      # one -- same as curl/links/rsync/whois.
      dnsFallback = true;
      # There is no --version: the usage line is what the program prints about
      # itself. The pattern pins the `-46` in it, which is the point of this
      # variant -- the flag GNU netcat never had.
      smoke = [ "-h" ];
      smokePattern = "usage: nc \\[-46";

      # Build via the unpin-llvm engine + emit a bitcode multicall module.
      # The engine compiles every Linux arch with `clang -target` (no nixpkgs
      # gcc cross toolchain, no qemu) and self-folds darwin the same way;
      # Windows stays on cosmo (cosmo.nix), which has the POSIX sockets nc needs.
      engine = "unpin-llvm";
      multicall = {
        inferLinkInputs = true;
        programs = [{
          name = "nc";
          # The page installs as nc.1; `netcat` is documented by the same page,
          # which the build installs under both names.
          aliases = [ "netcat" ];
        }];
      };
      pkgsAttr = "netcat-openbsd";
      build = pkgs:
        (pkgs.pkgsStatic.netcat-openbsd.overrideAttrs (oa: {
          postPatch = (oa.postPatch or "") + nativePatch;
          # The Makefile hard-codes `-Wl,--no-add-needed`, an ELF-only flag
          # ld64 refuses outright. It says nothing for a static link anyway.
          makeFlags = (oa.makeFlags or [ ])
            ++ pkgs.lib.optionals pkgs.stdenv.hostPlatform.isDarwin [ "LDFLAGS=" ];
          postInstall = (oa.postInstall or "") + manBoth;
          # nixpkgs marks the package broken on darwin, and it is: the Debian
          # port reaches for SOCK_CLOEXEC, SOCK_NONBLOCK and accept4(), none of
          # which macOS has. unpin-bsd-compat.h supplies all three, so the
          # reason no longer holds here -- cleared only for this build, and
          # only because the darwin binary is built and smoke-tested.
          meta = (oa.meta or { }) // { broken = false; };
        }));
      windowsBuild = import ./cosmo.nix { inherit lib cosmoPatch manBoth; };
    };
}
