# Building CENOS GetDP (Windows: Cygwin + mingw-w64 cross-compile)

Everything runs in a **Cygwin login shell**:

```
<cygwin>\bin\bash.exe -l
```

`-l` matters — without it `/usr/bin` is off `PATH` and `python3`/`grep` "aren't found".

## Quick start

```bash
git submodule update --init --recursive

C=/cygdrive/d/source/cenos/backend/bin      # a CENOS install (adjust)
MKL=$C/Library PY=$C ./build.sh             # shippable binary, embedded Python
```

`build.sh` takes every external dependency from the environment and discovers nothing:

| variable | required | what for |
|---|---|---|
| `MKL` | yes | oneMKL with `include/` + `lib/mkl_rt.lib`. CENOS: `backend/bin/Library` |
| `PY` | no | CPython prefix (`include/`, `libs/python310.lib`). **Set it for the shippable binary**; omit for a test binary. CENOS: `backend/bin` |
| `PYLIB` | no | default `python310.lib` |
| `CUDSS_DIR` + `CUDA_TOOLKIT_DIR` | no | GPU direct solve (step 9) |
| `BUILDDIR` | no | default `build` |

So a full CENOS install is *not* required — point `MKL` at any oneMKL and `PY` at any
CPython, or omit `PY` entirely.

Run a script from outside Cygwin with:
`MSYS_NO_PATHCONV=1 <cygwin>\bin\bash.exe -l -c '<script>'`

**Keep the scripts LF-only.** CRLF silently breaks the `\` line continuations and the build
then "succeeds" while doing nothing (`.gitattributes` enforces this in git).

---

## 0. Prerequisites

Install Cygwin **non-interactively** (the GUI package picker is unusable for this list).
Get `setup-x86_64.exe` from cygwin.com, then run the command below from cmd.exe **or**
PowerShell, in the directory holding it. It must be **one single line** - the `^`
continuations you may see elsewhere are cmd-only and PowerShell errors on them.

```
.\setup-x86_64.exe -q -n -N -d -R C:\cygwin64 -l C:\cygwin-pkgs -s https://mirrors.kernel.org/sourceware/cygwin/ -P gcc-core,gcc-g++,gcc-fortran,binutils,make,cmake,bison,flex,patch,git,curl,wget,diffutils,perl,python3,libtool,autoconf,automake,pkg-config,mingw64-x86_64-gcc-core,mingw64-x86_64-gcc-g++,mingw64-x86_64-gcc-fortran,mingw64-x86_64-headers,mingw64-x86_64-runtime,mingw64-x86_64-winpthreads,mingw64-x86_64-win-iconv,mingw64-x86_64-zlib
```

`-R` is the install root, `-l` the package cache. The command is idempotent -
re-run it to add packages or update. Then, in a Cygwin login shell, verify:

```bash
x86_64-w64-mingw32-gcc --version && x86_64-w64-mingw32-gfortran --version
cmake --version && python3 --version && nproc
x86_64-w64-mingw32-g++ -v 2>&1 | grep "Thread model"   # must say: posix
```

The last check must print `Thread model: posix`. Cygwin's mingw packages always are, so
this only catches a *different* mingw (MSYS2, standalone) shadowing it on `PATH` — a
`win32`-threads mingw has no `std::thread` in its libstdc++ and the post-processing writer
won't compile. Fix by removing the other toolchain from `PATH`, not by changing anything here.

**MKL** comes from the `mkl-devel` package CENOS already ships in
`backend/bin/Library` (headers + import libs) with the DLLs in `backend/bin`. Nothing to
install.

**Embedded Python** — only if you are building the *shipped* binary (step 7a). GetDP is
built with `-DENABLE_PYTHON=1` there, so `getdp.exe` needs `python310.dll` at run time and
CMake needs that Python's `include/` and `libs/python310.lib` at build time. Set `PY` above
to a CPython install that has both; CENOS's own `backend/bin` already does.
**For testing/benchmarking, skip this** — `build_getdp_arch.sh` builds with
`-DENABLE_PYTHON=0` and has no Python dependency at all.

**GPU (optional, cuDSS)** — see step 9. It needs the CUDA Toolkit and NVIDIA cuDSS
installed, but **no** nvcc, no VS2022 and no PETSc CUDA build: cuDSS is called through its
host API and compiles with plain mingw `g++`.

---

## 1. Get the sources

```bash
git submodule update --init --recursive
```

Five submodules land in `src/`, pinned to known-good commits: OpenBLAS, lapack, gmsh,
petsc, cenos-getdp-fork. MUMPS is not among them — PETSc downloads and builds it
(version pinned in `scripts/build_mkl_petsc.sh`), so configure needs network access.

---

## 2. OpenBLAS

```bash
cd $ROOT/OpenBLAS
cat > Makefile.rule <<'EOF'
DYNAMIC_ARCH = 1
DYNAMIC_OLDER = 1
CC = x86_64-w64-mingw32-gcc
FC = x86_64-w64-mingw32-gfortran
BINARY=64
USE_THREAD = 1
NUM_THREADS = 64
BUILD_LAPACK_DEPRECATED = 1
INTERFACE64 = 0
NO_WARMUP = 1
NO_AFFINITY = 1
EOF
make -j"$(nproc)"
```

Produces `$ROOT/OpenBLAS/libopenblas.a`, used in place (no install).
Not needed for the MKL arch, but the other archs use it.

---

## 3. LAPACK

```bash
cd $ROOT/lapack && mkdir -p build && cd build
cmake -DCMAKE_C_COMPILER=x86_64-w64-mingw32-gcc \
      -DCMAKE_Fortran_COMPILER=x86_64-w64-mingw32-gfortran \
      -DBUILD_SHARED_LIBS=OFF -DCBLAS=OFF -DLAPACKE=OFF -DLAPACKE_WITH_TMG=OFF ..
