# 基线版脚本

先构建：

```bash
bash build_itk_port_baseline.sh
```

再运行：

```bash
bash run_itk_port_baseline_584.sh
```

最后汇总：

```bash
python3 collect_baseline_metrics.py \
  "$RESULT_ROOT" "$RESULT_ROOT/itk_port_baseline_584_summary.csv"
```

