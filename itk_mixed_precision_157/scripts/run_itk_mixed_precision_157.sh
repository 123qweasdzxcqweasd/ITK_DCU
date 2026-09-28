#!/usr/bin/env bash
set -u

ROOT="${ROOT:-$HOME/yyb}"
OFF_TEST_BUILD="${OFF_TEST_BUILD:-$ROOT/build-test-port-baseline-584}"
ON_TEST_BUILD="${ON_TEST_BUILD:-$ROOT/build-test-mixed-precision-157}"
RESULT_ROOT="${RESULT_ROOT:-$ROOT/results/itk-mixed-precision-157}"
DATA_ROOT="${DATA_ROOT:-$ROOT/data}"
DATA_VALIDATOR="${DATA_VALIDATOR:-$ROOT/scripts/verify_dcu_dataset.py}"
MANIFEST="${MANIFEST:-$(cd "$(dirname "$0")/.." && pwd)/manifests/itk_mixed_precision_157.tsv}"
INVENTORY="${INVENTORY:-$(cd "$(dirname "$0")/.." && pwd)/manifests/benchmark_inventory.tsv}"
DTK_ROOT="${DTK_ROOT:-/public/software/compiler/dtk-24.04.3}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-600}"

if [[ "$OFF_TEST_BUILD" == "$ON_TEST_BUILD" && "${ALLOW_SAME_BUILD:-0}" != 1 ]]; then
  echo "OFF_TEST_BUILD and ON_TEST_BUILD must be different." >&2
  exit 2
fi

export PATH="$DTK_ROOT/bin:$DTK_ROOT/llvm/bin:$DTK_ROOT/hip/bin:$PATH"
export LD_LIBRARY_PATH="$ROOT/build-itk-port-baseline-584/lib:$ROOT/build-itk-mixed-precision-157/lib:$DTK_ROOT/lib64:$DTK_ROOT/lib:$DTK_ROOT/hip/lib:$DTK_ROOT/hsa/lib:$DTK_ROOT/.hyhal/lib:$DTK_ROOT/.hyhal/hsa/lib:${LD_LIBRARY_PATH:-}"
export ITK_HIP_FORBID_FALLBACK=1
export ITK_HIP_TRACE="${ITK_HIP_TRACE:-1}"
export ITK_DCU_DATA_ROOT="$DATA_ROOT"
export ITK_DCU_COMMON_DATA_ROOT="$DATA_ROOT/common"

mkdir -p "$RESULT_ROOT/OFF" "$RESULT_ROOT/ON"
if [[ "${SKIP_DATA_VERIFY:-0}" != 1 ]]; then
  python3 "$DATA_VALIDATOR" "$DATA_ROOT"
fi
cp "$MANIFEST" "$RESULT_ROOT/itk_mixed_precision_157.tsv"
if [[ -f "$DATA_ROOT/dataset_manifest.tsv" ]]; then
  cp "$DATA_ROOT/dataset_manifest.tsv" "$RESULT_ROOT/dataset_manifest.tsv"
fi
if [[ -f "$DATA_ROOT/alignment_report.tsv" ]]; then
  cp "$DATA_ROOT/alignment_report.tsv" "$RESULT_ROOT/alignment_report.tsv"
fi

run_mode() {
  local label="$1"
  local build="$2"
  local precision="$3"
  local mixed="$4"
  export ITK_HIP_PRECISION_MODE="$precision"
  export ITK_HIP_MIXED_PRECISION="$mixed"
  printf 'version\tmode\texecutable\tstatus\texit_code\tlog\n' > "$RESULT_ROOT/$label/target-status.tsv"
  local overall=0
  while IFS=$'\t' read -r executable; do
    [[ -n "$executable" ]] || continue
    local log="$RESULT_ROOT/$label/${executable}.log"
    if [[ ! -x "$build/$executable" ]]; then
      printf 'ITK_MIXED_PRECISION_157\t%s\t%s\tNOT_BUILT\t127\t%s\n' "$label" "$executable" "$log" | tee -a "$RESULT_ROOT/$label/target-status.tsv"
      printf 'MISSING_EXECUTABLE %s\n' "$build/$executable" > "$log"
      overall=1
      continue
    fi
    timeout "$TIMEOUT_SECONDS" "$build/$executable" > "$log" 2>&1
    local rc=$?
    local status
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
    printf 'ITK_MIXED_PRECISION_157\t%s\t%s\t%s\t%s\t%s\n' "$label" "$executable" "$status" "$rc" "$log" | tee -a "$RESULT_ROOT/$label/target-status.tsv"
  done < <(tail -n +2 "$INVENTORY")
  return "$overall"
}

off_rc=0
on_rc=0
run_mode OFF "$OFF_TEST_BUILD" default 0 || off_rc=$?
run_mode ON "$ON_TEST_BUILD" fp32_fp64 1 || on_rc=$?
echo "RUN_COMPLETE,$RESULT_ROOT,OFF_RC=$off_rc,ON_RC=$on_rc"
if [[ "$off_rc" -ne 0 || "$on_rc" -ne 0 ]]; then exit 1; fi
