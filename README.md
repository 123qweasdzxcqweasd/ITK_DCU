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

根目录 `data/common/` 是 ARM/DCU 两个平台共用的标准图像数据；
`data/dcu_legacy/` 保留 DCU 原有的 MHA/CSV 结构化数据。根目录下的 6 个
PNG 是当前可执行程序的兼容路径副本，已与 `data/common/` 按 SHA-256 对齐。
两版的函数清单和结果目录独立。
测试程序按 ITK 模块组织，不是每个函数一个二进制；脚本运行模块级
benchmark/correctness 入口，汇总脚本根据 `UNIFIED_METRIC function=...`
按函数提取结果。

根目录下的 285 函数外部检测文件作为兼容检测资料保留；正式按版本送测时，
以两个版本目录中的 README、manifest 和 scripts 为准。

## ARM 对齐的 584 函数测试

为与 ARM 平台 `ITK_ECNU/ITK_ECNU/lingsheng592` 的测试口径一致，新增了
一套覆盖全部 584 个函数的 DCU 测试入口：

```text
manifests/itk_arm_aligned_584.tsv       584 个 ARM 对齐测试条目
scripts/run_arm_aligned_584.sh          DCU 运行入口
scripts/submit_arm_aligned_584.sh       Slurm 提交入口
scripts/collect_arm_aligned_metrics.py  结果汇总
scripts/verify_arm_alignment.py         ARM/DCU 图像哈希校验
reference/arm/                           ARM 参考清单和原始说明
```

这套入口采用以下固定口径：

- 2D 标量图使用 `data/BrainProtonDensity1024.png`；
- 配准使用 `BrainProtonDensity1024_fixed.png` 和
  `BrainProtonDensity1024_moving.png`；
- Hough、细化、网格、点集、复数等函数使用清单指定的固定生成对象；
- 同一输入分别测试 float 和 double，预热 1 次、正式测量 3 次；
- ARM 对齐加速比为 `double_ms / float_ms`，误差为 float 相对 double 的
  `max_abs` 或清单指定的对象域指标；
- DCU 的 OFF/ON 时间和收益单独记录，不与 ARM 对齐加速比混为一列；
- `ITK_HIP_FORBID_FALLBACK=1`，发现 CPU fallback 时不得记为通过。

当前状态：脚本、584 条清单和数据校验入口已经写入本目录；现有工作簿中的
历史 G-L 数据保留，尚未按这套新口径重新完成一轮 DCU 584 函数测试。
因此新口径清单中的结果字段暂时为空，不能把旧数据直接标成 ARM 对齐结果。

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

如需按 ARM 口径运行全部 584 个函数：

```bash
cd "$ROOT"
python3 scripts/verify_arm_alignment.py \
  /path/to/ITK_ECNU/ITK_ECNU/test/data \
  "$ROOT/data"
bash scripts/run_arm_aligned_584.sh
python3 scripts/collect_arm_aligned_metrics.py \
  "$ROOT/results/arm_aligned_584" \
  "$ROOT/results/arm_aligned_584/arm_aligned_584_summary.csv"
```

`run_arm_aligned_584.sh` 默认保留当前 DCU 模块级 benchmark 的无参数入口；
如果测试程序已经实现 ARM 对齐的文件参数接口，可设置
`BENCH_ARGS_MODE=image`，由脚本传入标准 1024 图像路径。
