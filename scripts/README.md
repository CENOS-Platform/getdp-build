# Build scripts

All honour `ROOT` (source dir) and `MKL` (CENOS `backend/bin/Library`) from the
environment. `../build.sh` runs the recommended chain; use these directly only to build a
different variant.

| script | what it builds | when you need it |
|---|---|---|
| `build_deps.sh` | OpenBLAS, LAPACK, gmsh | always, once (skips what exists) |
| `build_metis_only.sh` | METIS for mingw | always — PETSc's `--download-metis` can't work here |
| `build_mkl_petsc.sh` | PETSc `complex_mkl_metis` | **recommended**: MUMPS/METIS + MKL PARDISO |
| `build_getdp_arch.sh` | GetDP against any arch | always, last step |
| `build_metis_petsc.sh` | PETSc `complex_mumps_metis` | MUMPS only, no MKL dependency |
| `build_mumps562_petsc.sh` | PETSc `complex_mumps562` | MUMPS 5.6.2 — tested, no faster than 5.4.1 |
| `build_mpi_petsc.sh` | PETSc `complex_mpi_mumps` | MPI MUMPS — builds, multi-rank solve crashes |
| `build_getdp_mpi.sh` + `scalapack_alias.c` | GetDP for the MPI arch | only with `build_mpi_petsc.sh` |

Usage:

```bash
./build_getdp_arch.sh <PETSC_ARCH> <build-dir> <blas-libs>
```

`<blas-libs>` must match the BLAS the arch was configured with (`$MKL/lib/mkl_rt.lib` for
the MKL archs, `$ROOT/OpenBLAS/libopenblas.a` otherwise), or the binary links both.
