#!/usr/bin/env bash
# Link GetDP against the METIS-enabled PETSc arch, into a separate build dir.
set -e
export PATH=/usr/x86_64-w64-mingw32/sys-root/mingw/bin:$PATH
ROOT=${ROOT:-/cygdrive/d/source/for_getdp_build}
export PETSC_DIR=$ROOT/petsc
export PETSC_ARCH=complex_mumps_metis
cd $ROOT/cenos-getdp-fork
mkdir -p build_metis && cd build_metis
cmake -DCMAKE_C_COMPILER=x86_64-w64-mingw32-gcc \
      -DCMAKE_CXX_COMPILER=x86_64-w64-mingw32-g++ \
      -DCMAKE_Fortran_COMPILER=x86_64-w64-mingw32-gfortran \
      -DENABLE_MPI=0 -DENABLE_BLAS_LAPACK=1 -DENABLE_OPENMP=1 -DENABLE_PETSC=1 \
      -DBUILD_SHARED_LIBS=OFF -DCMAKE_BUILD_TYPE=Release \
      -DBLAS_LAPACK_LIBRARIES=$ROOT/OpenBLAS/libopenblas.a \
      -DGMSH_INC=/usr/local/include -DGMSH_LIB=/usr/local/lib/libgmsh.a \
      -DENABLE_PYTHON=0 \
      -DGETDP_RELEASE=1 \
      -DGETDP_EXTRA_VERSION="+cenos.metis" \
      ..
make -j"$(nproc)"
./getdp.exe -info
echo "GETDP_METIS_BUILD_DONE"
