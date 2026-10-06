# ARM 对齐测试清单

`itk_arm_aligned_584.tsv` 是 DCU 平台 584 个函数的 ARM 对齐测试清单。

清单中的每一行对应原始 584 函数范围，但测试入口仍然按模块组织。一个
模块级程序可以覆盖多个函数；没有独立入口的函数必须保留状态说明，不能把
代表性函数的结果复制成独立结果。

每个函数都明确记录：

- `arm_input_profile`：与 `lingsheng592` 一致的输入来源；
- `dimensions_or_object`：二维图像尺寸或结构化对象规模；
- `precision_mode`：默认使用 `float_vs_double`；
- `error_metric`：连续图像、二值/标签、频域、点集、路径等对应指标；
- `warmups=1`、`measured_runs=3`：与 ARM 主测试策略一致。

ARM 对齐加速比定义为：

```text
double_ms / float_ms
```

DCU 开关收益单独记录为：

```text
dcu_off_ms / dcu_on_ms
```

这两个加速比不能混用。
