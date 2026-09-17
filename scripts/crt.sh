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
