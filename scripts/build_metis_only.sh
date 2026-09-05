#!/usr/bin/env bash
set -e
export PATH=/usr/x86_64-w64-mingw32/sys-root/mingw/bin:$PATH
ROOT=${ROOT:-/cygdrive/d/source/for_getdp_build}
SRC=$ROOT/petsc/complex_mumps_metis/externalpackages/git.metis
PREFIX=$ROOT/metis-mingw

if [ -f "$PREFIX/lib/libmetis.a" ] && [ -z "${FORCE:-}" ]; then
  echo "METIS already built ($PREFIX/lib/libmetis.a) - skipping. FORCE=1 to rebuild."
  exit 0
fi
rm -rf $SRC/build-manual
mkdir -p $SRC/build-manual
cd $SRC/build-manual
cmake .. -G "Unix Makefiles" \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DCMAKE_INSTALL_PREFIX=$PREFIX \
  -DCMAKE_INSTALL_LIBDIR:STRING=lib \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER=x86_64-w64-mingw32-gcc \
  -DCMAKE_AR=/usr/bin/ar -DCMAKE_RANLIB=/usr/bin/ranlib \
  -DCMAKE_C_FLAGS:STRING="-O3 -static -static-libgcc -DUSE_GKREGEX" \
  -DBUILD_SHARED_LIBS:BOOL=OFF -DSHARED=0 \
  -DGKLIB_PATH=../GKlib -DGKRAND=1 -DMATH_LIB=""
make -j"$(nproc)"
make install
echo "=== installed ==="
ls -la $PREFIX/lib $PREFIX/include 2>/dev/null
echo "METIS_ONLY_BUILD_DONE"
