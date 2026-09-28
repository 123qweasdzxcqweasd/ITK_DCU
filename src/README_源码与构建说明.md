# 源码与构建说明

本送测包不把 285 个函数拆成 285 个独立 C++ 工程。当前 DCU 测试体系按
ITK 模块组织 benchmark/correctness 程序，一个程序可以顺序覆盖同一模块
中的多个函数。

正式检测前，请将本目录对应的测试源码与 ITK/DCU 工程源码放在检测机器上，
并分别构建 OFF 和 ON 两套测试程序：

```bash
cmake -S /path/to/test-source -B /path/to/test-build-off \
  -DITK_DIR=/path/to/itk-off/lib/cmake/ITK-5.4 \
  -DITK_ENABLE_MIXED_PRECISION=OFF
cmake --build /path/to/test-build-off --parallel 8

cmake -S /path/to/test-source -B /path/to/test-build-on \
  -DITK_DIR=/path/to/itk-on/lib/cmake/ITK-5.4 \
  -DITK_ENABLE_MIXED_PRECISION=ON
cmake --build /path/to/test-build-on --parallel 8
```

参考构建入口在 `reference/build_phase2_test_CMakeLists.txt`。如果外部单位
使用自己的测试工程，需要保证每个程序输出以下统一记录，便于脚本汇总：

```text
UNIFIED_METRIC domain=... module=... function=... error=... speedup=... cpu_ms=... dcu_ms=...
UNIFIED_PRECISION domain=... module=... function=... requested=... effective=... mixed_kernel_observed=...
```

如果函数没有独立的 benchmark 入口，应在清单中标为模块级覆盖或待补入口，
不能因为模块程序运行成功就自动声称该函数已有独立测试数据。

