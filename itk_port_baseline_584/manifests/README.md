# ITK 移植基线版清单

- 函数范围：584 个 ITK 函数。
- 构建语义：`ITK_ENABLE_MIXED_PRECISION=OFF`。
- 运行语义：`ITK_HIP_PRECISION_MODE=default`，`ITK_HIP_MIXED_PRECISION=0`。
- 清单按函数记录，程序按模块级 benchmark/correctness 入口执行。
- 抽象基类、模板接口和无独立入口的函数必须按清单中的代表性覆盖说明记录，不能把代表性结果冒充独立函数结果。
