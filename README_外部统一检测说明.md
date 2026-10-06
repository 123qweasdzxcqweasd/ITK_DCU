# DCU 平台 285 个共同可做混合精度函数外部检测包

## 1. 检测范围

`manifests/dcu_285_test_manifest.tsv` 是本次外部检测的权威清单，共 285 个函数。清单中的每一行包含：

- 模块和函数名；
- 对应的 DCU 模块级 benchmark/correctness 程序；
- 测试方法；
- 数据来源；
- 当前程序的默认尺寸或参数口径；
- 当前主表中的测试证据状态。

这 285 个函数不是 285 个独立可执行文件。当前 DCU 测试体系是：

1. 一个统一启动器设置运行环境和精度模式；
2. 一个模块级程序依次实例化同一模块中的多个函数；
3. `hip_unified_metric.h` 统一输出 CPU/DCU 时间、误差和精度遥测。

当前盘点结果：

- 285 个函数；
- 283 个函数有模块级统一入口；
- 2 个函数没有独立函数级入口，需要单独增加 benchmark；
- 239 个函数已经形成 G-L 完整记录；
- 44 个函数已有部分记录。

## 2. 数据来源与记录要求

本送测包规定两类标准输入源，且每条测试记录必须在
`manifests/dcu_285_test_manifest.tsv` 的 `data_source` 字段中明确标注：

1. `internal_deterministic`：由对应 benchmark 按清单规定的固定公式、
   数据类型、维度、尺寸和参数生成。公式、参数和生成方式属于测试协议，
   不依赖随机数，重复执行应得到同一输入。
2. `package_file:<文件名>`：读取本包 `data/` 中指定的数据文件。文件名、
   数据类型、尺寸和生成方式以 `data/dataset_manifest.tsv` 为准。

现有模块级入口应按清单执行；程序内生成输入的入口记录为
`internal_deterministic`，接入随包文件驱动的入口记录为
`package_file:<文件名>`。两类输入分别汇总，不能把一种输入源的结果代替
另一种输入源的结果。

测试数据按函数类型组织，具体包括：

- 标量图：按像素坐标生成固定灰度；
- 二值图：使用固定几何区域或周期 mask；
- 标签图：使用固定块状标签；
- 向量图和复数图：按坐标生成固定分量；
- 点集、路径、网格和 Level Set：使用固定参数和几何构造；
- 注册：使用清单规定的 fixed/moving 图像或点集；
- 外部文件复核：使用 `data/` 中与函数数据类型匹配的文件。

本包不把所有函数强制归一为同一张 1024×1024 图像。1024×1024 是二维
标量图的主测尺寸；三维、向量、复数、点集、网格、注册和水平集按清单中
对应的数据类型、维度和参数执行。

ITK 官方示例图像或业务图像属于可选的代表性验证层。送测单位采用此类
数据时，必须在结果中记录数据来源、文件名、尺寸、像素类型、版本或采集
信息以及 SHA-256；该结果与标准回归结果分开汇总。

### 本包提供的文件化复核数据

`data/common/` 提供与 ARM 平台完全对齐的 ITK 5.4 图像数据；根目录下的
6 个同名 PNG 是当前 DCU 入口的兼容路径副本。`data/alignment_report.tsv`
记录 ARM/DCU 文件哈希和尺寸核对结果。

共用主测文件为：

- `BrainProtonDensitySlice.png`
- `BrainProtonDensitySliceBorder20.png`
- `BrainProtonDensitySliceShifted13x17y.png`
- `BrainProtonDensity1024.png`
- `BrainProtonDensity1024_fixed.png`
- `BrainProtonDensity1024_moving.png`

另外提供 `BrainProtonDensitySliceBorder20Mask.png` 和
`BrainProtonDensitySlice256x256.png` 两个 ARM 补充输入。

`data/dcu_legacy/` 及根目录兼容路径还保留由
`scripts/generate_dcu_285_data.py` 生成的确定性结构化数据文件：

