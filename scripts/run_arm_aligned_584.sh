#!/usr/bin/env bash
set -u

# ARM-aligned DCU protocol:
# same input, float and double, one warmup, three measured runs.
ROOT="${ROOT:-/public/home/acmcs42wxa/yyb}"
TEST_BUILD="${TEST_BUILD:-$ROOT/build-phase2/test}"
DATA_ROOT="${DATA_ROOT:-$ROOT/data}"
MANIFEST="${MANIFEST:-$ROOT/manifests/itk_arm_aligned_584.tsv}"
INVENTORY="${INVENTORY:-$ROOT/itk_port_baseline_584/manifests/benchmark_inventory.tsv}"
RESULT_ROOT="${RESULT_ROOT:-$ROOT/results/arm_aligned_584}"
RUNS="${RUNS:-3}"
WARMUPS="${WARMUPS:-1}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-900}"
BENCH_ARGS_MODE="${BENCH_ARGS_MODE:-none}"

export PATH="/public/software/compiler/dtk-24.04.3/bin:/public/software/compiler/dtk-24.04.3/llvm/bin:/public/software/compiler/dtk-24.04.3/hip/bin:/opt/hyhal/bin:$PATH"
export LD_LIBRARY_PATH="$ROOT/build-phase2/itk-gcc/lib:/public/software/compiler/dtk-24.04.3/lib64:/public/software/compiler/dtk-24.04.3/lib:/public/software/compiler/dtk-24.04.3/hip/lib:/public/software/compiler/dtk-24.04.3/hsa/lib:/public/software/compiler/dtk-24.04.3/.hyhal/lib:/public/software/compiler/dtk-24.04.3/.hyhal/hsa/lib:${LD_LIBRARY_PATH:-}"
export ITK_HIP_FORBID_FALLBACK=1
export ITK_HIP_PRECISION_MODE=default
export ITK_HIP_MIXED_PRECISION=0
export ITK_BENCH_PRECISION=both
export ITK_BENCH_WARMUPS="$WARMUPS"
export ITK_BENCH_RUNS="$RUNS"
export ITK_DCU_DATA_ROOT="$DATA_ROOT"
export ITK_DCU_COMMON_DATA_ROOT="$DATA_ROOT/common"
export ITK_ARM_ALIGNED_PROTOCOL=1
export ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS="${ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS:-4}"

if [[ "${SKIP_DATA_VERIFY:-0}" != 1 && -f "$ROOT/scripts/verify_dcu_dataset.py" ]]; then
  python3 "$ROOT/scripts/verify_dcu_dataset.py" "$DATA_ROOT"
fi

mkdir -p "$RESULT_ROOT/logs"
cp "$MANIFEST" "$RESULT_ROOT/itk_arm_aligned_584.tsv"
if [[ -f "$DATA_ROOT/dataset_manifest.tsv" ]]; then
  cp "$DATA_ROOT/dataset_manifest.tsv" "$RESULT_ROOT/dataset_manifest.tsv"
fi
if [[ -f "$DATA_ROOT/alignment_report.tsv" ]]; then
  cp "$DATA_ROOT/alignment_report.tsv" "$RESULT_ROOT/alignment_report.tsv"
fi
printf 'protocol\tARM-aligned float_vs_double\nscope\t584 functions\nwarmups\t%s\nmeasured_runs\t%s\ninput_root\t%s\nhost\t%s\n' \
  "$WARMUPS" "$RUNS" "$DATA_ROOT" "$(hostname)" > "$RESULT_ROOT/protocol.tsv"
printf 'executable\tstatus\texit_code\tseconds\tlog\n' > "$RESULT_ROOT/target-status.tsv"

while IFS=$'\t' read -r executable; do
  [[ -n "$executable" ]] || continue
  log="$RESULT_ROOT/logs/${executable}.log"
  if [[ ! -x "$TEST_BUILD/$executable" ]]; then
    printf '%s\tNOT_BUILT\t127\t0\t%s\n' "$executable" "$log" >> "$RESULT_ROOT/target-status.tsv"
    printf 'MISSING_EXECUTABLE %s\n' "$TEST_BUILD/$executable" > "$log"
    continue
  fi

  start=$(date +%s)
  if [[ "$BENCH_ARGS_MODE" == "image" ]]; then
    timeout "$TIMEOUT_SECONDS" "$TEST_BUILD/$executable" "$DATA_ROOT/BrainProtonDensity1024.png" "$RUNS" > "$log" 2>&1
  else
    timeout "$TIMEOUT_SECONDS" "$TEST_BUILD/$executable" > "$log" 2>&1
  fi
  rc=$?
  elapsed=$(( $(date +%s) - start ))
  if grep -Eq 'CPU fallback|CPU_FALLBACK|FALLBACK_USED|NO_DCU_BACKEND' "$log"; then
    status=FALLBACK_OR_FORBIDDEN
  elif [[ "$rc" -eq 0 ]]; then
    status=PASS
  elif [[ "$rc" -eq 124 ]]; then
    status=TIMEOUT
  else
    status=FAIL
  fi
  printf '%s\t%s\t%s\t%s\t%s\n' "$executable" "$status" "$rc" "$elapsed" "$log" >> "$RESULT_ROOT/target-status.tsv"
done < <(tail -n +2 "$INVENTORY")

echo "ARM_ALIGNED_RUN_COMPLETE,$RESULT_ROOT"
