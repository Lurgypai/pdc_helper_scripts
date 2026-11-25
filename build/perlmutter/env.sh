# Source on Perlmutter (login or compute node) before building or running PDC.
# Override any of the paths below by exporting them first.
# One at a time, so a missing or already-loaded module does not stop the rest.
# libfabric is the one in the default environment.
for m in PrgEnv-gnu cray-mpich cmake; do
  module load "$m" > /dev/null 2>&1 || echo "note: module load $m failed" >&2
done

PM_HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
export PDC_PREFIX=${PDC_PREFIX:-$PSCRATCH/pdc_helper}     # builds and installs (Lustre)
export MERCURY_DIR=$PDC_PREFIX/install/mercury PDC_DIR=$PDC_PREFIX/install/pdc
export LD_LIBRARY_PATH=$PDC_DIR/lib:$MERCURY_DIR/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
export PATH=$PDC_DIR/bin:$MERCURY_DIR/bin:$PATH
# PDC clients ask for MPI_THREAD_MULTIPLE; Cray MPICH only grants it with this.
export MPICH_MAX_THREAD_SAFETY=multiple
# PDC defaults to ofi+cxi on Perlmutter and picks cxi0:<pid> endpoints itself.
unset HG_HOST

export GPU=${GPU:-0}   # GPU=1 adds cuSZ and CUDA ZFP (GPU transformations)
# Transformation libraries (ZFP, SZ3, TurboPFor, libsodium, cuSZ) built by build.sh.
source "$(dirname "${BASH_SOURCE[0]}")/../common.sh"
tf_env
