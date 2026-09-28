#!/bin/bash
set -euo pipefail

if [[ ${ITK_HIP_RUN_BENCHMARKS:-0} != 1 ]]; then
  echo "BENCHMARK_DISABLED: set ITK_HIP_RUN_BENCHMARKS=1 or use the stage6-benchmark preset"
  exit 0
fi
if [[ $# -lt 4 ]]; then
  echo "usage: run_benchmark.sh <module> <correctness command...> -- <benchmark command...>" >&2
  exit 2
fi

module=$1
shift
correctness_command=()
while [[ $# -gt 0 && $1 != -- ]]; do
  correctness_command+=("$1")
  shift
done
if [[ $# -eq 0 ]]; then
  echo "benchmark command delimiter is missing" >&2
  exit 2
fi
shift
benchmark_command=("$@")

if [[ -n "${ITK_HIP_BENCHMARK_PRECISION_MODE:-}" ]]; then
  precision_mode="$ITK_HIP_BENCHMARK_PRECISION_MODE"
elif [[ -n "${ITK_HIP_PRECISION_MODE:-}" ]]; then
  precision_mode="$ITK_HIP_PRECISION_MODE"
elif [[ "${ITK_HIP_MIXED_PRECISION:-0}" != "0" ]]; then
  precision_mode="fp16_fp32"
else
  precision_mode="default"
fi
case "$precision_mode" in
  default|fp32_fp64|fp16_fp32) ;;
  *)
    echo "unsupported benchmark precision mode: $precision_mode (expected default, fp32_fp64, or fp16_fp32)" >&2
    exit 2
    ;;
esac
export ITK_HIP_PRECISION_MODE="$precision_mode"
if [[ "$precision_mode" == "fp16_fp32" ]]; then
  export ITK_HIP_MIXED_PRECISION=1
else
  export ITK_HIP_MIXED_PRECISION=0
fi

warmups=${ITK_HIP_BENCHMARK_WARMUPS:-1}
repeats=${ITK_HIP_BENCHMARK_REPEATS:-3}
if (( warmups < 1 || repeats < 3 )); then
  echo "benchmark protocol requires at least 1 warmup and 3 measured repeats" >&2
  exit 2
fi

echo "BENCHMARK_CORRECTNESS_BEGIN module=$module"
"${correctness_command[@]}"
echo "BENCHMARK_CORRECTNESS_RESULT module=$module status=PASS"
echo "BENCHMARK_PROTOCOL module=$module warmups=$warmups repeats=$repeats initialization=child_defined external_metric=end_to_end_ms"
echo "BENCHMARK_PRECISION_REQUEST module=$module mode=$precision_mode legacy_mixed=$ITK_HIP_MIXED_PRECISION"

for ((i = 0; i < warmups; ++i)); do
  "${benchmark_command[@]}" >/dev/null
done

tmp_dir=$(mktemp -d)
trap 'rm -rf -- "$tmp_dir"' EXIT
samples=()
for ((i = 0; i < repeats; ++i)); do
  start_ns=$(date +%s%N)
  "${benchmark_command[@]}" >"$tmp_dir/run_$i.log" 2>&1
  end_ns=$(date +%s%N)
  samples+=("$(((end_ns - start_ns) / 1000000))")
done

cat "$tmp_dir/run_0.log"
mapfile -t sorted < <(printf '%s\n' "${samples[@]}" | sort -n)
middle=$((repeats / 2))
if (( repeats % 2 == 1 )); then
  median_ms=${sorted[$middle]}
else
  median_ms=$(((sorted[middle - 1] + sorted[middle]) / 2))
fi
min_ms=${sorted[0]}
max_ms=${sorted[repeats - 1]}
range_ms=$((max_ms - min_ms))
sample_csv=$(IFS=,; echo "${samples[*]}")

echo "BENCHMARK_PHASES cpu_total=child_report h2d=child_report_or_NA kernel_or_hipfft=child_report_or_NA d2h=child_report_or_NA hip_end_to_end=child_report"
echo "BENCHMARK_RESULT module=$module status=PASS median_ms=$median_ms min_ms=$min_ms max_ms=$max_ms range_ms=$range_ms samples_ms=$sample_csv"
