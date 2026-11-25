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

# CMake args that hand PDC a Mercury install directly. PDC's FindMERCURY.cmake
# looks for mercury.h under ${MERCURY_DIR}, which is Mercury's CMake config
# directory once its config file is found, so the header is not always found.
# mercury_args <mercury prefix>
mercury_args() {
  local m=$1 lib=$1/lib
  [ -e "$lib/libmercury.so" ] || lib=$1/lib64
  echo "-DMERCURY_DIR=$m/share/cmake/mercury -DCMAKE_PREFIX_PATH=$m -DMERCURY_INCLUDE_DIR=$m/include" \
    "-DMERCURY_LIBRARY=$lib/libmercury.so -DMERCURY_NA_LIBRARY=$lib/libna.so" \
    "-DMERCURY_UTIL_LIBRARY=$lib/libmercury_util.so"
}

# need <file> <step...>: run the build steps first when <file> is missing,
# so `build.sh pdc` on a fresh machine builds its dependencies too.
need() {
  local f=$1
  shift
  [ -e "$f" ] && return 0
  echo "=== $f missing, building $* first"
  local c
  for c in "$@"; do "build_$c"; done
}

# pdc_build <build dir> <install prefix> [cmake args...]
pdc_build() {
  local b=$1 p=$2
  shift 2
  pdc_checkout
  build_tf
  [ "${CLEAN:-0}" = 1 ] && rm -rf "$b"
  cmake -S "$PDC_SRC" -B "$b" -DCMAKE_BUILD_TYPE=${BUILD_TYPE:-Release} -DCMAKE_INSTALL_PREFIX="$p" \
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -DBUILD_SHARED_LIBS=ON \
    -DBUILD_TESTING=${PDC_TESTS:-OFF} -DBUILD_MPI_TESTING=${PDC_TESTS:-OFF} \
    -DPDC_ENABLE_MPI=ON -DPDC_SERVER_CACHE=ON -DCUDA_ENABLED=$([ "${PDC_GPU:-0}" = 1 ] && echo ON || echo OFF) "$@"
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

# In-flight transformation dependencies, at the versions PDC's CI uses
# (.github/workflows/dependencies-linux.sh): ZFP 1.0.1, SZ3 v3.4.0, TurboPFor
# (pinned commit), libsodium 1.0.20. With PDC_GPU=1 also CUDA (from the loaded
# toolkit) and cuSZ, and ZFP is built with CUDA. PDC enables each
# transformation when its *_DIR variable is set (tf_env), so build these
# before configuring PDC.
TF_PREFIX=${TF_PREFIX:-$PDC_PREFIX/tf}
CUSZ_REF=${CUSZ_REF:-4aa42be6e7bb11cba566cadf0192b424c1ce675f}  # last commit with capi_psz_make_timerecord, which PDC calls
TURBO_REF=1f646d98d65ee91befd3066f351f2cf386593442

tf_env() {
  local d
  [ -e "$TF_PREFIX/zfp/include/zfp.h" ] && export ZFP_ROOT_DIR=$TF_PREFIX/zfp
  [ -e "$TF_PREFIX/sz3/include/SZ3c/sz3c.h" ] && export SZ_CPU_DIR=$TF_PREFIX/sz3
  [ -e "$TF_PREFIX/turbopfor/libic.a" ] && export TURBO_DIR=$TF_PREFIX/turbopfor
  [ -e "$TF_PREFIX/libsodium/include/sodium.h" ] && export LIBSODIUM_ROOT_DIR=$TF_PREFIX/libsodium
  if [ "${PDC_GPU:-0}" = 1 ] && [ -e "$TF_PREFIX/cusz/include/cusz/cusz.h" ]; then
    export CUDA_ROOT_DIR=${CUDA_ROOT_DIR:-$CUDA_HOME} CUSZ_GPU_DIR=$TF_PREFIX/cusz
  else
    # PDC turns on CUDA whenever CUDA_ROOT_DIR is set, e.g. by a login profile.
    unset CUDA_ROOT_DIR CUSZ_GPU_DIR
  fi
  for d in zfp sz3 libsodium cusz; do
    [ -d "$TF_PREFIX/$d/lib" ] && LD_LIBRARY_PATH=$TF_PREFIX/$d/lib:$LD_LIBRARY_PATH
    [ -d "$TF_PREFIX/$d/lib64" ] && LD_LIBRARY_PATH=$TF_PREFIX/$d/lib64:$LD_LIBRARY_PATH
  done
  export LD_LIBRARY_PATH
}

tf_clone() {   # <url> <ref> <dir>
  [ -d "$3/.git" ] || git clone -q "$1" "$3"
  git -C "$3" checkout -q "$2"
}

build_zfp() {
  local cuda=()
  [ "${PDC_GPU:-0}" = 1 ] && cuda=(-DZFP_WITH_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES="${CUDA_ARCH:-80}")
  tf_clone https://github.com/LLNL/zfp.git 1.0.1 "$SRC/zfp"
  cmake -S "$SRC/zfp" -B "$SRC/build-zfp" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$TF_PREFIX/zfp" \
    -DBUILD_TESTING=OFF -DBUILD_UTILITIES=OFF "${cuda[@]}"
  cmake --build "$SRC/build-zfp" -j"${J:-8}" && cmake --install "$SRC/build-zfp"
}

build_sz3() {
  tf_clone https://github.com/szcompressor/SZ3.git v3.4.0 "$SRC/sz3"
  cmake -S "$SRC/sz3" -B "$SRC/build-sz3" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$TF_PREFIX/sz3" \
    -DBUILD_TESTING=OFF
  cmake --build "$SRC/build-sz3" -j"${J:-8}" && cmake --install "$SRC/build-sz3"
}

build_turbopfor() {   # PDC wants include/ic.h and libic.a directly in TURBO_DIR
  tf_clone https://github.com/powturbo/TurboPFor-Integer-Compression.git "$TURBO_REF" "$TF_PREFIX/turbopfor"
  make -C "$TF_PREFIX/turbopfor" -j"${J:-8}" libic.a
}

build_libsodium() {
  fetch https://download.libsodium.org/libsodium/releases/libsodium-1.0.20.tar.gz libsodium-1.0.20.tar.gz
  rm -rf "$SRC/libsodium-1.0.20" && tar xzf "$SRC/libsodium-1.0.20.tar.gz" -C "$SRC"
  (cd "$SRC/libsodium-1.0.20" && ./configure -q --prefix="$TF_PREFIX/libsodium" && make -s -j"${J:-8}" && make -s install)
}

build_cusz() {
  tf_clone https://github.com/szcompressor/cuSZ.git "$CUSZ_REF" "$SRC/cusz"
  cmake -S "$SRC/cusz" -B "$SRC/build-cusz" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$TF_PREFIX/cusz" \
    -DPSZ_BACKEND=CUDA -DPSZ_BUILD_EXAMPLES=OFF -DBUILD_TESTING=OFF -DCMAKE_CUDA_ARCHITECTURES="${CUDA_ARCH:-80}"
  cmake --build "$SRC/build-cusz" -j"${J:-8}" && cmake --install "$SRC/build-cusz"
}

# All transformation dependencies that are not installed yet.
build_tf() {
  need "$TF_PREFIX/zfp/include/zfp.h" zfp
  need "$TF_PREFIX/sz3/include/SZ3c/sz3c.h" sz3
  need "$TF_PREFIX/turbopfor/libic.a" turbopfor
  need "$TF_PREFIX/libsodium/include/sodium.h" libsodium
  [ "${PDC_GPU:-0}" = 1 ] && need "$TF_PREFIX/cusz/include/cusz/cusz.h" cusz
  tf_env
}
