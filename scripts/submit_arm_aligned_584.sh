#!/usr/bin/env bash
set -euo pipefail

ROOT="${ROOT:-/public/home/acmcs42wxa/yyb}"
RESULT_ROOT="${RESULT_ROOT:-$ROOT/results/arm_aligned_584}"
SCRIPT="${SCRIPT:-$ROOT/scripts/run_arm_aligned_584.sh}"
ACCOUNT="${ACCOUNT:-acmcs42wxa}"
PARTITION="${PARTITION:-hx1hdnormal}"
TIME_LIMIT="${TIME_LIMIT:-24:00:00}"

mkdir -p "$RESULT_ROOT"
sbatch --parsable \
  -A "$ACCOUNT" \
  -p "$PARTITION" \
  --gres=dcu:1 \
  -N1 -n1 -c4 \
  --time="$TIME_LIMIT" \
  -J itk584_arm_aligned \
  -o "$RESULT_ROOT/slurm.%j.out" \
  -e "$RESULT_ROOT/slurm.%j.err" \
  "$SCRIPT"
