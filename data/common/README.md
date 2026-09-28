# ARM/DCU 共用测试数据

本目录是跨平台标准输入目录。文件来自 ARM 平台
`ITK_ECNU/ITK_ECNU/testdata/images/`，并按 SHA-256 与 ARM 文件逐项核对。

二维标量函数使用 1024×1024 主测图；配准函数使用固定图和移动图；
掩膜、小尺寸图像和其他结构化对象按各自测试方法使用。具体文件属性见
上级目录的 `dataset_manifest.tsv`，对齐结果见 `alignment_report.tsv`。
