#!/usr/bin/env python3
import csv
import re
import sys
from pathlib import Path

METRIC = re.compile(
    r"UNIFIED_METRIC\s+domain=(?P<domain>\S+)\s+module=(?P<module>\S+)\s+"
    r"function=(?P<function>\S+)\s+error=(?P<error>\S+)\s+speedup=(?P<speedup>\S+)"
    r"(?:\s+cpu_ms=(?P<cpu>\S+)\s+dcu_ms=(?P<dcu>\S+))?"
)

def load_manifest(path):
    with path.open(encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))

def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: collect_baseline_metrics.py RESULT_ROOT OUTPUT_CSV")
    result_root = Path(sys.argv[1])
    output = Path(sys.argv[2])
    manifest_path = result_root / "itk_port_baseline_584.tsv"
    manifest = load_manifest(manifest_path)
    metrics = {}
    for log in sorted(result_root.glob("*.log")):
        for line in log.read_text(encoding="utf-8", errors="replace").splitlines():
            match = METRIC.search(line)
            if match:
                item = match.groupdict()
                item["source_log"] = str(log)
                metrics[item["function"]] = item
    fields = [
        "function", "module", "parallel", "script_status", "error", "speedup",
        "cpu_ms", "dcu_ms", "source_log", "check_conclusion", "classification",
    ]
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        for row in manifest:
            metric = metrics.get(row["function"], {})
            writer.writerow({
                "function": row["function"],
                "module": row["module"],
                "parallel": row["parallel"],
                "script_status": row["script_status"],
                "error": metric.get("error", ""),
                "speedup": metric.get("speedup", ""),
                "cpu_ms": metric.get("cpu", ""),
                "dcu_ms": metric.get("dcu", ""),
                "source_log": metric.get("source_log", ""),
                "check_conclusion": row["check_conclusion"],
                "classification": row["classification"],
            })
    print(f"SUMMARY_FILE:{output}")
    print(f"FUNCTION_ROWS:{len(manifest)}")
    print(f"METRIC_ROWS:{len(metrics)}")

if __name__ == "__main__":
    main()