make -j"$(nproc)"
```

Produces `$ROOT/lapack/build/lib/liblapack.a`.

---

## 4. gmsh (library only — no mesh module, no GUI)

```bash
cd $ROOT/gmsh && mkdir -p build && cd build
cmake -DCMAKE_C_COMPILER=x86_64-w64-mingw32-gcc \
      -DCMAKE_CXX_COMPILER=x86_64-w64-mingw32-g++ \
      -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local \
      -DENABLE_BUILD_LIB=1 -DENABLE_BUILD_SHARED=OFF -DENABLE_BUILD_DYNAMIC=OFF \
      -DENABLE_BLAS_LAPACK=1 -DENABLE_OPENMP=1 -DENABLE_PARSER=1 -DENABLE_POST=1 \
      -DENABLE_PLUGINS=1 -DENABLE_PRIVATE_API=1 -DENABLE_ALGLIB=1 -DENABLE_ANN=1 \
      -DENABLE_GMP=ON \
      -DENABLE_MESH=OFF -DENABLE_OCC=OFF -DENABLE_FLTK=0 -DENABLE_MPI=OFF \
      -DENABLE_PETSC=OFF -DENABLE_MED=OFF -DENABLE_CGNS=OFF -DENABLE_MMG=OFF \
      -DENABLE_METIS=OFF -DENABLE_NETGEN=OFF -DENABLE_TESTS=OFF -DENABLE_EIGEN=0 \
      -DENABLE_WRAP_PYTHON=OFF ..
make -j"$(nproc)" && make install
```

Installs into Cygwin's `/usr/local` — where GetDP's CMake looks.

---

## 5. METIS

**Needed by every arch except `complex_mumps_seq`.** METIS is the fill-reducing ordering
MUMPS uses; without it MUMPS falls back to PORD, which costs ~16% more arithmetic and ~12%
more memory on our test cases.

```bash
./scripts/build_metis_only.sh      # -> $ROOT/metis-mingw/{include,lib}
```

It has its own script because PETSc's `--download-metis` cannot work here: PETSc forces
`-G "MSYS Makefiles"` (Cygwin cmake has only `Unix Makefiles`), cmake 4 rejects METIS's
`cmake_minimum_required(VERSION 2.8)`, and mingw has no `<regex.h>`.

---

## 6. PETSc

Pick **one** arch. Same `PETSC_DIR`, different `PETSC_ARCH`.

| arch | script | solvers |
|---|---|---|
| **`complex_mkl_metis`** | **`scripts/build_mkl_petsc.sh`** | **MUMPS 5.6.2/METIS + MKL PARDISO — recommended** |
| `complex_mumps_seq` | 6a below | MUMPS 5.4.1/PORD — the original build, kept for reference |

Two things that bite on the MKL archs:

- Link **`mkl_rt.lib` only**. The other MKL `.lib`s aren't pure import libraries — they carry
  MSVC objects needing `__security_cookie` / UCRT symbols that mingw's msvcrt lacks.
- The MKL **DLLs must be on `PATH` during configure**. PETSc *runs* test programs; if they
  fail to launch it silently concludes "64-bit BLAS indices" and PARDISO refuses to
  configure. The scripts handle this.

### 6a. `complex_mumps_seq` (original, no METIS/MKL)

```bash
export PETSC_DIR=$ROOT/petsc PETSC_ARCH=complex_mumps_seq
cd $PETSC_DIR
./configure CC=x86_64-w64-mingw32-gcc CXX=x86_64-w64-mingw32-g++ \
  FC=x86_64-w64-mingw32-gfortran PETSC_ARCH=$PETSC_ARCH \
  --with-debugging=0 --with-mpi=0 --with-mpiuni-fortran-binding=0 \
  --with-fortran-bindings=0 --with-mumps-serial \
  --download-mumps \
  --with-shared-libraries=0 --with-x=0 --with-ssl=0 \
  --with-scalar-type=complex --with-openmp=1 \
  --with-blas-lib=$ROOT/OpenBLAS/libopenblas.a \
  --with-lapack-lib=$ROOT/lapack/build/lib/liblapack.a \
  --download-sowing=yes \
  COPTFLAGS="-O3 -static -static-libgcc -static-libstdc++" \
  CXXOPTFLAGS="-O3 -static -static-libgcc -static-libstdc++" \
  FOPTFLAGS="-O3 -static -static-libgfortran"
