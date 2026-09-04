#!/usr/bin/env bash
# Renormalize submodule checkouts to LF.
#
# git on Windows defaults to core.autocrlf=true and checks the submodules out
# with CRLF, which breaks their shell scripts and makefiles:
#   ./c_check: line 2: $'\r': command not found
# Called automatically by build.sh; safe to run by hand. Refuses to act if a
# submodule has changes beyond the line endings.
set -e
cd "$(dirname "$0")/.."

grep -qU $'\r' src/OpenBLAS/c_check 2>/dev/null || { echo "line endings OK"; exit 0; }

echo "submodules were checked out with CRLF - renormalizing to LF"
# A CRLF worktree reads as "every file modified" under a git whose autocrlf
# differs from the one that cloned it, so ask whether anything differs beyond
# the CRs. --name-only ignores whitespace flags; --quiet honours them.
echo "  checking for real local edits (~30 s)"
real=$(git submodule foreach --quiet 'git -c core.autocrlf=false diff --ignore-cr-at-eol --quiet || echo "  $name"; git -c core.autocrlf=false diff --cached --ignore-cr-at-eol --quiet || echo "  $name (staged)"')
if [ -n "$real" ]; then
  echo "  real changes in a submodule - not touching them:"
  echo "$real"
  echo "  commit or stash them, then re-run this script."
  exit 1
fi

git config core.autocrlf false
git config core.eol lf
git submodule foreach --recursive --quiet 'git config core.autocrlf false; git config core.eol lf; git rm --cached -r . >/dev/null; git reset --hard -q'

if grep -qU $'\r' src/OpenBLAS/c_check 2>/dev/null; then
  echo "  FAILED - still CRLF"; exit 1
fi
echo "  done"
