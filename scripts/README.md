# Build scripts

All honour `ROOT` (sources) and `MKL` (CENOS `backend/bin/Library`) from the environment.
`../build.sh` runs them in order — use these directly only to redo one stage.

| script | builds | notes |
|---|---|---|
| `fix_eol.sh` | nothing - renormalizes submodule checkouts to LF | run by `build.sh`; needed because git on Windows checks them out with CRLF |
| `build_deps.sh` | OpenBLAS, LAPACK, gmsh | once; skips whatever already exists |
| `build_metis_only.sh` | METIS for mingw | PETSc's `--download-metis` cannot work here |
| `build_mkl_petsc.sh` | PETSc `complex_mkl_metis` | MUMPS 5.6.2/METIS + MKL PARDISO; needs internet (PETSc fetches MUMPS) |
| `build_getdp_arch.sh` | `getdp.exe` | `<PETSC_ARCH> <build-dir> <blas-libs>`; runs both checks below |
| `crt.sh` | nothing - sourced by the others | picks the C runtime (`CRT=ucrt`, the default). Read it: this is the one setting that silently breaks the embedded Python |
| `check_abi.sh` | nothing - checks `getdp.exe` | import-table gate: one CRT and it must be the UCRT, `-static` not dropped, Python linked when asked for |
| `smoke_python.sh` | nothing - runs `getdp.exe` | runs both `Python[]` forms on a one-triangle problem; the `.py`-file form is the one that used to segfault |

`<blas-libs>` must match the BLAS the arch was configured with — `$MKL/lib/mkl_rt.lib`
here — or the binary links two BLAS implementations.
