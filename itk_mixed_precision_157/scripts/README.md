# 混合精度版脚本

先构建 OFF 和 ON 两套 ITK：

```bash
bash build_itk_mixed_precision_157.sh
```

再对 157 个目标函数对应的模块入口运行 OFF/ON：

```bash
bash run_itk_mixed_precision_157.sh
```

最后汇总：

```bash
python3 collect_mixed_precision_157.py \
  "$RESULT_ROOT" "$RESULT_ROOT/itk_mixed_precision_157_summary.csv"
```

