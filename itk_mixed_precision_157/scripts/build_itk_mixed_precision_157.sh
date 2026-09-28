#!/usr/bin/env bash
set -eu

ROOT="${ROOT:-$HOME/yyb}"
SOURCE_DIR="${SOURCE_DIR:-$ROOT/InsightToolkit-5.4.3}"
OFF_ITK_BUILD="${OFF_ITK_BUILD:-$ROOT/build-itk-port-baseline-584}"
ON_ITK_BUILD="${ON_ITK_BUILD:-$ROOT/build-itk-mixed-precision-157}"
OFF_TEST_SOURCE_DIR="${OFF_TEST_SOURCE_DIR:-$ROOT/test}"
ON_TEST_SOURCE_DIR="${ON_TEST_SOURCE_DIR:-$ROOT/test-mixed-precision}"
OFF_TEST_BUILD="${OFF_TEST_BUILD:-$ROOT/build-test-port-baseline-584}"
ON_TEST_BUILD="${ON_TEST_BUILD:-$ROOT/build-test-mixed-precision-157}"
DTK_ROOT="${DTK_ROOT:-/public/software/compiler/dtk-24.04.3}"
PARALLEL_JOBS="${PARALLEL_JOBS:-8}"

configure_build() {
  local build_dir="$1"
  local mixed="$2"
  cmake -S "$SOURCE_DIR" -B "$build_dir" \
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
    -DITK_ENABLE_MIXED_PRECISION="$mixed"
  cmake --build "$build_dir" --parallel "$PARALLEL_JOBS"
}

configure_build "$OFF_ITK_BUILD" OFF
configure_build "$ON_ITK_BUILD" ON

configure_test() {
  local source_dir="$1"
  local build_dir="$2"
  local itk_build_dir="$3"
  local mixed="$4"
  if [[ ! -f "$source_dir/CMakeLists.txt" ]]; then
    echo "TEST_SOURCE_DIR does not contain CMakeLists.txt; skip test-program build: $source_dir" >&2
    return 0
  fi
  cmake -S "$source_dir" -B "$build_dir" \
    -DCMAKE_BUILD_TYPE=Release \
    -DITK_DIR="$itk_build_dir/lib/cmake/ITK-5.4" \
    -DITK_ENABLE_MIXED_PRECISION="$mixed"
  cmake --build "$build_dir" --parallel "$PARALLEL_JOBS"
}

configure_test "$OFF_TEST_SOURCE_DIR" "$OFF_TEST_BUILD" "$OFF_ITK_BUILD" OFF
configure_test "$ON_TEST_SOURCE_DIR" "$ON_TEST_BUILD" "$ON_ITK_BUILD" ON
