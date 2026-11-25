# Source on Perlmutter (login or compute node) before building or running PDC.
# Override any of the paths below by exporting them first.
# One at a time, so a missing or already-loaded module does not stop the rest
# (build.sh checks for libfabric itself).
for m in PrgEnv-gnu cray-mpich cmake; do
  module load "$m" > /dev/null 2>&1 || echo "note: module load $m failed" >&2
done
pkg-config --exists libfabric 2> /dev/null || module load libfabric > /dev/null 2>&1 ||
  module load cray-libfabric > /dev/null 2>&1 || true

PM_HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
export PDC_PREFIX=${PDC_PREFIX:-$PSCRATCH/pdc_helper}     # builds and installs (Lustre)
export MERCURY_DIR=$PDC_PREFIX/install/mercury PDC_DIR=$PDC_PREFIX/install/pdc
export LD_LIBRARY_PATH=$PDC_DIR/lib:$MERCURY_DIR/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
export PATH=$PDC_DIR/bin:$MERCURY_DIR/bin:$PATH
# PDC clients ask for MPI_THREAD_MULTIPLE; Cray MPICH only grants it with this.
export MPICH_MAX_THREAD_SAFETY=multiple
# PDC defaults to ofi+cxi on Perlmutter and picks cxi0:<pid> endpoints itself.
unset HG_HOST
