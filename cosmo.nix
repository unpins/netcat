# netcat via cosmoStaticCross for Windows-x86_64. The source edits (cosmoPatch)
# and the man-page copy (manBoth) are shared with the native build in flake.nix.
{ lib, cosmoPatch, manBoth }:
pkgs:
(lib.cosmoStaticCross pkgs).netcat-openbsd.overrideAttrs (oa: {
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
})
