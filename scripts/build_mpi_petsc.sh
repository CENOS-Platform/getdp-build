#!/usr/bin/env bash
# Fourth PETSc arch: real MPI-parallel MUMPS via MS-MPI + MKL ScaLAPACK/BLACS.
# This is the configuration that gives MUMPS actual tree-level parallelism
# (independent subtrees on separate ranks), which the sequential build lacks.
#
# MS-MPI SDK extracted from msmpisdk.msi via "msiexec /a" (no system install).
# msmpifec.lib (Fortran, exports mpi_init_) must precede msmpi.lib: its
# mpifbind.obj references __imp_mpi_*__ from msmpi.lib, and ld discards
# msmpi.lib if it comes first -> misleading "mpi_init() could not be located".
# ScaLAPACK/BLACS from MKL. Only a generic mkl_blacs_lp64_dll.lib exists (no
# msmpi variant); the MPI flavour is chosen at runtime via MKL_BLACS_MPI=MSMPI.
#
# Keep LF-only: CRLF silently breaks the backslash line-continuations.
set -e
ROOT=${ROOT:-/cygdrive/d/source/for_getdp_build}
MKL=${MKL:-/cygdrive/d/source/cenos/backend/bin/Library}
# Flattened copy of the extracted SDK: the original path contains a space
# ("Microsoft SDKs"), and mpif.h does INCLUDE 'mpifptr.h' which lives in the
# arch subdirectory Include/x64 - so both include dirs must be on the path.
MPISDK="$ROOT/msmpi/flat"
# MKL DLLs must be on PATH so PETSc's runtime probes can launch (see build_mkl_petsc.sh)
export PATH=/usr/x86_64-w64-mingw32/sys-root/mingw/bin:$MKL/bin:/cygdrive/d/source/cenos/backend/bin:$PATH
export PETSC_DIR=$ROOT/petsc
export PETSC_ARCH=complex_mpi_mumps
cd $PETSC_DIR

./configure CC=x86_64-w64-mingw32-gcc CXX=x86_64-w64-mingw32-g++ \
  FC=x86_64-w64-mingw32-gfortran PETSC_ARCH=$PETSC_ARCH \
  --with-debugging=0 \
  --with-mpi=1 \
  --with-mpi-include="[$MPISDK/include,$MPISDK/include/x64]" \
  --with-mpi-lib="[$MPISDK/lib/msmpifec.lib,$MPISDK/lib/msmpi.lib]" \
  --known-mpi-shared-libraries=1 \
  --with-fortran-bindings=0 \
  --download-mumps=$ROOT/pkg-mumps --download-mumps-commit=HEAD \
  --with-metis-include=$ROOT/metis-mingw/include \
  --with-metis-lib=$ROOT/metis-mingw/lib/libmetis.a \
  --with-scalapack-lib="[$MKL/lib/mkl_scalapack_lp64_dll.lib,$MKL/lib/mkl_blacs_lp64_dll.lib]" \
  --with-shared-libraries=0 --with-x=0 --with-ssl=0 \
  --with-scalar-type=complex --with-openmp=1 \
  --with-blaslapack-include=$MKL/include \
  --with-blaslapack-lib=$MKL/lib/mkl_rt.lib \
  --download-sowing=yes \
  COPTFLAGS="-O3 -static -static-libgcc -static-libstdc++" \
  CXXOPTFLAGS="-O3 -static -static-libgcc -static-libstdc++" \
  FOPTFLAGS="-O3 -static -static-libgfortran"

make PETSC_DIR=$PETSC_DIR PETSC_ARCH=$PETSC_ARCH all
echo "=== config summary ==="
grep -E "PETSC_HAVE_MUMPS|PETSC_HAVE_SCALAPACK|PETSC_HAVE_METIS" $PETSC_DIR/$PETSC_ARCH/include/petscconf.h || true
echo "PETSC_MPI_BUILD_DONE"
