#!/usr/bin/env bash
# Fetch the pinned sources into src/. Run once, from a Cygwin login shell.
set -e
cd "$(dirname "$0")"
git submodule update --init --recursive
echo "Sources ready in src/ at the pinned commits. Now run ./build.sh"
