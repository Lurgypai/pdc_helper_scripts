#!/bin/bash
# Build libfabric, Mercury and PDC on Tuolumne (login node, or inside
# `flux alloc -N1` for a faster build).
#   build/tuolumne/build.sh [libfabric] [mercury] [pdc]    default: all
set -euo pipefail
source "$(dirname "$0")/env.sh"
source "$(dirname "$0")/../common.sh"
J=${J:-32}
SRC=$PDC_PREFIX/src
mkdir -p "$SRC"
MPICC=${MPICC:-$(command -v mpicc || command -v cc)}

build_libfabric() { build_libfabric_docs "$MPICC" "$PDC_DIR"; }
build_mercury() { build_mercury_docs "$MPICC" "$PDC_DIR"; }
build_pdc() {
  # Cray clang: PDC_TIMING globals are defined in a header, so linking needs
  # -fcommon (PDC adds it for GCC only). TOSS 4's glibc keeps shm_open in
  # librt, which PDC does not link.
  pdc_build "$SRC/build-pdc" "$PDC_DIR" -DCMAKE_C_COMPILER="$MPICC" \
    -DMERCURY_DIR="$PDC_DIR/share/cmake/mercury" -DCMAKE_PREFIX_PATH="$PDC_DIR" \
    -DCMAKE_C_FLAGS=-fcommon -DCMAKE_C_STANDARD_LIBRARIES=-lrt
}

for c in ${*:-libfabric mercury pdc}; do
  echo "=== $c"
  "build_$c"
done
