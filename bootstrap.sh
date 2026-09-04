#!/usr/bin/env bash
# Clone/refresh the pinned sources. Run once from a Cygwin login shell.
set -e
cd "$(dirname "$0")"
git submodule update --init --recursive --depth 1
echo
echo "Sources ready under src/. Next:"
echo "  export ROOT=\$(pwd)/src"
echo "  export MKL=/cygdrive/d/source/cenos/backend/bin/Library   # adjust"
echo "  ./scripts/build_metis_only.sh && ./scripts/build_mkl_petsc.sh"
echo "  ./scripts/build_getdp_arch.sh complex_mkl_metis build_best \$MKL/lib/mkl_rt.lib"
