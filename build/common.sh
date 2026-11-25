# PDC checkout and build, shared by build/<machine>/build.sh. Sourced after
# the machine's env.sh.
#
# The source lives in deps/pdc (git-ignored). The first build clones PDC_REF
# from PDC_REPO: by default the in-flight transformations branch with the
# Perlmutter CXI endpoint fix. Later builds never fetch, reset or switch
# branches there, so edits and local branches survive: change the code, rerun
# `build/<machine>/build.sh pdc` and it rebuilds incrementally. CLEAN=1 starts
# from an empty build directory. PDC_SRC points the build at another checkout.
HELPER_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
PDC_REPO=${PDC_REPO:-https://github.com/TheAssembler1/pdc.git}
PDC_REF=${PDC_REF:-inflight-transformations-perlmutter-cxi}
PDC_SRC=${PDC_SRC:-$HELPER_ROOT/deps/pdc}

pdc_checkout() {
  if [ ! -e "$PDC_SRC/.git" ]; then
    mkdir -p "$(dirname "$PDC_SRC")"
    git clone -q -b "$PDC_REF" "$PDC_REPO" "$PDC_SRC"
  fi
  local at
  at=$(git -C "$PDC_SRC" rev-parse --abbrev-ref HEAD)
  [ "$at" = "$PDC_REF" ] || echo "note: $PDC_SRC is on $at, not $PDC_REF; building it as is" >&2
  echo "PDC source $PDC_SRC ($at $(git -C "$PDC_SRC" describe --always --dirty))"
}

# pdc_build <build dir> <install prefix> [cmake args...]
pdc_build() {
  local b=$1 p=$2
  shift 2
  pdc_checkout
  [ "${CLEAN:-0}" = 1 ] && rm -rf "$b"
  cmake -S "$PDC_SRC" -B "$b" -DCMAKE_BUILD_TYPE=${BUILD_TYPE:-Release} -DCMAKE_INSTALL_PREFIX="$p" \
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -DBUILD_SHARED_LIBS=ON \
    -DBUILD_TESTING=${PDC_TESTS:-OFF} -DBUILD_MPI_TESTING=${PDC_TESTS:-OFF} \
    -DPDC_ENABLE_MPI=ON -DPDC_SERVER_CACHE=ON "$@"
  cmake --build "$b" -j"${J:-8}"
  cmake --install "$b"
  echo "PDC -> $p"
}

# fetch <url> <file in $SRC>
fetch() { [ -e "$SRC/$2" ] || curl -fsSL --retry 3 -o "$SRC/$2" "$1"; }

# libfabric 1.18.0 and Mercury 2.2.0, the versions in PDC's install docs.
build_libfabric_docs() {   # <cc> <prefix>
  fetch https://github.com/ofiwg/libfabric/releases/download/v1.18.0/libfabric-1.18.0.tar.bz2 libfabric-1.18.0.tar.bz2
  rm -rf "$SRC/libfabric-1.18.0" && tar xjf "$SRC/libfabric-1.18.0.tar.bz2" -C "$SRC"
  (cd "$SRC/libfabric-1.18.0" && ./configure -q --prefix="$2" CC="$1" CFLAGS=-O2 \
    --enable-tcp=yes --enable-rxm=yes --enable-sockets=yes \
    --disable-verbs --disable-psm3 --disable-efa --disable-usnic --disable-opx &&
    make -s -j"${J:-8}" && make -s install)
}

build_mercury_docs() {     # <cc> <prefix>
  fetch https://github.com/mercury-hpc/mercury/releases/download/v2.2.0/mercury-2.2.0.tar.bz2 mercury-2.2.0.tar.bz2
  rm -rf "$SRC/mercury-2.2.0" "$SRC/build-mercury" && tar xjf "$SRC/mercury-2.2.0.tar.bz2" -C "$SRC"
  cmake -S "$SRC/mercury-2.2.0" -B "$SRC/build-mercury" -DCMAKE_C_COMPILER="$1" -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$2" -DCMAKE_PREFIX_PATH="$2" -DBUILD_SHARED_LIBS=ON -DBUILD_TESTING=OFF \
    -DMERCURY_USE_BOOST_PP=ON -DMERCURY_USE_CHECKSUMS=OFF -DNA_USE_OFI=ON -DNA_USE_SM=OFF
  cmake --build "$SRC/build-mercury" -j"${J:-8}" && cmake --install "$SRC/build-mercury"
}
