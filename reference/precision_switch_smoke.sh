#!/usr/bin/env bash
set -u

export PATH=/public/software/compiler/dtk-24.04.3/hip/bin:/usr/local/bin:/usr/bin:/bin
export LD_LIBRARY_PATH=/public/home/acmcs42wxa/yyb/build-phase2/itk-gcc/lib:/public/software/compiler/dtk-24.04.3/lib64:/public/software/compiler/dtk-24.04.3/lib:/public/software/compiler/dtk-24.04.3/hip/lib:/public/software/compiler/dtk-24.04.3/hsa/lib:/public/software/compiler/dtk-24.04.3/.hyhal/lib:/public/software/compiler/dtk-24.04.3/.hyhal/hsa/lib
cd /public/home/acmcs42wxa/yyb/build-phase2/test

ITK_HIP_PRECISION_MODE=default ./hip_convolution_benchmark 64 64 > /tmp/precision_default.log 2>&1
default_rc=$?
ITK_HIP_PRECISION_MODE=fp16_fp32 ./hip_convolution_benchmark 64 64 > /tmp/precision_fp16.log 2>&1
mixed_rc=$?

echo "DEFAULT_RC=$default_rc"
grep -E "UNIFIED_METRIC|UNIFIED_PRECISION" /tmp/precision_default.log | head -10
echo "MIXED_RC=$mixed_rc"
grep -E "UNIFIED_METRIC|UNIFIED_PRECISION" /tmp/precision_fp16.log | head -10

test "$default_rc" -eq 0
test "$mixed_rc" -ne 0
