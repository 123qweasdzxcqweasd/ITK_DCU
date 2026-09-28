# 外部可复现测试数据

本目录中的数据由 `scripts/generate_dcu_285_data.py` 生成，生成公式和类型固定，未使用随机数。重新生成同样的尺寸和深度应得到相同内容。

这些文件是外部复核数据。当前已有的 DCU 模块级 benchmark 多数在 C++ 程序内部直接按同类公式生成输入，因此不会自动读取这些 MHA/CSV 文件。外部检测报告必须在 `data_source` 中写明：

- `internal_deterministic`：使用现有程序内部生成的数据；
- `external_mha_csv`：使用本目录文件驱动的新或改造后的 benchmark。

两种来源不能混写成同一条测试记录。
