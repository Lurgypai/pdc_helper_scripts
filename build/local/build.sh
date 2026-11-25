#!/usr/bin/env bash
# Build libfabric, Mercury and PDC into deps/install on a Linux workstation or
# laptop (needs mpicc, cmake, curl).
#   build/local/build.sh [libfabric] [mercury] [pdc]    default: all
set -euo pipefail
source "$(dirname "$0")/env.sh"
source "$(dirname "$0")/../common.sh"
J=${J:-$(nproc)}
SRC=$HELPER_ROOT/deps/src
mkdir -p "$SRC"

build_libfabric() { build_libfabric_docs gcc "$PDC_PREFIX"; }
build_mercury() { build_mercury_docs gcc "$PDC_PREFIX"; }
build_pdc() {
  pdc_build "$SRC/build-pdc" "$PDC_PREFIX" -DCMAKE_C_COMPILER=mpicc \
    -DMERCURY_DIR="$PDC_PREFIX/share/cmake/mercury" -DCMAKE_PREFIX_PATH="$PDC_PREFIX"
}

for c in ${*:-libfabric mercury pdc}; do
  echo "=== $c"
  "build_$c" > "$SRC/build_$c.log" 2>&1 || { echo "=== $c FAILED (see $SRC/build_$c.log)"; exit 1; }
done