make PETSC_DIR=$PETSC_DIR PETSC_ARCH=$PETSC_ARCH all
```

---

## 7. GetDP

Generic helper (no embedded Python — fine for testing, not for shipping):

```bash
$ROOT/../scripts/build_getdp_arch.sh <PETSC_ARCH> <build-dir> <blas-libs>

$ROOT/../scripts/build_getdp_arch.sh complex_mkl_metis   build_best  $MKL/lib/mkl_rt.lib
```

`<blas-libs>` **must match the BLAS the arch was configured with**, or the binary ends up
with both OpenBLAS and MKL linked in.

### 7a. Shipped binary (embedded Python)

```bash
cd $ROOT/cenos-getdp-fork && mkdir -p build && cd build
export PETSC_DIR=$ROOT/petsc PETSC_ARCH=complex_mkl_metis
cmake -DCMAKE_C_COMPILER=x86_64-w64-mingw32-gcc \
      -DCMAKE_CXX_COMPILER=x86_64-w64-mingw32-g++ \
      -DCMAKE_Fortran_COMPILER=x86_64-w64-mingw32-gfortran \
      -DENABLE_MPI=0 -DENABLE_BLAS_LAPACK=1 -DENABLE_OPENMP=1 -DENABLE_PETSC=1 \
      -DBUILD_SHARED_LIBS=OFF -DCMAKE_BUILD_TYPE=Release \
      -DBLAS_LAPACK_LIBRARIES=$MKL/lib/mkl_rt.lib \
      -DGMSH_INC=/usr/local/include -DGMSH_LIB=/usr/local/lib/libgmsh.a \
      -DENABLE_PYTHON=1 \
      -DPYTHON_INCLUDE_DIR=/cygdrive/d/source/cenos/backend/bin/include \
      -DPYTHON_LIBRARY=/cygdrive/d/source/cenos/backend/bin/libs/python310.lib \
      -DGETDP_RELEASE=1 -DGETDP_EXTRA_VERSION="+cenos.py310.1" ..
make -j"$(nproc)"
```

### Regenerating the parser (only if `ProParser.y`/`.l` changed)

```bash
make parser      # before make, from the build dir
```

---

## 8. Smoke test

```bash
./getdp.exe -info                     # version + PETSc line
./getdp.exe some.pro -solve X -pos Y  # a real solve
```

Solver selection at runtime (same binary):

```bash
-pc_factor_mat_solver_type mkl_pardiso -mat_mkl_pardiso_65 6 \
  -mat_mkl_pardiso_2 3 -mat_mkl_pardiso_24 1      # PARDISO (recommended)
-pc_factor_mat_solver_type mumps -mat_mumps_icntl_7 5   # MUMPS fallback
```

**Runtime DLLs:** `getdp.exe` imports one non-system DLL, `mkl_rt.2.dll`, which loads its
kernels (`mkl_core`, `mkl_intel_thread`, `mkl_avx2`, `libiomp5md`, ...) at run time. All of
them already ship in CENOS's `backend/bin`, so nothing extra to distribute — just keep that
directory on `PATH` (`_ensure_getdp_dll_path()` in `getdp_wrapper.py` already does).

## 9. Optional: GPU direct solve (cuDSS)

Only worth it on a machine with an NVIDIA GPU. cuDSS is a GPU direct sparse solver
(MUMPS/PARDISO equivalent), called through its **host API** — so there is no device code to
compile: **no nvcc, no VS2022, no CUDA-enabled PETSc.** Use a normal CPU PETSc arch.

An earlier attempt built PETSc itself with CUDA; that only accelerates PETSc's *iterative*
solvers, which this product doesn't use. `cuda-build.md` keeps that history — ignore it
unless you specifically want the iterative path.

Install:
- NVIDIA CUDA Toolkit (for `cudart`)
- NVIDIA cuDSS — a **separate** download from the Toolkit. Use the subdirectory matching
  your CUDA major version, e.g. `v0.8/13/{include,lib,bin}` for CUDA 13.

Build:

```bash
export CUDA_TOOLKIT_DIR="C:/Program Files/NVIDIA GPU Computing Toolkit/CUDA/v13.2"
export CUDSS_DIR="C:/Program Files/NVIDIA cuDSS/v0.8"
# add -DENABLE_CUDSS=1 to the cmake line in step 7/7a (needs ENABLE_PETSC=1)
```

Ship these DLLs beside `getdp.exe` (nothing else is needed):
`cudss64_0.dll`, `cudart64_13.dll` (from `CUDA/v<ver>/bin/x64/`), `cublas64_13.dll`,
`cublasLt64_13.dll`.

Note `src/kernel/gs_stub.c` in the fork: `cudart.lib` references MSVC `/GS` stack-cookie
symbols that mingw doesn't define. The stub supplies them — needed by any mingw code linking
`cudart.lib`.

Falls back to the CPU solver automatically if no GPU/driver is present.

## Incremental rebuilds

Don't redo the above — `rebuild_getdp.sh`, or from the relevant `build*/` dir:
`make parser` (only if the grammar changed) then `make -j"$(nproc)"`.
