# Building PDC

One directory per machine: `local` (Linux workstation or laptop, WSL
included), `perlmutter` and `tuolumne`. Each has an `env.sh` to source and a
`build.sh` that builds libfabric (except on Perlmutter, which uses
the default one), Mercury, the in-flight transformation libraries and PDC.
`build.sh pdc` on a fresh machine builds whatever of these is missing first.

The transformation libraries are ZFP 1.0.1, SZ3 v3.4.0, TurboPFor and
libsodium 1.0.20 (the versions PDC's CI uses), installed under
`$PDC_PREFIX/tf`. With `GPU=1` (off by default) ZFP is built with CUDA and cuSZ is added, which turns on the GPU
transformations. `env.sh` exports the variables PDC's CMake looks for
(`ZFP_ROOT_DIR`, `SZ_CPU_DIR`, `TURBO_DIR`, `LIBSODIUM_ROOT_DIR`,
`CUDA_ROOT_DIR`, `CUSZ_GPU_DIR`) and puts the libraries on `LD_LIBRARY_PATH`.
JSON graph parsing needs nothing extra: PDC bundles cJSON.

    build/perlmutter/build.sh           # everything
    build/perlmutter/build.sh pdc       # PDC only, after editing it
    source build/perlmutter/env.sh      # before running

PDC is cloned into `deps/pdc` on the first build. The default branch is
TheAssembler1/pdc `inflight-transformations-perlmutter-cxi` (in-flight
transformations plus the Perlmutter CXI endpoint fix); `PDC_REPO` and `PDC_REF`
pick another. Later builds never pull or reset that checkout, so edit the code
there and rerun `build.sh pdc` to rebuild. `CLEAN=1` rebuilds from scratch,
`PDC_TESTS=ON` builds PDC's tests, and `PDC_SRC` builds another checkout.
