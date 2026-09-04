#!/usr/bin/env bash
# Chain all remaining solver-variant builds. Run after build_metis_petsc.sh
# has produced the complex_mumps_metis arch.
set -e
ROOT=${ROOT:-/cygdrive/d/source/for_getdp_build}
OB=$ROOT/OpenBLAS/libopenblas.a
MKL=${MKL:-/cygdrive/d/source/cenos/backend/bin/Library}
MKLLIBS="$MKL/lib/mkl_intel_lp64_dll.lib;$MKL/lib/mkl_intel_thread_dll.lib;$MKL/lib/mkl_core_dll.lib;$MKL/lib/libiomp5md.lib"

echo "############ 1/3  GetDP -> complex_mumps_metis (MUMPS+METIS, OpenBLAS)"
$ROOT/build_getdp_arch.sh complex_mumps_metis build_metis "$OB"

echo "############ 2/3  PETSc arch complex_mkl_metis (MKL BLAS + PARDISO + MUMPS/METIS)"
$ROOT/build_mkl_petsc.sh

echo "############ 3/3  GetDP -> complex_mkl_metis"
$ROOT/build_getdp_arch.sh complex_mkl_metis build_mkl "$MKLLIBS"

echo "ALL_BUILDS_DONE"
