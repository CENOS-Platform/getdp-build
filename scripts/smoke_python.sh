#!/usr/bin/env bash
# Run the embedded interpreter through both Python[] forms.
#   smoke_python.sh <path-to-getdp.exe>
#
# `getdp.exe -info` only proves the binary loads its DLLs. It passed for months
# on a build whose Python[...]{"script.py"} path segfaulted on the first call -
# nothing in the build ever executed an embedded-Python path. This does, in about
# a tenth of a second, on one triangle.
#
# PATH must already carry python310.dll and the MKL DLLs; the caller sets that up.
set -e
EXE=${1:?usage: smoke_python.sh <getdp.exe>}
HERE=$(cd "$(dirname "$0")/../tests/python_smoke" && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
cp "$HERE"/smoke.pro "$HERE"/smoke.msh "$HERE"/smoke.py "$WORK/"

cd "$WORK"
set +e
out=$("$EXE" smoke.pro -msh smoke.msh -solve smoke 2>&1)
rc=$?
set -e

ok_expr=$(echo "$out" | grep -c "PYSMOKE expr 42" || true)
ok_file=$(echo "$out" | grep -c "PYSMOKE file 42" || true)

if [ "$rc" -ne 0 ] || [ "$ok_expr" -eq 0 ] || [ "$ok_file" -eq 0 ]; then
  echo "smoke_python: FAIL (exit $rc)" >&2
  [ "$ok_expr" -eq 0 ] && echo "  Python[...]{\"<expression>\"} did not return 42" >&2
  if [ "$ok_file" -eq 0 ]; then
    echo "  Python[...]{\"smoke.py\"} did not return 42" >&2
    if [ "$rc" -eq 139 ] || [ "$rc" -gt 128 ]; then
      echo "  the binary died running the script FILE. This is the msvcrt/UCRT split:" >&2
      echo "  F_Python fopen()s the script and hands the FILE* to PyRun_SimpleFile()" >&2
      echo "  inside python310.dll. Check scripts/crt.sh and run scripts/check_abi.sh." >&2
    fi
  fi
  echo >&2
  echo "$out" | tail -20 | sed 's/^/  | /' >&2
  exit 1
fi
echo "smoke_python: OK (both Python[] forms returned 42)"
