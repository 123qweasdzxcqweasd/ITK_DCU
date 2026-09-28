# DCU ITK 外部统一检测目录说明

本目录是面向 DCU/HIP 平台的 ITK 混合精度外部检测包。它参考 ARM 平台的
`data/src/scripts/results` 组织方式，但将 DCU 的构建开关、设备检查、禁止
CPU fallback 和 OFF/ON 双构建要求单独落实。

## 目录内容

| 目录 | 内容 |
|---|---|
| `data/` | 可复现的确定性输入数据，以及 `dataset_manifest.tsv` |
| `manifests/` | 285 个函数清单、对应模块入口和测试方法 |
| `reference/` | 构建参考、统一指标输出头文件和已有工作簿 |
| `scripts/` | 生成数据、运行 OFF/ON、汇总结果的脚本 |
| `results/` | 运行脚本后产生的日志、状态和 CSV 结果 |

## 送测前必须准备

需要准备两套不同的 ITK 构建：

```bash
cmake -S /path/to/itk -B /path/to/itk-off \
  -DITK_ENABLE_MIXED_PRECISION=OFF
cmake --build /path/to/itk-off --parallel 8

cmake -S /path/to/itk -B /path/to/itk-on \
  -DITK_ENABLE_MIXED_PRECISION=ON
cmake --build /path/to/itk-on --parallel 8
```

OFF 和 ON 不能只靠运行时变量伪装成两种构建。正式验收时，
`OFF_BUILD` 和 `ON_BUILD` 必须指向两个不同的测试程序构建目录。

同时确认：

```bash
which hipcc
rocminfo | head
test -x "$OFF_BUILD/<测试程序>"
test -x "$ON_BUILD/<测试程序>"
```

## 正式运行顺序

```bash
export OFF_BUILD=/path/to/test-build-off
export ON_BUILD=/path/to/test-build-on
export RESULT_ROOT=/path/to/results/dcu-285-external
export DATA_ROOT=/path/to/data/dcu-285
export DTK_ROOT=/public/software/compiler/dtk-24.04.3

python3 scripts/generate_dcu_285_data.py "$DATA_ROOT"
bash scripts/run_dcu_285_external.sh OFF
bash scripts/run_dcu_285_external.sh ON
python3 scripts/collect_unified_metrics.py \
  "$RESULT_ROOT" "$RESULT_ROOT/dcu_285_summary.csv"
```

正式检测时脚本会设置：

```text
ITK_HIP_FORBID_FALLBACK=1
ITK_HIP_TRACE=1
```

如果程序发生 CPU fallback、没有 DCU backend、目标程序不存在或超时，
结果不会记为通过，而会在 `target-status.tsv` 中标记。

## 数据来源规则

当前统一回归数据优先使用程序内部按固定公式生成的确定性数据，保证
CPU/DCU、OFF/ON 之间可复现。`data/` 中另附 1024 x 1024 标量图、二值图、
标签图、向量图、复数图、RGB 图、3D 体数据、张量数据和点集文件，供
file-driven benchmark 或外部复核使用。

不能把“随便一张 1024 x 1024 图片”作为全部函数的统一输入。滤波器、
形态学、FFT、注册、点集、网格、水平集和随机算法需要分别使用清单规定的
数据类型、维度、参数和误差指标。官方图像或真实业务图像应作为第二层
代表性验证数据，并在结果中注明文件来源。

## 结果回传

外部检测完成后至少回传：

```text
dcu_285_summary.csv
OFF/target-status.tsv
ON/target-status.tsv
OFF/*.log
ON/*.log
dataset_manifest.tsv
```

另外请记录 DCU 型号、驱动/DTK 版本、ITK 提交号、CMake 配置和失败程序的
完整 stdout/stderr。

