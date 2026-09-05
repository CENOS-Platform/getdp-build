#!/usr/bin/env bash
# Third PETSc arch: Intel MKL as BLAS/LAPACK + MKL PARDISO as an alternative
# direct solver, MUMPS(+METIS) kept in the same binary so both can be compared
# at runtime with -pc_factor_mat_solver_type {mumps,mkl_pardiso}.
#
# MKL comes from the mkl-devel 2024.1.0 package that CENOS already ships in
# backend/bin (DLLs) and backend/bin/Library (headers + import libs), so this
# adds no new redistributable.
#
# Link mkl_rt.lib ONLY. The mkl_intel_lp64_dll/_thread/_core .lib files are not
# pure import libraries - they carry MSVC objects needing __security_cookie and
# UCRT symbols that mingw's msvcrt lacks. Threading layer picked at runtime via
# MKL_THREADING_LAYER.
#
# MUMPS is built from source by PETSc with our toolchain. Pin the tarball URL:
# a bare --download-mumps silently reuses any pkg-mumps directory sitting next
# to PETSC_DIR, which is how 5.4.1 kept coming back.
set -e
ROOT=${ROOT:-/cygdrive/d/source/for_getdp_build}
MKL=${MKL:-/cygdrive/d/source/cenos/backend/bin/Library}
MUMPS_TARBALL=${MUMPS_TARBALL:-https://web.cels.anl.gov/projects/petsc/download/externalpackages/MUMPS_5.6.2.tar.gz}
# MKL DLLs must be on PATH during configure: PETSc runs test programs, and if
# they fail to launch it concludes "64-bit BLAS indices" and PARDISO refuses.
export PATH=/usr/x86_64-w64-mingw32/sys-root/mingw/bin:$MKL/bin:/cygdrive/d/source/cenos/backend/bin:$PATH
export PETSC_DIR=$ROOT/petsc
export PETSC_ARCH=complex_mkl_metis

# PETSc takes ~30 min and the configure below wipes $PETSC_ARCH, so never redo it
# implicitly on a resumed build.
if [ -f "$PETSC_DIR/$PETSC_ARCH/lib/libpetsc.a" ] && [ -z "${FORCE:-}" ]; then
  echo "PETSc $PETSC_ARCH already built - skipping. FORCE=1 to rebuild."
  exit 0
fi
cd $PETSC_DIR

# PETSc caches configure options in $PETSC_DIR/RDict.log and merges them into
# later runs, so stale options (an old --download-sowing, an old --download-mumps
# path) silently come back. Clear it so this script alone decides the build.
rm -f $PETSC_DIR/RDict.log $PETSC_DIR/RDict.log.bkp
rm -rf $PETSC_DIR/$PETSC_ARCH        # stale externalpackages get reused otherwise

./configure CC=x86_64-w64-mingw32-gcc CXX=x86_64-w64-mingw32-g++ \
  FC=x86_64-w64-mingw32-gfortran PETSC_ARCH=$PETSC_ARCH \
  --with-debugging=0 \
  --with-mpi=0 --with-mpiuni-fortran-binding=0 --with-fortran-bindings=0 \
  --with-mumps-serial \
  --download-mumps=$MUMPS_TARBALL \
  --with-metis-include=$ROOT/metis-mingw/include \
  --with-metis-lib=$ROOT/metis-mingw/lib/libmetis.a \
  --with-shared-libraries=0 --with-x=0 --with-ssl=0 \
  --with-scalar-type=complex --with-openmp=1 \
  --with-blaslapack-include=$MKL/include \
  --with-blaslapack-lib=$MKL/lib/mkl_rt.lib \
  --with-mkl_pardiso-include=$MKL/include \
  --with-mkl_pardiso-lib=$MKL/lib/mkl_rt.lib \
  COPTFLAGS="-O3 -static -static-libgcc -static-libstdc++" \
  CXXOPTFLAGS="-O3 -static -static-libgcc -static-libstdc++" \
  FOPTFLAGS="-O3 -static -static-libgfortran"

make PETSC_DIR=$PETSC_DIR PETSC_ARCH=$PETSC_ARCH all

echo "=== solver support in the new arch ==="
grep -E "PETSC_HAVE_MKL_PARDISO|PETSC_HAVE_MUMPS|PETSC_HAVE_MKL " $PETSC_DIR/$PETSC_ARCH/include/petscconf.h || true
grep -E '^ORDERINGSF' $PETSC_DIR/$PETSC_ARCH/externalpackages/git.mumps/Makefile.inc || true
echo "PETSC_MKL_BUILD_DONE"
