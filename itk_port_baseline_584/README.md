# ITK 移植基线版

## 范围

- 函数范围：ITK 移植基线中的全部 584 个函数。
- 版本语义：只验证移植后的默认 DCU/HIP 路径。
- 编译开关：`ITK_ENABLE_MIXED_PRECISION=OFF`。
- 运行变量：

```text
ITK_HIP_PRECISION_MODE=default
ITK_HIP_MIXED_PRECISION=0
ITK_HIP_FORBID_FALLBACK=1
```

该版本不用于统计混合精度加速。它的目标是确认 584 个函数的移植入口、
正确性、DCU 执行状态和默认路径性能。

## 文件

```text
manifests/itk_port_baseline_584.tsv   584 个函数清单
manifests/benchmark_inventory.tsv     模块级 benchmark/correctness 入口
scripts/build_itk_port_baseline.sh   构建 OFF 版 ITK
scripts/run_itk_port_baseline_584.sh 运行基线版
scripts/collect_baseline_metrics.py   汇总基线指标
results/                              运行结果
```

清单按函数记录，程序按模块级入口执行。一个模块程序可能覆盖多个函数；
抽象基类、模板接口和无独立入口的函数按清单中的代表性覆盖说明记录，
不能把代表性结果冒充独立函数结果。

`manifests/itk_port_baseline_584.tsv` 的 `data_source` 是送测输入契约：
`internal_deterministic` 表示按清单固定公式、类型、尺寸和参数生成，
`package_file:<文件名>` 表示读取随包文件。不同输入源的结果分别汇总。

运行脚本默认使用 `$ROOT/data`，启动前校验 `data/common/` 的 ARM/DCU
共用图像和根目录兼容副本；如需指定其他数据目录，设置 `DATA_ROOT`，
并同时提供 `DATA_ROOT/dataset_manifest.tsv`。

## 运行

```bash
export ROOT=/public/home/acmcs42wxa/yyb
export ITK_BUILD_DIR=$ROOT/build-itk-port-baseline-584
export TEST_BUILD_DIR=$ROOT/build-test-port-baseline-584
export RESULT_ROOT=$ROOT/results/itk-port-baseline-584

bash scripts/build_itk_port_baseline.sh
bash scripts/run_itk_port_baseline_584.sh
python3 scripts/collect_baseline_metrics.py \
  "$RESULT_ROOT" "$RESULT_ROOT/itk_port_baseline_584_summary.csv"
```

正式验收时必须保留 `target-status.tsv`、全部日志、清单、数据清单、
DCU 型号、DTK 版本和 CMake 日志。
