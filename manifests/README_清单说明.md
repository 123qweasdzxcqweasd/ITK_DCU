# 清单说明

`dcu_285_test_manifest.tsv` 是 285 个函数的外部检测映射。

字段含义：

- `id`：清单序号；
- `module`：ITK 模块；
- `function`：函数名；
- `script_status`：当前是否有模块级统一入口；
- `suggested_executable`：建议调用的 DCU 可执行程序；
- `test_method`：正确性和性能的比较方法；
- `data_source`：输入是程序内部确定性生成，还是外部数据文件；
- `size_or_parameter_policy`：当前程序尺寸或参数口径；
- `current_evidence`：当前 DCU 主表中 G-L 的证据状态。

注意：`suggested_executable` 是模块级程序，一个程序可能覆盖多个函数。缺少函数级 `UNIFIED_METRIC` 时，不能用同一程序的其他函数结果代填。
