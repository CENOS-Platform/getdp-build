#!/usr/bin/env bash
# The C runtime every stage of this build must agree on.
#
# getdp.exe embeds python310.dll and links MKL and cuDSS - all MSVC-built, all on
# the Universal CRT (they import api-ms-win-crt-*.dll / ucrtbase). The Cygwin
# mingw-w64 cross-compiler defaults to the OLD msvcrt.dll instead. Nothing fails
# at link time, because the .lib files we link (python310.lib, mkl_rt.lib) are
# pure import libraries and need no CRT symbols - the mismatch only bites at run
# time, when a CRT-owned object crosses the boundary.
#
# It did bite: Python[...]{"script.py"} calls PyRun_SimpleFile(FILE*, ...), and a
# FILE* made by msvcrt's fopen is meaningless to ucrtbase's stdio. getdp.exe
# segfaulted with no message. The same hazard covers file descriptors,
# allocations (malloc here / free there), errno and locale state.
#
# -mcrtdll=ucrt swaps -lmsvcrt for -lucrt in gcc's own link spec (see
# `x86_64-w64-mingw32-gcc -dumpspecs`, the *libgcc: entry) and works for gcc, g++
# and gfortran. -D_UCRT puts the mingw headers in the matching mode. Both must be
# applied to EVERY stage: the whole static stack ends up inside getdp.exe, so one
# stage left on msvcrt reintroduces the split.
#
# CRT=msvcrt restores the old behaviour. Do not ship such a binary - it is what
# scripts/check_abi.sh rejects.

CRT=${CRT:-ucrt}
case "$CRT" in
  ucrt)   CRT_FLAGS="-D_UCRT -mcrtdll=ucrt" ;;
  msvcrt) CRT_FLAGS="" ;;
  *) echo "CRT must be 'ucrt' or 'msvcrt', got '$CRT'" >&2; exit 1 ;;
esac
export CRT CRT_FLAGS

# Every stage skips its work when its artifact already exists, so a resumed build
# will happily combine stages from before and after a CRT switch - which is how
# msvcrt.dll creeps back in, and how a hybrid binary was actually shipped. So each
# artifact is stamped with the CRT it was built with, and a stage that finds the
# wrong stamp stops the build then and there.
crt_stamp_path() { echo "$(dirname "$1")/.crt-stamp"; }
crt_record()     { echo "$CRT" > "$(crt_stamp_path "$1")" 2>/dev/null || true; }
crt_of()         { cat "$(crt_stamp_path "$1")" 2>/dev/null || echo unknown; }

# crt_require <artifact> <stage name>
#
# Call it where a stage is about to skip work because its artifact is already
# there. Returns for a matching stamp; otherwise prints why and exits.
#
# Stopping is not pedantry. Every stage is compiled into getdp.exe statically, so
# an msvcrt-compiled dependency does not just relink into a UCRT binary - it drags
# msvcrt-only symbols (__iob_func, __ms_vsnprintf, ...) along, and the link then
# resolves them by importing msvcrt.dll beside the UCRT. Deleting the artifact is
# not enough either: the object files under it were compiled in the other mode, so
# the stage has to be cleaned and built again. That is what FORCE=1 does.
#
# An unstamped artifact counts as a mismatch: stamping arrived with the UCRT
# switch, so anything without a stamp predates it and is msvcrt.
crt_require() {
  local artifact=$1 stage=${2:-$(basename "$1")} was
  was=$(crt_of "$artifact")
  if [ "$was" = "$CRT" ]; then
    echo "$stage already built (CRT=$was) - skipping."
    return 0
  fi
  {
    echo
    if [ "$was" = unknown ]; then
      echo "FAILED: $stage was built before CRT stamping existed, i.e. with msvcrt,"
      echo "        but this build is CRT=$CRT."
    else
      echo "FAILED: $stage was built with CRT=$was, but this build is CRT=$CRT."
    fi
    echo "  artifact: $artifact"
    echo
    echo "  These cannot be mixed - see scripts/crt.sh. The stage must be compiled"
    echo "  again, not just relinked, so removing the artifact by hand is not enough."
    echo
    echo "  Rebuild every stage with the current runtime:"
    echo "      FORCE=1 CRT=$CRT ./build.sh"
    echo
  } >&2
  exit 1
}