- `scalar_f32.mha`：1024×1024，float32；
- `scalar_f64.mha`：1024×1024，float64；
- `scalar_signed_f32.mha`：1024×1024，带负值 float32；
- `binary_u8.mha`：1024×1024，uint8 二值图；
- `labels_u16.mha`：1024×1024，uint16 标签图；
- `volume_f32.mha`：256×256×32，float32 体数据；
- `vector3_f32.mha`：1024×1024 三分量向量图；
- `complex2_f32.mha`：1024×1024 两分量复数数据；
- `rgb_u8.mha`：1024×1024 RGB 数据；
- `tensor6_f32.mha`：256×256×32 六分量张量数据；
- `pointset_2d.csv`：4096 个二维点；
- `dataset_manifest.tsv`：数据类型、尺寸、来源、角色和 SHA-256；
- `alignment_report.tsv`：ARM/DCU 数据对齐结果；
- `sha256sums.txt`：共用数据和兼容路径的哈希清单。

共用 PNG 用于 `package_file:<文件名>` 的二维主测场景；MHA/CSV 用于三维、
向量、复数、张量、点集等结构化对象的文件化复核。送测单位应按
`dataset_manifest.tsv` 校验文件属性，并在结果中保留实际使用的文件名、
尺寸、像素类型和 SHA-256。

## 3. 测试方法

### 3.1 OFF 与 ON

使用同一个程序、同一份输入、同一台 DCU，分别运行：

```bash
ITK_HIP_PRECISION_MODE=default ITK_HIP_MIXED_PRECISION=0
ITK_HIP_PRECISION_MODE=fp32_fp64 ITK_HIP_MIXED_PRECISION=1
```

实际项目构建开关仍应使用：

```bash
cmake ... -DITK_ENABLE_MIXED_PRECISION=OFF
cmake ... -DITK_ENABLE_MIXED_PRECISION=ON
```

OFF 和 ON 应分别构建，不能只依赖运行时环境变量把一个二进制伪装成两种构建。

### 3.2 运行约束

每个程序必须满足：

1. `ITK_HIP_FORBID_FALLBACK=1`；
2. 申请 1 张 DCU；
3. correctness 先于 benchmark；
4. 预热至少 1 次；
5. 正式计时至少 3 次，建议 5 次；
6. GPU 输出同步回主机后再停止计时；
7. 输出 `UNIFIED_METRIC` 和 `UNIFIED_PRECISION`；
8. 记录程序返回码、超时、缺少可执行文件和 fallback。

### 3.3 指标

连续标量图像：

- CPU/DCU 墙钟；
- `max_abs` 或 RMS error；
- OFF/ON 的 DCU 时间；
- 混精加速比；
- `UNIFIED_PRECISION` 的 requested/effective/mixed_kernel_observed。

二值、标签和形态学：

- 像素完全一致率；
- mismatch rate；
- Dice、连通域数、拓扑结构；
- 不把普通灰度 `max_abs` 作为唯一标准。

FFT/复数：

- 实部和虚部 RMS；
- 频谱幅值/相位误差；
- 正变换后逆变换残差；
- FFT 计划和端到端时间。

注册、点集、网格和路径：

- 度量值；
- 收敛状态；
- 点坐标误差；
- 路径长度、采样偏差；
- 网格拓扑和几何误差。

随机噪声：

- 固定 seed；
- 同一随机数生成策略；
- 统计量或分布误差；
- 不把未固定 seed 的逐像素差异当作混精误差。

## 4. 外部检测步骤

### 步骤 1：准备环境

```bash
export DTK_ROOT=/public/software/compiler/dtk-24.04.3
export OFF_BUILD=/public/home/acmcs42wxa/yyb/build-mixed-off/test
export ON_BUILD=/public/home/acmcs42wxa/yyb/build-mixed-on/test
export RESULT_ROOT=/public/home/acmcs42wxa/yyb/test-results/dcu-285-external
export DATA_ROOT=/public/home/acmcs42wxa/yyb/data
```

如果外部单位需要重新构建测试程序，应先得到两个不同的测试构建目录：

```bash
cmake -S /path/to/test -B "$ROOT/build-mixed-off" \
  -DITK_DIR=/path/to/itk-off/lib/cmake/ITK-5.4 \
  -DITK_ENABLE_MIXED_PRECISION=OFF
cmake --build "$ROOT/build-mixed-off" --parallel 8

cmake -S /path/to/test -B "$ROOT/build-mixed-on" \
  -DITK_DIR=/path/to/itk-on/lib/cmake/ITK-5.4 \
  -DITK_ENABLE_MIXED_PRECISION=ON
cmake --build "$ROOT/build-mixed-on" --parallel 8
```

