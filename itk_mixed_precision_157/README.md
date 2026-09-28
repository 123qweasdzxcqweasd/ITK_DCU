# ITK 混合精度版

## 范围

本版本只包含 157 个函数，选择条件为：

```text
DCU 混合精度加速比 > 1
且
DCU 混合精度误差 max_abs <= 1e-5
```

这 157 个函数来自 ARM/DCU 同时可做混合精度的交集。运行时使用同一批
模块级入口，结果汇总只保留清单中的 157 个函数。

## 构建语义

需要两套不同的 ITK 和测试程序构建：

```bash
cmake ... -DITK_ENABLE_MIXED_PRECISION=OFF
cmake ... -DITK_ENABLE_MIXED_PRECISION=ON
```

OFF 用于参考路径，ON 用于混合精度路径。不能只使用同一个二进制再切换
环境变量冒充两套构建。

ON 运行时：

```text
ITK_HIP_PRECISION_MODE=fp32_fp64
ITK_HIP_MIXED_PRECISION=1
ITK_HIP_FORBID_FALLBACK=1
```

## 文件

```text
manifests/itk_mixed_precision_157.tsv 157 个目标函数
manifests/benchmark_inventory.tsv     对应模块入口
scripts/build_itk_mixed_precision_157.sh
scripts/run_itk_mixed_precision_157.sh
scripts/collect_mixed_precision_157.py
results/                              OFF/ON 日志和汇总
```

## 运行

```bash
export ROOT=/public/home/acmcs42wxa/yyb
export OFF_ITK_BUILD=$ROOT/build-itk-port-baseline-584
export ON_ITK_BUILD=$ROOT/build-itk-mixed-precision-157
export OFF_TEST_BUILD=$ROOT/build-test-port-baseline-584
export ON_TEST_BUILD=$ROOT/build-test-mixed-precision-157
export RESULT_ROOT=$ROOT/results/itk-mixed-precision-157

bash scripts/build_itk_mixed_precision_157.sh
bash scripts/run_itk_mixed_precision_157.sh
python3 scripts/collect_mixed_precision_157.py \
  "$RESULT_ROOT" "$RESULT_ROOT/itk_mixed_precision_157_summary.csv"
```

汇总中的 `mixed_speedup` 定义为 `OFF DCU 时间 / ON DCU 时间`，
`mixed_error` 使用 ON 运行输出的统一误差字段。

