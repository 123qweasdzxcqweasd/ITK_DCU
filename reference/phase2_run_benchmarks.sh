#!/usr/bin/env bash
set -u

build_dir="${TEST_BUILD_DIR:-$HOME/yyb/build-phase2/test}"
itk_build_dir="${ITK_BUILD_DIR:-$HOME/yyb/build-phase2/itk-gcc}"
dtk_root="${DTK_ROOT:-/public/software/compiler/dtk-24.04.3}"
timeout_seconds="${BENCHMARK_TIMEOUT:-300}"

export PATH="$dtk_root/bin:$dtk_root/hip/bin:$PATH"
export LD_LIBRARY_PATH="$itk_build_dir/lib:$dtk_root/lib64:$dtk_root/lib:$dtk_root/hip/lib:$dtk_root/hsa/lib:$dtk_root/.hyhal/lib:$dtk_root/.hyhal/hsa/lib:${LD_LIBRARY_PATH:-}"

if [ -n "${ITK_HIP_BENCHMARK_PRECISION_MODE:-}" ]; then
  precision_mode="$ITK_HIP_BENCHMARK_PRECISION_MODE"
elif [ -n "${ITK_HIP_PRECISION_MODE:-}" ]; then
  precision_mode="$ITK_HIP_PRECISION_MODE"
elif [ "${ITK_HIP_MIXED_PRECISION:-0}" != "0" ]; then
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
if [ "$precision_mode" = "fp16_fp32" ]; then
  export ITK_HIP_MIXED_PRECISION=1
else
  export ITK_HIP_MIXED_PRECISION=0
fi

if [ "$#" -eq 0 ]; then
  set -- \
    hip_smoothing_benchmark \
    hip_anisotropic_smoothing_benchmark \
    hip_antialias_benchmark \
    hip_image_intensity_benchmark \
    hip_thresholding_benchmark \
    hip_image_sources_benchmark \
    hip_colormap_benchmark \
    hip_image_compose_benchmark \
    hip_image_statistics_benchmark \
    hip_image_compare_benchmark \
    hip_convolution_benchmark \
    hip_curvature_flow_benchmark \
    hip_deconvolution_benchmark \
    hip_denoising_benchmark \
    hip_diffusion_tensor_image_benchmark \
    hip_displacement_field_benchmark \
    hip_distance_map_benchmark \
    hip_fast_marching_benchmark \
    hip_fft_benchmark \
    hip_image_fusion_benchmark \
    hip_image_feature_benchmark \
    hip_image_label_benchmark \
    hip_label_map_benchmark \
    hip_mathematical_morphology_benchmark \
    hip_frequency_band_benchmark
fi

cd "$build_dir"
overall=0
summary="${BENCHMARK_SUMMARY:-$HOME/yyb/build-phase2/logs/benchmark-status.tsv}"
mkdir -p "$(dirname "$summary")"
printf 'benchmark\tstatus\texit_code\telapsed_seconds\tprecision_mode\n' > "$summary"
echo "BENCHMARK_PRECISION_REQUEST mode=$precision_mode legacy_mixed=$ITK_HIP_MIXED_PRECISION"
for benchmark in "$@"; do
  start_seconds="$(date +%s)"
  echo "BENCHMARK_BEGIN name=$benchmark"
  timeout "$timeout_seconds" "./$benchmark"
  rc=$?
  elapsed_seconds="$(( $(date +%s) - start_seconds ))"
  if [ "$rc" -eq 0 ]; then
    status=PASS
  elif [ "$rc" -eq 124 ]; then
    status=TIMEOUT
  else
    status=FAIL
  fi
  printf '%s\t%s\t%s\t%s\t%s\n' "$benchmark" "$status" "$rc" "$elapsed_seconds" "$precision_mode" | tee -a "$summary"
  echo "BENCHMARK_END name=$benchmark status=$status exit_code=$rc elapsed_seconds=$elapsed_seconds"
  if [ "$rc" -ne 0 ]; then
    overall=1
  fi
done

exit "$overall"
