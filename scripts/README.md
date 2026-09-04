# Build scripts

All honour `ROOT` (sources) and `MKL` (CENOS `backend/bin/Library`) from the environment.
`../build.sh` runs all four in order — use these directly only to rebuild one stage.

| script | builds | notes |
|---|---|---|
| `build_deps.sh` | OpenBLAS, LAPACK, gmsh | once; skips whatever already exists |
| `build_metis_only.sh` | METIS for mingw | PETSc's `--download-metis` cannot work here |
| `build_mkl_petsc.sh` | PETSc `complex_mkl_metis` | MUMPS 5.6.2/METIS + MKL PARDISO; needs internet (PETSc fetches MUMPS) |
| `build_getdp_arch.sh` | `getdp.exe` | `<PETSC_ARCH> <build-dir> <blas-libs>` |

`<blas-libs>` must match the BLAS the arch was configured with — `$MKL/lib/mkl_rt.lib`
here — or the binary links two BLAS implementations.