外部验收时 `OFF_BUILD` 和 `ON_BUILD` 必须指向不同构建目录。脚本默认拒绝使用同一个目录；只有做冒烟检查时才允许显式设置 `ALLOW_SAME_BUILD=1`。

确认：

```bash
which hipcc
test -x "$TEST_BUILD/hip_smoothing_benchmark"
rocminfo | head
```

### 步骤 2：准备测试数据

```bash
python3 scripts/generate_dcu_285_data.py "$DATA_ROOT" \
  --width 1024 --height 1024 --depth 32
```

如果只做冒烟测试，可以改成 256×256；正式检测建议使用清单规定的尺寸和默认参数。

### 步骤 3：检查可执行程序

```bash
awk -F '\t' 'NR > 1 {print $7}' manifests/dcu_285_test_manifest.tsv \
  | sort -u
```

逐项确认对应程序存在。缺少程序不能记为 PASS。

### 步骤 4：运行 OFF

```bash
bash scripts/run_dcu_285_external.sh OFF
```

### 步骤 5：运行 ON

```bash
bash scripts/run_dcu_285_external.sh ON
```

### 步骤 6：汇总

```bash
python3 scripts/collect_unified_metrics.py \
  "$RESULT_ROOT" \
  "$RESULT_ROOT/dcu_285_summary.csv"
```

### 步骤 7：判定

单个函数只有同时满足以下条件，才可写为“外部检测通过”：

- OFF、ON 对应构建和程序都存在；
- 程序返回码为 0；
- 没有 `CPU_FALLBACK`、`FALLBACK_USED` 或 `NO_DCU_BACKEND`；
- 有对应函数的独立 `UNIFIED_METRIC`；
- 有对应的正确性指标；
- OFF/ON 时间样本齐全；
- 误差使用该函数所属 profile 的阈值，而不是对所有函数机械使用同一个阈值。

## 5. 全部 584 个函数的 ARM 对齐复测

如果送测范围是全部 584 个函数，使用根目录的
`scripts/run_arm_aligned_584.sh`，不要把历史 285 函数包的结果直接当作
584 函数结果。该入口使用
`manifests/itk_arm_aligned_584.tsv` 中逐函数登记的输入契约：

- 2D 标量函数使用官方脑部图像生成的 1024×1024 标准图；
- 配准函数使用固定图和移动图；
- 标签、二值、复数、点集、网格和水平集函数使用对应的固定生成数据；
- 同一输入测试 float 和 double，预热 1 次、正式测量 3 次；
- `double_ms / float_ms` 是 ARM 对齐精度对比的加速比；
- DCU OFF/ON 时间和 `OFF / ON` 是 DCU 混合精度收益，单独存储；
- 连续图像使用 `max_abs`，对象类函数使用清单指定的领域指标。

benchmark 如需向汇总器提供独立函数结果，应输出：

```text
ARM_ALIGNED_METRIC function=<name> input_source=<source> \
dimensions=<shape> pixel_type=<type> float_ms=<ms> \
double_ms=<ms> speedup=<double/float> max_abs=<value>
```

可复核资料包括 584 条清单、原始日志、`protocol.tsv`、
`target-status.tsv`、`dataset_manifest.tsv`、`alignment_report.tsv` 和
汇总 CSV。当前工作簿中的历史数据不因新增入口自动改写，必须在实际复测
完成后再将新结果回填。

## 5. 需要外部检测单位回传的文件

至少回传：

1. `dcu_285_summary.csv`；
2. `target-status.tsv`；
3. OFF 全部日志；
4. ON 全部日志；
5. `dataset_manifest.tsv`；
6. DCU 型号、驱动、DTK 版本、ITK 构建提交号；
7. CMake 配置和编译日志；
8. 失败函数的完整 stdout/stderr。

## 6. 当前范围的限制

当前统一测试体系适合作为 DCU 后端和混精路径的可重复回归检测，但不能替代真实医学数据验证。建议外部检测分两层：

1. **标准可重复层**：使用本包确定性数据和现有模块级程序，确认后端、精度开关、数值误差和墙钟；
2. **应用代表层**：再选取经过授权的官方/真实业务图像，按相同函数清单复核结果。

两层结果不能混写。标准层用于回归和横向比较，应用代表层用于说明真实数据上的适用性。
