#!/usr/bin/env bash
set -u

ROOT="${ROOT:-/public/home/acmcs42wxa/yyb}"
OFF_BUILD="${OFF_BUILD:-$ROOT/build-mixed-off/test}"
ON_BUILD="${ON_BUILD:-$ROOT/build-mixed-on/test}"
RESULT_ROOT="${RESULT_ROOT:-$ROOT/test-results/dcu-285-external}"
MANIFEST="${MANIFEST:-$(cd "$(dirname "$0")/.." && pwd)/manifests/dcu_285_test_manifest.tsv}"
DATA_ROOT="${DATA_ROOT:-$ROOT/test-data/dcu-285}"
DTK_ROOT="${DTK_ROOT:-/public/software/compiler/dtk-24.04.3}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-600}"
MODE="${1:-all}"

export PATH="$DTK_ROOT/bin:$DTK_ROOT/llvm/bin:$DTK_ROOT/hip/bin:/opt/hyhal/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
export LD_LIBRARY_PATH="$ROOT/build-phase2/itk-gcc/lib:$DTK_ROOT/lib64:$DTK_ROOT/lib:$DTK_ROOT/hip/lib:$DTK_ROOT/llvm/lib:$DTK_ROOT/hsa/lib:$DTK_ROOT/.hyhal/lib:$DTK_ROOT/.hyhal/hsa/lib:/opt/hyhal/lib:/opt/hyhal/lib64:${LD_LIBRARY_PATH:-}"
export ITK_HIP_FORBID_FALLBACK=1
export ITK_HIP_TRACE="${ITK_HIP_TRACE:-1}"

if [[ "$OFF_BUILD" == "$ON_BUILD" && "${ALLOW_SAME_BUILD:-0}" != 1 ]]; then
  echo "OFF_BUILD and ON_BUILD must be different for external acceptance; set ALLOW_SAME_BUILD=1 only for a smoke test." >&2
  exit 2
fi

mkdir -p "$RESULT_ROOT" "$DATA_ROOT"
if [[ ! -f "$DATA_ROOT/dataset_manifest.tsv" ]]; then
  python3 "$(cd "$(dirname "$0")" && pwd)/generate_dcu_285_data.py" "$DATA_ROOT"
fi

if [[ ! -f "$MANIFEST" ]]; then
  echo "MISSING_MANIFEST,$MANIFEST" >&2
  exit 2
fi
cp "$MANIFEST" "$RESULT_ROOT/dcu_285_test_manifest.tsv"
cp "$DATA_ROOT/dataset_manifest.tsv" "$RESULT_ROOT/dataset_manifest.tsv"

run_mode() {
  local mode="$1"
  local build="$2"
  if [[ "$mode" == "ON" ]]; then
    export ITK_HIP_PRECISION_MODE=fp32_fp64
    export ITK_HIP_MIXED_PRECISION=1
  else
    export ITK_HIP_PRECISION_MODE=default
    export ITK_HIP_MIXED_PRECISION=0
  fi

  local mode_dir="$RESULT_ROOT/$mode"
  mkdir -p "$mode_dir"
  printf 'mode\texecutable\tstatus\texit_code\tlog\n' > "$mode_dir/target-status.tsv"

  awk -F '\t' 'NR > 1 && $7 != "" && !seen[$7]++ {print $7}' "$MANIFEST" |
  while IFS= read -r executable; do
    [[ -n "$executable" ]] || continue
    local log="$mode_dir/${executable}.log"
    local status
    local rc
    echo "PROGRAM_BEGIN mode=$mode name=$executable"
    if [[ ! -x "$build/$executable" ]]; then
      status=NOT_BUILT
      rc=127
      printf '%s\t%s\t%s\t%s\t%s\n' "$mode" "$executable" "$status" "$rc" "$log" >> "$mode_dir/target-status.tsv"
      echo "MISSING_EXECUTABLE $build/$executable" | tee "$log"
      echo "PROGRAM_END mode=$mode name=$executable status=$status exit_code=$rc"
      continue
    fi

    set +e
    timeout "$TIMEOUT_SECONDS" "$build/$executable" > "$log" 2>&1
    rc=$?
    set -e
    if grep -Eq 'CPU fallback|CPU_FALLBACK|FALLBACK_USED|NO_DCU_BACKEND|ITK_HIP_FORBID_FALLBACK.*FAIL' "$log"; then
      status=FALLBACK_OR_FORBIDDEN
    elif [[ "$rc" -eq 0 ]]; then
      status=PASS
    elif [[ "$rc" -eq 124 ]]; then
      status=TIMEOUT
    else
      status=FAIL
    fi
    printf '%s\t%s\t%s\t%s\t%s\n' "$mode" "$executable" "$status" "$rc" "$log" >> "$mode_dir/target-status.tsv"
    cat "$log"
    echo "PROGRAM_END mode=$mode name=$executable status=$status exit_code=$rc"
  done
}

case "$MODE" in
  OFF) run_mode OFF "$OFF_BUILD" ;;
  ON) run_mode ON "$ON_BUILD" ;;
  all)
    run_mode OFF "$OFF_BUILD"
    run_mode ON "$ON_BUILD"
    ;;
  *)
    echo "usage: $0 [OFF|ON|all]" >&2
    exit 2
    ;;
esac

echo "RUN_COMPLETE,$RESULT_ROOT"
