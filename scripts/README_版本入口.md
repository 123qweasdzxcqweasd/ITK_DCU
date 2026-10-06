# 版本入口说明

正式测试不要直接使用本目录原有的 285 函数入口。当前送测版本已经拆分为：

- `../itk_port_baseline_584/`：584 个函数，混合精度 OFF；
- `../itk_mixed_precision_157/`：157 个函数，OFF/ON 对照并汇总混合精度结果。

两个版本分别维护自己的函数清单、入口程序清单和结果目录。

两版脚本默认使用上级目录的 `data/`。启动前会校验
`data/common/` 中的 ARM/DCU 共用图像、根目录兼容副本和
`dataset_manifest.tsv`；如使用其他数据目录，必须通过 `DATA_ROOT` 指定
并提供同样的清单与校验文件。

若需要把 DCU 的 584 个函数测试方法与 ARM
`ITK_ECNU/ITK_ECNU/lingsheng592` 对齐，使用：

- `../manifests/itk_arm_aligned_584.tsv`：584 个函数的输入和指标契约；
- `run_arm_aligned_584.sh`：预热 1 次、正式测量 3 次，分别测试 float/double；
- `collect_arm_aligned_metrics.py`：汇总 `double_ms/float_ms`、误差和 DCU OFF/ON 字段；
- `verify_arm_alignment.py`：校验 ARM 来源图像与 DCU `data/common/` 的 SHA-256。

ARM 对齐入口只负责建立统一测试口径，不会把历史 G-L 数据自动改写为新口径
结果；实际复测完成后再汇总和回填。
