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

## 2. 数据来源

### 当前 DCU 程序实际使用的数据

当前 285 个统一 metric 入口没有发现读取 ITK 官方图像文件的证据。主要数据在 C++ 测试程序内部由固定公式生成，例如：

- 标量图：按像素坐标生成确定性灰度；
- 二值图：中心圆盘、周期 mask；
- 标签图：固定块状标签；
- 向量图：按 x、y 坐标生成固定三分量；
- 复数图：按坐标生成固定实部和虚部；
- 点集：固定参数曲线或环形点集；
- 注册：程序内生成 fixed/moving 合成图像或点集；
- 路径、网格、Level Set：程序内构造固定几何对象或 level-set 初值。

因此，当前数据不是“随便选一张 1024×1024 图像”，也不是 ITK 官方示例图像。它的优点是 CPU/DCU、OFF/ON 之间完全可复现，缺点是不能代表所有真实医学图像分布。

### 本包提供的外部可复现数据

`data/` 中提供由 `scripts/generate_dcu_285_data.py` 生成的确定性数据文件：

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
- `dataset_manifest.tsv`：数据类型、尺寸、生成模式和文件名。

这些数据用于外部复核和新写的 file-driven benchmark。现有部分模块程序仍然在程序内部生成输入，不会自动读取这些 MHA 文件；因此外部检测时必须在结果中注明是“内部确定性输入”还是“外部数据文件输入”。

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
export DATA_ROOT=/public/home/acmcs42wxa/yyb/test-data/dcu-285
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
