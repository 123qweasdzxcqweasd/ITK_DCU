# ITK DCU 双版本测试目录

本目录按两个明确版本组织 DCU 平台 ITK 测试：

| 版本目录 | 函数范围 | 主要用途 |
|---|---:|---|
| `itk_port_baseline_584/` | 584 个函数 | ITK 移植基线版，确认默认 DCU/HIP 路径 |
| `itk_mixed_precision_157/` | 157 个函数 | ITK 混合精度版，确认满足误差和加速条件的函数 |

## 版本边界

### ITK 移植基线版

编译和运行均关闭混合精度：

```text
ITK_ENABLE_MIXED_PRECISION=OFF
ITK_HIP_PRECISION_MODE=default
ITK_HIP_MIXED_PRECISION=0
```

该版本覆盖 584 个函数，不用于把混合精度收益写入基线结果。

### ITK 混合精度版

只包含以下 157 个函数：

```text
DCU 混合精度加速比 > 1
且
DCU 混合精度误差 max_abs <= 1e-5
```

该版本必须使用不同的 OFF/ON 构建：

```text
OFF: ITK_ENABLE_MIXED_PRECISION=OFF
ON : ITK_ENABLE_MIXED_PRECISION=ON
```

ON 运行时使用：

```text
ITK_HIP_PRECISION_MODE=fp32_fp64
ITK_HIP_MIXED_PRECISION=1
ITK_HIP_FORBID_FALLBACK=1
```

## 数据和测试入口

根目录 `data/` 是两版共享的确定性数据。两版的函数清单和结果目录独立。
测试程序按 ITK 模块组织，不是每个函数一个二进制；脚本运行模块级
benchmark/correctness 入口，汇总脚本根据 `UNIFIED_METRIC function=...`
按函数提取结果。

根目录下的 285 函数外部检测文件作为兼容检测资料保留；正式按版本送测时，
以两个版本目录中的 README、manifest 和 scripts 为准。

## 推荐顺序

```bash
cd itk_port_baseline_584
bash scripts/build_itk_port_baseline.sh
bash scripts/run_itk_port_baseline_584.sh
python3 scripts/collect_baseline_metrics.py \
  "$RESULT_ROOT" "$RESULT_ROOT/itk_port_baseline_584_summary.csv"

cd ../itk_mixed_precision_157
bash scripts/build_itk_mixed_precision_157.sh
bash scripts/run_itk_mixed_precision_157.sh
python3 scripts/collect_mixed_precision_157.py \
  "$RESULT_ROOT" "$RESULT_ROOT/itk_mixed_precision_157_summary.csv"
```
