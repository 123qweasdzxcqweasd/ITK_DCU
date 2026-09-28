#!/usr/bin/env bash
#SBATCH -p hx1hdnormal
#SBATCH --gres=dcu:1
#SBATCH -N1
#SBATCH -n1
#SBATCH -J itk-unverified
#SBATCH -o /public/home/acmcs42wxa/yyb/build-phase2/logs/unverified_mixed_precision_retest_%j.log
#SBATCH -e /public/home/acmcs42wxa/yyb/build-phase2/logs/unverified_mixed_precision_retest_%j.err

set +e

ROOT=/public/home/acmcs42wxa/yyb
DTK=/public/software/compiler/dtk-24.04.3
TEST="$ROOT/build-phase2/test"
export PATH="$DTK/bin:$DTK/hip/bin:$PATH"
export LD_LIBRARY_PATH="$ROOT/build-phase2/itk-gcc/lib:$DTK/lib64:$DTK/lib:$DTK/hip/lib:$DTK/hsa/lib:$DTK/.hyhal/lib:$DTK/.hyhal/hsa/lib:${LD_LIBRARY_PATH:-}"
export ITK_HIP_FORBID_FALLBACK=1
export ITK_HIP_TRACE=0

benchmarks=(
  hip_anisotropic_smoothing_benchmark
  hip_antialias_benchmark
  hip_convolution_benchmark
  hip_deconvolution_benchmark
  hip_denoising_benchmark
  hip_diffusion_tensor_image_benchmark
  hip_displacement_field_benchmark
  hip_distance_map_benchmark
  hip_image_feature_benchmark
  hip_image_gradient_benchmark
  hip_image_grid_benchmark
  hip_imagegrid2_benchmark
  hip_imagegrid3_benchmark
  hip_image_intensity_benchmark
  hip_image_intensity_remaining_benchmark
  hip_image_sources_benchmark
  hip_image_statistics_benchmark
  hip_image_compare_benchmark
  hip_registration_common_benchmark
  hip_registration_method_benchmark
  hip_registration_metricv4_benchmark
  hip_registration_benchmark
  hip_mathematical_morphology_benchmark
  hip_smoothing_benchmark
  hip_smoothing_extra_benchmark
  hip_thresholding_benchmark
  hip_image_noise_benchmark
  hip_binary_reconstruction_benchmark
)

checks=(
  hip_anisotropic_smoothing_test
  hip_antialias_test
  hip_stage5_n4_test
  hip_difference_gaussian_584_test
  hip_binomial_blur_584_test
  hip_change_information_584_test
  hip_polyline_mask2d_584_test
  hip_polyline_mask3d_584_test
  hip_slice_by_slice_584_test
  hip_binary_pruning_584_test
  hip_binary_thinning_584_test
  hip_connected_components_extended_test
  hip_registration_test
  hip_segmentation_evolution_test
  hip_remaining8_real_test
  hip_smoothing_test
)

run_group() {
  local label="$1"
  local precision="$2"
  export ITK_HIP_PRECISION_MODE="$precision"
  if [[ "$precision" == "fp32_fp64" ]]; then
    export ITK_HIP_MIXED_PRECISION=1
  else
    export ITK_HIP_MIXED_PRECISION=0
  fi
  echo "SUITE_BEGIN label=$label precision=$precision"
  for program in "${benchmarks[@]}"; do
    echo "PROGRAM_BEGIN label=$label kind=benchmark name=$program"
    if [[ -x "$TEST/$program" ]]; then
      timeout 600 "$TEST/$program"
      rc=$?
    else
      rc=127
      echo "MISSING_EXECUTABLE $TEST/$program"
    fi
    echo "PROGRAM_END label=$label kind=benchmark name=$program rc=$rc"
  done
  for program in "${checks[@]}"; do
    echo "PROGRAM_BEGIN label=$label kind=correctness name=$program"
    if [[ -x "$TEST/$program" ]]; then
      timeout 600 "$TEST/$program"
      rc=$?
    else
      rc=127
      echo "MISSING_EXECUTABLE $TEST/$program"
    fi
    echo "PROGRAM_END label=$label kind=correctness name=$program rc=$rc"
  done
  echo "SUITE_END label=$label"
}

run_group ON fp32_fp64
run_group OFF default
echo "SUITE_COMPLETE"
