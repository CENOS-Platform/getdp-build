#!/usr/bin/env bash
# Full build of the recommended GetDP (MUMPS/METIS + MKL PARDISO).
# Cygwin login shell, after: git submodule update --init --recursive
#     MKL=/cygdrive/d/source/cenos/backend/bin/Library ./build.sh
set -e
cd "$(dirname "$0")"
export ROOT="$(pwd)/src"
export MKL="${MKL:-/cygdrive/d/source/cenos/backend/bin/Library}"
[ -f "$MKL/lib/mkl_rt.lib" ] || { echo "mkl_rt.lib not under $MKL - set MKL=..."; exit 1; }

./scripts/build_deps.sh                    # OpenBLAS, LAPACK, gmsh
./scripts/build_metis_only.sh              # METIS
./scripts/build_mkl_petsc.sh               # PETSc arch complex_mkl_metis
./scripts/build_getdp_arch.sh complex_mkl_metis build_best "$MKL/lib/mkl_rt.lib"

echo
echo "Built: $ROOT/cenos-getdp-fork/build_best/getdp.exe"
