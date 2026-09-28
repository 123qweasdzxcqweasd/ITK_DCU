#!/bin/bash
set -uo pipefail

if [[ $# -lt 3 ]]; then
  echo "usage: run_test.sh <correctness|backend> <module> <executable> [args...]" >&2
  exit 2
fi

kind=$1
module=$2
shift 2

tmp_dir=$(mktemp -d)
trap 'rm -rf -- "$tmp_dir"' EXIT
log_file="$tmp_dir/test.log"

echo "TEST_BEGIN kind=$kind module=$module seed=5489 executable=$1"
set +e
"$@" 2>&1 | tee "$log_file"
status=${PIPESTATUS[0]}
set -e

if [[ $status -eq 0 && $kind == backend ]]; then
  if ! grep -Eq 'ITK_HIP_KERNEL|BACKEND:(HIP|HYBRID)' "$log_file"; then
    echo "TEST_FAILURE kind=backend module=$module reason=no_kernel_or_backend_record" >&2
    status=3
  fi
fi

if [[ $status -eq 0 ]]; then
  echo "TEST_RESULT kind=$kind module=$module status=PASS exit_code=0"
else
  echo "TEST_RESULT kind=$kind module=$module status=FAIL exit_code=$status" >&2
fi
exit "$status"
