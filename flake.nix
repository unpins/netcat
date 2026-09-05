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
      # musl and cosmopolitan have no b64_ntop -- it is a BIND/libresolv
      # extension that glibc and the BSDs declare in <resolv.h>. socks.c is the
      # only caller (Basic auth for an HTTP CONNECT proxy), and the missing
      # function is precisely what kept this package on GNU netcat.
      #
      # The <resolv.h> include goes with it: b64_ntop is the only thing socks.c
      # ever wanted from that header, and the darwin static SDK does not ship
      # one at all.
      b64Shim = ''
        cp ${./unpin-b64.h} unpin-b64.h
        substituteInPlace socks.c \
          --replace-fail '#include <resolv.h>' '#include "unpin-b64.h"'
      '';
      # Debian's port is written for Linux + libbsd. unpin-bsd-compat.h fills
      # what each of our other platforms is missing; on Linux every block in it
      # compiles away.
      compatShim = ''
        cp ${./unpin-bsd-compat.h} unpin-bsd-compat.h
      '';
      # linux + darwin: libbsd is there, the socket flags are not (macOS has no
      # SOCK_CLOEXEC, SOCK_NONBLOCK or accept4, and no IPTOS_LOWCOST). macOS
      # also has readpassphrase in its own libc, so libbsd there ships no
      # <bsd/readpassphrase.h> to include. socks.c gets <bsd/string.h> too --
      # it calls explicit_bzero, which netcat.c only sees because IT includes
      # that header, and the macOS SDK declares no explicit_bzero of its own.
      nativePatch = b64Shim + compatShim + ''
        # Nothing links libresolv now that b64_ntop is ours -- and the darwin
        # SDK has no libresolv.a to find.
        substituteInPlace Makefile \
          --replace-fail '--libs libbsd` -lresolv' '--libs libbsd`'
        substituteInPlace netcat.c \
          --replace-fail '#include <bsd/string.h>' '#include <bsd/string.h>
#include "unpin-bsd-compat.h"'
        substituteInPlace socks.c \
          --replace-fail '#include <bsd/readpassphrase.h>' '#ifdef __APPLE__
#include <readpassphrase.h>
#else
#include <bsd/readpassphrase.h>
#endif
#include <bsd/string.h>'
      '';
      # cosmo: libbsd does not build there at all (its <bsd/libutil.h> falls
      # over on __END_DECLS), and cosmo's own libc already has strlcpy,
      # strlcat, explicit_bzero and readpassphrase. What is left of
      # <bsd/stdlib.h> is strtonum and arc4random_uniform, which the compat
      # header supplies under UNPIN_NO_LIBBSD.
      cosmoPatch = b64Shim + compatShim + ''
        substituteInPlace netcat.c \
          --replace-fail '#include <bsd/stdlib.h>' '#include "unpin-bsd-compat.h"' \
          --replace-fail '#include <bsd/string.h>' '/* strlcpy: see unpin-bsd-compat.h */' \
          --replace-fail '#include <arpa/telnet.h>' '/* cosmo has no arpa/telnet.h -- see unpin-bsd-compat.h */'
        substituteInPlace socks.c \
          --replace-fail '#include <bsd/readpassphrase.h>' '#include "unpin-bsd-compat.h"'
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
      # Windows stays on cosmo below (engine covers Linux + darwin only).
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
      windowsBuild = pkgs:
        ((lib.cosmoStaticCross pkgs).netcat-openbsd.overrideAttrs (oa: {
          buildInputs = [ ];
          # UNPIN_NO_LIBBSD turns on the libbsd half of unpin-bsd-compat.h --
          # a flag and not a #define in the source, since both netcat.c and
          # socks.c need it. _BSD_SOURCE is what puts strlcpy, strlcat and
          # explicit_bzero in cosmo's own headers -- they sit behind it there,
          # and socks.c otherwise stops on "implicit declaration of function".
          NIX_CFLAGS_COMPILE = "-DUNPIN_NO_LIBBSD=1 -D_BSD_SOURCE=1";
          postPatch = (oa.postPatch or "") + cosmoPatch;
          # The Makefile asks pkg-config for libbsd and adds -lresolv; with
          # libbsd gone there is nothing to link but the objects themselves.
          makeFlags = (oa.makeFlags or [ ]) ++ [ "LIBS=" ];
          postInstall = (oa.postInstall or "") + manBoth;
        }));
    };
}
