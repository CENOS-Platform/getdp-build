#!/usr/bin/env bash
# Build a SECOND PETSc arch that adds METIS to MUMPS. The existing
# complex_mumps_seq arch is left completely untouched.
#
# METIS is built separately by build_metis_only.sh, because PETSc's
# --download-metis fails here on two counts with the Cygwin toolchain:
#   1. PETSc hardcodes -G "MSYS Makefiles" (config/BuildSystem/config/package.py:1989)
#      and Cygwin's cmake only has "Unix Makefiles";
#   2. cmake 4.2 rejects METIS's cmake_minimum_required(VERSION 2.8), needing
#      -DCMAKE_POLICY_VERSION_MINIMUM=3.5;
#   3. mingw has no POSIX <regex.h>, needing -DUSE_GKREGEX for GKlib.
set -e
export PATH=/usr/x86_64-w64-mingw32/sys-root/mingw/bin:$PATH
ROOT=${ROOT:-/cygdrive/d/source/for_getdp_build}
export PETSC_DIR=$ROOT/petsc
export PETSC_ARCH=complex_mumps_metis
cd $PETSC_DIR

./configure CC=x86_64-w64-mingw32-gcc CXX=x86_64-w64-mingw32-g++ \
  FC=x86_64-w64-mingw32-gfortran PETSC_ARCH=$PETSC_ARCH \
  --with-debugging=0 \
  --with-mpi=0 --with-mpiuni-fortran-binding=0 --with-fortran-bindings=0 \
  --with-mumps-serial \
  --download-mumps=$ROOT/pkg-mumps --download-mumps-commit=HEAD \
  --with-metis-include=$ROOT/metis-mingw/include \
  --with-metis-lib=$ROOT/metis-mingw/lib/libmetis.a \
  --with-shared-libraries=0 --with-x=0 --with-ssl=0 \
  --with-scalar-type=complex --with-openmp=1 \
  --with-blas-lib=$ROOT/OpenBLAS/libopenblas.a \
  --with-lapack-lib=$ROOT/lapack/build/lib/liblapack.a \
  --download-sowing=yes \
  COPTFLAGS="-O3 -static -static-libgcc -static-libstdc++" \
  CXXOPTFLAGS="-O3 -static -static-libgcc -static-libstdc++" \
  FOPTFLAGS="-O3 -static -static-libgfortran"

make PETSC_DIR=$PETSC_DIR PETSC_ARCH=$PETSC_ARCH all

echo "=== ORDERINGS in the new MUMPS build ==="
grep -E '^ORDERINGSF' $PETSC_DIR/$PETSC_ARCH/externalpackages/git.mumps/Makefile.inc
echo "PETSC_METIS_BUILD_DONE"
