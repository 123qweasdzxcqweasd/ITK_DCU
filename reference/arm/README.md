# ARM 参考资料

本目录保存 ARM 平台 `lingsheng592` 测试包的只读参考资料，用于让 DCU
测试清单、输入分类、精度对比和结果判定与 ARM 口径一致。

| 文件 | 用途 |
|---|---|
| `qualified_functions_304.tsv` | ARM 侧通过筛选的函数清单 |
| `mixed_precision_lingsheng592.csv` | ARM 侧 584 个函数的混合精度测试记录 |
| `lingsheng592_README.md` | ARM 测试包原始说明 |

这些文件不是 DCU 测试结果，也不替代 DCU 的 OFF/ON 日志。DCU 的新测试入口
是 `scripts/run_arm_aligned_584.sh`，结果由
`scripts/collect_arm_aligned_metrics.py` 汇总。

对齐原则：

1. 测试范围固定为 584 个函数；
2. 二维标量图优先使用 `BrainProtonDensity1024.png`；
3. 配准使用固定图和移动图；
4. Hough、细化等特殊算子使用清单指定的固定生成对象；
5. 同一输入分别运行 float 和 double；
6. 预热 1 次、正式测量 3 次；
7. ARM 对齐加速比为 `double_ms / float_ms`；
8. DCU 自身的 OFF/ON 收益单独记录，不能与 ARM 对齐加速比混用。
