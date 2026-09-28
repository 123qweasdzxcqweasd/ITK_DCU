#!/usr/bin/env bash
set -eu

ROOT="${ROOT:-$HOME/yyb}"
SOURCE_DIR="${SOURCE_DIR:-$ROOT/InsightToolkit-5.4.3}"
ITK_BUILD_DIR="${ITK_BUILD_DIR:-$ROOT/build-itk-port-baseline-584}"
TEST_SOURCE_DIR="${TEST_SOURCE_DIR:-$ROOT/test}"
TEST_BUILD_DIR="${TEST_BUILD_DIR:-$ROOT/build-test-port-baseline-584}"
DTK_ROOT="${DTK_ROOT:-/public/software/compiler/dtk-24.04.3}"
PARALLEL_JOBS="${PARALLEL_JOBS:-8}"

cmake -S "$SOURCE_DIR" -B "$ITK_BUILD_DIR" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_CXX_COMPILER=/usr/bin/g++ \
  -DCMAKE_C_COMPILER=/usr/bin/gcc \
  -DBUILD_SHARED_LIBS=ON \
  -DBUILD_TESTING=OFF \
  -DITK_BUILD_DEFAULT_MODULES=OFF \
  -DITK_BUILD_EXAMPLES=OFF \
  -DITK_WRAP_PYTHON=OFF \
  -DITK_USE_HIP=ON \
  -DHIP_ROOT="$DTK_ROOT" \
  -DITK_ENABLE_MIXED_PRECISION=OFF

cmake --build "$ITK_BUILD_DIR" --parallel "$PARALLEL_JOBS"

if [[ -f "$TEST_SOURCE_DIR/CMakeLists.txt" ]]; then
  cmake -S "$TEST_SOURCE_DIR" -B "$TEST_BUILD_DIR" \
    -DCMAKE_BUILD_TYPE=Release \
    -DITK_DIR="$ITK_BUILD_DIR/lib/cmake/ITK-5.4" \
    -DITK_ENABLE_MIXED_PRECISION=OFF
  cmake --build "$TEST_BUILD_DIR" --parallel "$PARALLEL_JOBS"
else
  echo "TEST_SOURCE_DIR does not contain CMakeLists.txt; skip test-program build: $TEST_SOURCE_DIR" >&2
fi
