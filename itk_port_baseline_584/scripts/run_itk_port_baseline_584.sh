#!/usr/bin/env bash
set -u

ROOT="${ROOT:-$HOME/yyb}"
TEST_BUILD_DIR="${TEST_BUILD_DIR:-$ROOT/build-test-port-baseline-584}"
RESULT_ROOT="${RESULT_ROOT:-$ROOT/results/itk-port-baseline-584}"
DATA_ROOT="${DATA_ROOT:-$ROOT/data}"
DATA_VALIDATOR="${DATA_VALIDATOR:-$ROOT/scripts/verify_dcu_dataset.py}"
MANIFEST="${MANIFEST:-$(cd "$(dirname "$0")/.." && pwd)/manifests/itk_port_baseline_584.tsv}"
INVENTORY="${INVENTORY:-$(cd "$(dirname "$0")/.." && pwd)/manifests/benchmark_inventory.tsv}"
DTK_ROOT="${DTK_ROOT:-/public/software/compiler/dtk-24.04.3}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-600}"

export PATH="$DTK_ROOT/bin:$DTK_ROOT/llvm/bin:$DTK_ROOT/hip/bin:$PATH"
export LD_LIBRARY_PATH="$ROOT/build-itk-port-baseline-584/lib:$DTK_ROOT/lib64:$DTK_ROOT/lib:$DTK_ROOT/hip/lib:$DTK_ROOT/hsa/lib:$DTK_ROOT/.hyhal/lib:$DTK_ROOT/.hyhal/hsa/lib:${LD_LIBRARY_PATH:-}"
export ITK_HIP_FORBID_FALLBACK=1
export ITK_HIP_TRACE="${ITK_HIP_TRACE:-1}"
export ITK_HIP_PRECISION_MODE=default
export ITK_HIP_MIXED_PRECISION=0
export ITK_DCU_DATA_ROOT="$DATA_ROOT"
export ITK_DCU_COMMON_DATA_ROOT="$DATA_ROOT/common"

mkdir -p "$RESULT_ROOT"
if [[ "${SKIP_DATA_VERIFY:-0}" != 1 ]]; then
  python3 "$DATA_VALIDATOR" "$DATA_ROOT"
fi
cp "$MANIFEST" "$RESULT_ROOT/itk_port_baseline_584.tsv"
if [[ -f "$DATA_ROOT/dataset_manifest.tsv" ]]; then
  cp "$DATA_ROOT/dataset_manifest.tsv" "$RESULT_ROOT/dataset_manifest.tsv"
fi
if [[ -f "$DATA_ROOT/alignment_report.tsv" ]]; then
  cp "$DATA_ROOT/alignment_report.tsv" "$RESULT_ROOT/alignment_report.tsv"
fi
printf 'version\texecutable\tstatus\texit_code\tlog\n' > "$RESULT_ROOT/target-status.tsv"

overall=0
while IFS=$'\t' read -r executable; do
  [[ -n "$executable" ]] || continue
  log="$RESULT_ROOT/${executable}.log"
  if [[ ! -x "$TEST_BUILD_DIR/$executable" ]]; then
    printf 'ITK_PORT_BASELINE_584\t%s\tNOT_BUILT\t127\t%s\n' "$executable" "$log" | tee -a "$RESULT_ROOT/target-status.tsv"
    printf 'MISSING_EXECUTABLE %s\n' "$TEST_BUILD_DIR/$executable" > "$log"
    overall=1
    continue
  fi
  timeout "$TIMEOUT_SECONDS" "$TEST_BUILD_DIR/$executable" > "$log" 2>&1
  rc=$?
  if grep -Eq 'CPU fallback|CPU_FALLBACK|FALLBACK_USED|NO_DCU_BACKEND' "$log"; then
    status=FALLBACK_OR_FORBIDDEN
    overall=1
  elif [[ "$rc" -eq 0 ]]; then
    status=PASS
  elif [[ "$rc" -eq 124 ]]; then
    status=TIMEOUT
    overall=1
  else
    status=FAIL
    overall=1
  fi
  printf 'ITK_PORT_BASELINE_584\t%s\t%s\t%s\t%s\n' "$executable" "$status" "$rc" "$log" | tee -a "$RESULT_ROOT/target-status.tsv"
done < <(tail -n +2 "$INVENTORY")

echo "RUN_COMPLETE,$RESULT_ROOT"
exit "$overall"
