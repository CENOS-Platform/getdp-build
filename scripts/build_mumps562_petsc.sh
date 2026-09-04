#!/usr/bin/env bash
# Fifth PETSc arch: newer MUMPS (5.6.2, the version PETSc 3.21.1 targets) with
# METIS, still sequential. The local pkg-mumps clone is pinned at 5.4.1, so this
# one lets PETSc fetch the 5.6.2 tarball instead. MUMPS 5.5/5.6 improved the
# shared-memory (L0 tree) threading, which is exactly what measured flat here.
set -e
export PATH=/usr/x86_64-w64-mingw32/sys-root/mingw/bin:$PATH
ROOT=${ROOT:-/cygdrive/d/source/for_getdp_build}
export PETSC_DIR=$ROOT/petsc
export PETSC_ARCH=complex_mumps562
cd $PETSC_DIR

./configure CC=x86_64-w64-mingw32-gcc CXX=x86_64-w64-mingw32-g++ \
  FC=x86_64-w64-mingw32-gfortran PETSC_ARCH=$PETSC_ARCH \
  --with-debugging=0 \
  --with-mpi=0 --with-mpiuni-fortran-binding=0 --with-fortran-bindings=0 \
  --with-mumps-serial \
  --download-mumps \
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
echo "=== MUMPS version built ==="
grep -m1 MUMPS_VERSION $PETSC_DIR/$PETSC_ARCH/include/zmumps_c.h 2>/dev/null || \
  grep -rm1 "define MUMPS_VERSION" $PETSC_DIR/$PETSC_ARCH/externalpackages/*/include/*.h 2>/dev/null
echo "PETSC_MUMPS562_BUILD_DONE"
