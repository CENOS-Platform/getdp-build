#!/usr/bin/env bash
set -e
ROOT=${ROOT:-/cygdrive/d/source/for_getdp_build}
MKL=${MKL:-/cygdrive/d/source/cenos/backend/bin/Library}
echo "############ PETSc arch complex_mkl_metis"
$ROOT/build_mkl_petsc.sh
echo "############ GetDP -> complex_mkl_metis"
$ROOT/build_getdp_arch.sh complex_mkl_metis build_mkl "$MKL/lib/mkl_rt.lib"
echo "ALL_MKL_DONE"
