#!/bin/bash

set -xeu

pushd $BIN_DIR
srun \
  -N "$NUM_NODES" \
  -n "$CLIENT_TOTAL_TASKS" \
  --ntasks-per-node="$CLIENTS_PER_NODE" \
  --output=client_output_${1}_${TRANSFORM}_${NUM_NODES}.log \
  --error=client_output_${1}_${TRANSFORM}_${NUM_NODES}.err \
  ./$1 write enc 1024 1024
popd

