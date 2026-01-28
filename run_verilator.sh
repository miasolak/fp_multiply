#!/usr/bin/env bash
set -euo pipefail

# ----------------------------------------
# Config
# ----------------------------------------
DUT_SV="fmul.sv"
TB_CPP="tb_fmul.cpp"
TOP="fmul"

# Defaults
NRAND=200000
PRINT_OK=0
TRACE=0
CHECK_FLAGS=0
SEED=""

usage() {
  cat <<EOF
Usage:
  ./run_verilator.sh [options]

Options:
  --n N            Number of random tests (default: ${NRAND})
  --print-ok       Print PASS cases as well as FAIL cases
  --trace          Enable VCD tracing (wave.vcd)
  --check-flags    Check invalid/overflow/underflow/inexact status outputs
  --seed S         RNG seed (reproducible runs)
  -h, --help       Show this help

Examples:
  ./run_verilator.sh
  ./run_verilator.sh --n 500000
  ./run_verilator.sh --n 50 --print-ok
  ./run_verilator.sh --n 50 --print-ok --trace
  ./run_verilator.sh --n 200000 --check-flags
  ./run_verilator.sh --n 50 --print-ok --trace --check-flags --seed 12345
EOF
}

# ----------------------------------------
# Args
# ----------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --n)
      NRAND="$2"
      shift 2
      ;;
    --print-ok)
      PRINT_OK=1
      shift
      ;;
    --trace)
      TRACE=1
      shift
      ;;
    --check-flags)
      CHECK_FLAGS=1
      shift
      ;;
    --seed)
      SEED="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo
      usage
      exit 1
      ;;
  esac
done

# ----------------------------------------
# Clean build artifacts
# ----------------------------------------
rm -rf obj_dir wave.vcd

# ----------------------------------------
# Build
# ----------------------------------------
echo "=============================================="
echo "Building with Verilator..."
echo "=============================================="

verilator -Wall -Wno-UNUSED -Wno-DECLFILENAME \
  --cc "rtl/$DUT_SV" \
  --exe "dv/$TB_CPP" \
  --top-module "$TOP" \
  --trace \
  --build \
  -O3

# ----------------------------------------
# Run
# ----------------------------------------
echo
echo "=============================================="
echo "Running simulation"
echo "=============================================="
echo "  Random tests : $NRAND"
echo "  Print OK     : $PRINT_OK"
echo "  Trace        : $TRACE"
echo "  Check flags  : $CHECK_FLAGS"
echo "  Seed         : ${SEED:-<default in TB>}"
echo "=============================================="
echo

CMD="./obj_dir/V${TOP} --n ${NRAND}"

if [[ "$PRINT_OK" -eq 1 ]]; then
  CMD="${CMD} --print-ok"
fi

if [[ "$TRACE" -eq 1 ]]; then
  CMD="${CMD} --trace"
fi

if [[ "$CHECK_FLAGS" -eq 1 ]]; then
  CMD="${CMD} --check-flags"
fi

if [[ -n "$SEED" ]]; then
  CMD="${CMD} --seed ${SEED}"
fi

echo "CMD: $CMD"
echo

$CMD

echo
echo "=============================================="
echo "Done."
echo "=============================================="

if [[ "$TRACE" -eq 1 ]]; then
  echo "Waveform written to: wave.vcd"
  echo "Open with: gtkwave wave.vcd"
fi
