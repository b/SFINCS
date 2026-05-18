#!/bin/bash
R="${OMPI_COMM_WORLD_RANK:-0}"
if [ "$R" = "0" ]; then
  exec "/usr/lib/linux-tools-6.8.0-117/perf" record -F 999 --call-graph dwarf,16384 \
      -o "/work/tests/perf/snapwave-memoize-20260517/snapwave_perf.data" \
      -- "/work/source/install_cuda/bin/sfincs"
else
  exec "/work/source/install_cuda/bin/sfincs"
fi
