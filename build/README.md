# Building PDC

One directory per machine: `local` (Linux workstation or laptop, WSL
included), `perlmutter` and `tuolumne`. Each has an `env.sh` to source and a
`build.sh` that builds libfabric (except on Perlmutter, which uses
cray-libfabric), Mercury and PDC.

    build/perlmutter/build.sh           # everything
    build/perlmutter/build.sh pdc       # PDC only, after editing it
    source build/perlmutter/env.sh      # before running

PDC is cloned into `deps/pdc` on the first build. The default branch is
TheAssembler1/pdc `inflight-transformations-perlmutter-cxi` (in-flight
transformations plus the Perlmutter CXI endpoint fix); `PDC_REPO` and `PDC_REF`
pick another. Later builds never pull or reset that checkout, so edit the code
there and rerun `build.sh pdc` to rebuild. `CLEAN=1` rebuilds from scratch,
`PDC_TESTS=ON` builds PDC's tests, and `PDC_SRC` builds another checkout.
