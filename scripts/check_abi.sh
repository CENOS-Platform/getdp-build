#!/usr/bin/env bash
# Assert the invariants that hold a shippable getdp.exe together.
#   check_abi.sh <path-to-getdp.exe>
#
# These are cheap import-table facts. They are checked because each one has
# already been violated by a build that otherwise looked completely successful.
set -e
EXE=${1:?usage: check_abi.sh <getdp.exe>}
[ -f "$EXE" ] || { echo "check_abi: no such file: $EXE" >&2; exit 1; }
# absolute, so the caller can pass a relative path from any directory
EXE=$(cd "$(dirname "$EXE")" && pwd)/$(basename "$EXE")

imports=$(objdump -p "$EXE" | sed -n 's/^	DLL Name: //p' | tr 'A-Z' 'a-z' | sort -u)
fail=0
note() { echo "check_abi: FAIL - $*" >&2; fail=1; }

# 1. One C runtime, and it must be the Universal CRT.
#    msvcrt.dll here means the binary disagrees with python310.dll, the MKL DLLs
#    and the CUDA/cuDSS DLLs, all of which are MSVC/UCRT. See scripts/crt.sh.
if echo "$imports" | grep -qx "msvcrt.dll"; then
  note "getdp.exe imports msvcrt.dll, but every DLL it loads is on the Universal CRT."
  note "  a FILE*, fd, allocation or errno crossing that boundary is undefined behaviour"
  note "  -> build with CRT=ucrt (the default); see scripts/crt.sh"
  # Which symbols came from the wrong CRT says where the damage is and, usually,
  # which stage is stale. fopen/fclose is the Python[]{"file.py"} segfault itself;
  # malloc/free is a corrupted heap; __iob_func or __ms_* means some stage was
  # still compiled with the msvcrt headers, not just linked against them.
  from_msvcrt=$(objdump -p "$EXE" | awk '
    /DLL Name:/ { inblk = ($NF == "msvcrt.dll"); next }
    inblk && $1 ~ /^[0-9a-f]+$/ { print $NF }' | sort -u)
  telling=$(echo "$from_msvcrt" | grep -xE 'fopen|fclose|fread|fwrite|malloc|free|calloc|realloc|_fdopen|_fileno|__iob_func|_errno|__ms_.*' | tr '\n' ' ')
  note "  $(echo "$from_msvcrt" | grep -c .) symbols bound to msvcrt.dll${telling:+, including: $telling}"
fi
if ! echo "$imports" | grep -q "^api-ms-win-crt-stdio"; then
  note "getdp.exe does not import the Universal CRT (api-ms-win-crt-stdio-*)."
fi

# 2. -static must not have been dropped. If it is, these appear and the binary
#    needs compiler DLLs beside it that we do not ship.
for dll in libgcc_s_seh-1.dll libstdc++-6.dll libgfortran-5.dll            libquadmath-0.dll libwinpthread-1.dll; do
  if echo "$imports" | grep -qx "$dll"; then
    note "getdp.exe imports $dll - the -static link flag was lost."
  fi
done

# 3. A build asked for embedded Python must actually have it linked.
if [ -n "${PY:-}" ] && ! echo "$imports" | grep -qx "python310.dll"; then
  note "PY was set but getdp.exe does not import python310.dll."
fi

if [ "$fail" -ne 0 ]; then
  echo >&2
  echo "check_abi: import table was:" >&2
  echo "$imports" | sed 's/^/  /' >&2
  exit 1
fi
echo "check_abi: OK ($(echo "$imports" | grep -c . ) imported DLLs, Universal CRT, static runtimes)"
