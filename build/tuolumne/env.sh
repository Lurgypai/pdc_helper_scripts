# Source on Tuolumne (login or compute node) before building or running PDC.
# Override any of the paths below by exporting them first.
if command -v module > /dev/null 2>&1; then
  module load cmake > /dev/null 2>&1 || true
  module is-loaded cray-mpich > /dev/null 2>&1 || module load cray-mpich > /dev/null 2>&1 || true
fi
# $HOME and /usr/workspace are NFS; builds and installs go to Lustre.
export PDC_PREFIX=${PDC_PREFIX:-/p/lustre5/$USER/pdc_helper}
export LIBFABRIC_DIR=$PDC_PREFIX/install MERCURY_DIR=$PDC_PREFIX/install PDC_DIR=$PDC_PREFIX/install
export LD_LIBRARY_PATH=$PDC_DIR/lib:$PDC_DIR/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
export PKG_CONFIG_PATH=$PDC_DIR/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}
export PATH=$PDC_DIR/bin:$PATH
# Single-node runs over TCP loopback need no Slingshot/CXI auth-key setup.
export HG_TRANSPORT=${HG_TRANSPORT:-ofi+tcp}
export HG_HOST=${HG_HOST:-127.0.0.1}
