#!/usr/bin/env python3
"""Collect ARM-aligned float/double metrics from DCU benchmark logs."""
import csv
import re
import sys
from pathlib import Path


ARM_METRIC = re.compile(
    r"ARM_ALIGNED_METRIC\s+function=(?P<function>\S+)\s+"
    r"input_source=(?P<input_source>\S+)\s+dimensions=(?P<dimensions>\S+)\s+"
    r"pixel_type=(?P<pixel_type>\S+)\s+float_ms=(?P<float_ms>\S+)\s+"
    r"double_ms=(?P<double_ms>\S+)\s+speedup=(?P<speedup>\S+)\s+"
    r"max_abs=(?P<max_abs>\S+)"
)
CSV_METRIC = re.compile(
    r"^(?P<module>[^,]+),(?P<function>[^,]+),(?P<float_ms>[^,]+),"
    r"(?P<double_ms>[^,]+),(?P<speedup>[^,]+),(?P<max_abs>[^,]+)"
)


def load_manifest(path):
    with path.open(encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def parse_logs(result_root):
    metrics = {}
    for log in sorted((result_root / "logs").glob("*.log")):
        for raw in log.read_text(encoding="utf-8", errors="replace").splitlines():
            match = ARM_METRIC.search(raw)
            if match:
                item = match.groupdict()
                item["source_log"] = str(log)
                metrics[item["function"]] = item
                continue
            match = CSV_METRIC.match(raw)
            if match and match.group("function") not in {"operator", "function"}:
                item = match.groupdict()
                item["input_source"] = ""
                item["dimensions"] = ""
                item["pixel_type"] = ""
                item["source_log"] = str(log)
                metrics[item["function"]] = item
    return metrics


def number(value):
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: collect_arm_aligned_metrics.py RESULT_ROOT OUTPUT_CSV")
    result_root = Path(sys.argv[1])
    output = Path(sys.argv[2])
    manifest = load_manifest(result_root / "itk_arm_aligned_584.tsv")
    metrics = parse_logs(result_root)
    fields = [
        "id",
        "module",
        "function",
        "parallel",
        "input_source",
        "dimensions_or_object",
        "pixel_type",
        "float_ms",
        "double_ms",
        "arm_aligned_speedup",
        "max_abs",
        "dcu_off_ms",
        "dcu_on_ms",
        "dcu_off_on_speedup",
        "status",
        "source_log",
    ]
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        for row in manifest:
            metric = metrics.get(row["function"], {})
            float_ms = number(metric.get("float_ms"))
            double_ms = number(metric.get("double_ms"))
            speedup = number(metric.get("speedup"))
            if speedup is None and float_ms not in (None, 0) and double_ms is not None:
                speedup = double_ms / float_ms
            writer.writerow(
                {
                    "id": row["id"],
                    "module": row["module"],
                    "function": row["function"],
                    "parallel": row["parallel"],
                    "input_source": metric.get("input_source", row["arm_input_profile"]),
                    "dimensions_or_object": metric.get(
                        "dimensions", row["dimensions_or_object"]
                    ),
                    "pixel_type": metric.get("pixel_type", ""),
                    "float_ms": "" if float_ms is None else float_ms,
                    "double_ms": "" if double_ms is None else double_ms,
                    "arm_aligned_speedup": "" if speedup is None else speedup,
                    "max_abs": metric.get("max_abs", ""),
                    "dcu_off_ms": "",
                    "dcu_on_ms": "",
                    "dcu_off_on_speedup": "",
                    "status": "PASS" if metric else "NO_INDEPENDENT_METRIC",
                    "source_log": metric.get("source_log", ""),
                }
            )
    print(f"SUMMARY_FILE={output}")
    print(f"FUNCTION_ROWS={len(manifest)}")
    print(f"METRIC_ROWS={len(metrics)}")


if __name__ == "__main__":
    main()
