# DCU 平台 ITK 送测数据说明

## 1. 数据分层与跨平台口径

DCU 平台送测数据沿用 ARM 平台的测试数据口径，分为两类：

1. **二维灰度图主测数据**：使用 ITK 5.4 `Examples/Data` 中的官方脑部
   图像及其固定派生尺寸，不能用任意替代图像。
2. **非二维灰度对象数据**：网格、折线、标签表、水平集初值、点集、位移
   场、复数频谱等没有统一的单一图像文件，由对应的
   `src/precision_*_bench.cxx` 按 ITK 官方测试协议在运行时生成。

两类数据分别记录和汇总。不能把非二维对象强行转换成灰度图后作为该对象
函数的标准输入。

`common/` 是 ARM/DCU 共用数据的标准目录；其中的文件已按字节级 SHA-256
与 ARM 平台 `ITK_ECNU/ITK_ECNU/testdata/images/` 对齐。根目录下的 6 个
PNG 是当前 DCU 可执行程序的兼容路径副本，内容必须与 `common/` 中的同名
文件完全一致。

## 2. 二维灰度图主测文件

正式送测时，以下文件必须同时存在于 `common/` 和根目录兼容路径：

| 文件名 | 来源与用途 |
|---|---|
| `BrainProtonDensitySlice.png` | ITK 5.4 `Examples/Data` 官方图像；二维主测原图 |
| `BrainProtonDensitySliceBorder20.png` | ITK 5.4 `Examples/Data` 官方图像；配准固定图原图 |
| `BrainProtonDensitySliceShifted13x17y.png` | ITK 5.4 `Examples/Data` 官方图像；配准移动图原图 |
| `BrainProtonDensity1024.png` | 由 `BrainProtonDensitySlice.png` 按固定规则生成的 1024×1024 主测图 |
| `BrainProtonDensity1024_fixed.png` | 由 `BrainProtonDensitySliceBorder20.png` 按固定规则生成的 1024×1024 固定图 |
| `BrainProtonDensity1024_moving.png` | 由 `BrainProtonDensitySliceShifted13x17y.png` 按固定规则生成的 1024×1024 移动图 |

其中前三个文件是 ITK 5.4 官方输入，后三个文件是由对应官方输入按统一
尺寸转换规则得到的送测文件。二维图像函数默认使用
`BrainProtonDensity1024.png`；配准函数使用
`BrainProtonDensity1024_fixed.png` 和 `BrainProtonDensity1024_moving.png`。

`common/BrainProtonDensitySliceBorder20Mask.png` 和
`common/BrainProtonDensitySlice256x256.png` 是 ARM 平台的补充输入，
用于掩膜和小尺寸图像场景；不作为所有函数的统一输入。

## 3. 文件生成、哈希与校验

`BrainProtonDensity1024*.png` 必须由送测脚本按固定规则生成，不得使用
未登记的任意缩放图像。生成后应在 `dataset_manifest.tsv` 中记录：

- 来源文件名；
- 输出文件名；
- 图像尺寸；
- 像素类型和通道数；
- 生成工具及版本；
- SHA-256。

`dataset_manifest.tsv` 还记录文件的跨平台角色：

- `arm_dcu_common`：ARM/DCU 共用的标准文件；
- `dcu_legacy`：DCU 原有确定性 MHA/CSV 文件，保留用于结构化对象复核；
- `compatibility_alias`：根目录兼容路径的同字节副本。

`alignment_report.tsv` 记录 ARM 来源路径、DCU 路径、尺寸、像素类型、两端
SHA-256 和对齐状态。

送测前先执行数据校验：

```bash
python3 scripts/verify_dcu_dataset.py data
```

如果校验脚本报告缺少文件、尺寸不符、像素类型不符或 SHA-256 不一致，
应先修正数据，再开始 OFF/ON 测试。

## 4. 非二维灰度对象

以下输入由对应 benchmark 按固定测试协议生成，不要求另放一张统一图像：

- 网格、折线和路径；
- 标签表和标签图；
- 水平集初值、速度场和迭代参数；
- 点集和点集配准对象；
- 位移场；
- 复数图像和频谱；
- 其他由函数接口定义的结构化对象。

这些函数的 `data_source` 应记录为
`internal_deterministic:<生成器或测试程序名>`，并在结果中保留生成参数、
尺寸、迭代次数、固定 seed（如适用）和程序版本。

## 7. ARM 对齐清单

全部 584 个函数的 ARM 对齐输入分类记录在
`../manifests/itk_arm_aligned_584.tsv`。该清单把每个函数映射到二维主测图、
配准固定/移动图、标签/二值图或对应的固定生成对象。运行前可用：

```bash
python3 ../scripts/verify_arm_alignment.py \
  /path/to/ITK_ECNU/ITK_ECNU/test/data \
  /path/to/ITK_DCU/data
```

校验输出中的每一项必须为 `MATCH`，才能确认 DCU 的共用图像和 ARM 来源
完全一致。`run_arm_aligned_584.sh` 会把 `dataset_manifest.tsv` 和
`alignment_report.tsv` 复制到结果目录，便于外部复核。

## 5. 现有 MHA/CSV 文件的定位

本目录的 `dcu_legacy/` 以及根目录兼容路径保留
`scalar_*.mha`、`binary_u8.mha`、`labels_u16.mha`、
`volume_f32.mha`、`vector3_f32.mha`、`complex2_f32.mha`、
`rgb_u8.mha`、`tensor6_f32.mha` 和 `pointset_2d.csv` 保留为：

- 非二维对象函数的文件化复核数据；
- 缺少对应官方输入的开发调试数据；
- 需要独立文件驱动入口时的补充数据。

它们不替代上述 6 个二维灰度主测文件。使用其中任意文件时，必须在测试
结果中记录确切文件名、尺寸、像素类型和 SHA-256。

## 6. 结果记录

每条测试结果至少记录：

- `data_source`；
- 输入文件名或运行时生成器；
- 尺寸、像素类型和通道数；
- ITK 版本或提交号；
- DCU 型号、驱动和 DTK 版本；
- OFF/ON 构建配置；
- 输入文件或生成结果的 SHA-256；
- CPU 参考、DCU 时间、误差和加速比。

二维灰度主测、非二维对象测试和代表性业务图像测试应分开汇总，不能混成
一条结果。
