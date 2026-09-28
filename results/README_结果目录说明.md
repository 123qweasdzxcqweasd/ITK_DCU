# 结果目录

正式运行 `scripts/run_dcu_285_external.sh OFF` 和 `ON` 后，本目录用于保存
检测结果。建议结果目录至少包含：

```text
OFF/target-status.tsv
OFF/*.log
ON/target-status.tsv
ON/*.log
dcu_285_summary.csv
dataset_manifest.tsv
dcu_285_test_manifest.tsv
```

不要手工修改日志中的设备状态、回退状态或统一指标。若需要修正测试程序，
应保留原始失败日志，并以新的运行目录重新执行。
