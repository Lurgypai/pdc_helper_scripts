# Source on a Linux workstation or laptop (WSL included) to use the PDC built
# by build.sh. PDC and Mercury talk ofi+tcp over loopback.
LOCAL_HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
export PDC_PREFIX=${PDC_PREFIX:-$(cd "$LOCAL_HERE/../.." && pwd)/deps/install}
export LIBFABRIC_DIR=$PDC_PREFIX MERCURY_DIR=$PDC_PREFIX PDC_DIR=$PDC_PREFIX
export PATH=$PDC_PREFIX/bin:$PATH
export LD_LIBRARY_PATH=$PDC_PREFIX/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
export PKG_CONFIG_PATH=$PDC_PREFIX/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}
export HG_TRANSPORT=${HG_TRANSPORT:-ofi+tcp}
export HG_HOST=${HG_HOST:-127.0.0.1}
export OMPI_MCA_rmaps_base_oversubscribe=1
export PDC_TMPDIR=${PDC_TMPDIR:-$PWD/pdc_tmp}
export PDC_DATA_LOC=${PDC_DATA_LOC:-$PWD/pdc_data}

# Transformation libraries (ZFP, SZ3, TurboPFor, libsodium, cuSZ) built by build.sh.
source "$(dirname "${BASH_SOURCE[0]}")/../common.sh"
tf_env
