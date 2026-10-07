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
UNIFIED_METRIC = re.compile(
    r"UNIFIED_METRIC\s+domain=(?P<domain>\S+)\s+module=(?P<module>\S+)\s+"
    r"function=(?P<function>\S+)\s+error=(?P<error>\S+)\s+"
    r"speedup=(?P<speedup>\S+)"
    r"(?:\s+cpu_ms=(?P<cpu_ms>\S+)\s+dcu_ms=(?P<dcu_ms>\S+))?"
)


def load_manifest(path):
    with path.open(encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def parse_logs(result_root):
    metrics = {}
    for log in sorted(result_root.rglob("*.log")):
        mode = "on" if log.stem.endswith("_on") else "off"
        for raw in log.read_text(encoding="utf-8", errors="replace").splitlines():
            match = ARM_METRIC.search(raw)
            if match:
                item = match.groupdict()
                item["source_log"] = str(log)
                metrics.setdefault(item["function"], {})["arm"] = item
                continue
            match = UNIFIED_METRIC.search(raw)
            if match:
                item = match.groupdict()
                item["mode"] = mode
                item["source_log"] = str(log)
                metrics.setdefault(item["function"], {})[mode] = item
                continue
            match = CSV_METRIC.match(raw)
            if match and match.group("function") not in {"operator", "function"}:
                item = match.groupdict()
                item["input_source"] = ""
                item["dimensions"] = ""
                item["pixel_type"] = ""
                item["source_log"] = str(log)
                metrics.setdefault(item["function"], {})[mode] = item
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
    manifest_path = result_root / "itk_arm_aligned_584.tsv"
    if not manifest_path.is_file():
        candidates = sorted(result_root.glob("**/itk_arm_aligned_584.tsv"))
        if not candidates:
            raise SystemExit("manifest not found under RESULT_ROOT")
        manifest_path = candidates[0]
    manifest = load_manifest(manifest_path)
    metrics = parse_logs(result_root)
    fields = [
        "id",
        "module",
        "function",
        "parallel",
        "input_source",
        "dimensions_or_object",
        "pixel_type",
        "cpu_ms",
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
            arm_metric = metric.get("arm", {})
            off = metric.get("off", {})
            on = metric.get("on", {})
            float_ms = number(arm_metric.get("float_ms"))
            double_ms = number(arm_metric.get("double_ms"))
            speedup = number(arm_metric.get("speedup"))
            if speedup is None and float_ms not in (None, 0) and double_ms is not None:
                speedup = double_ms / float_ms
            dcu_off_ms = number(off.get("dcu_ms"))
            dcu_on_ms = number(on.get("dcu_ms"))
            cpu_ms = number(off.get("cpu_ms") or on.get("cpu_ms"))
            dcu_off_on_speedup = (
                dcu_off_ms / dcu_on_ms
                if dcu_off_ms not in (None, 0) and dcu_on_ms not in (None, 0)
                else None
            )
            representative = on or off or arm_metric
            writer.writerow(
                {
                    "id": row["id"],
                    "module": row["module"],
                    "function": row["function"],
                    "parallel": row["parallel"],
                    "input_source": representative.get("input_source", row["arm_input_profile"]),
                    "dimensions_or_object": representative.get(
                        "dimensions", row["dimensions_or_object"]
                    ),
                    "pixel_type": representative.get("pixel_type", ""),
                    "cpu_ms": "" if cpu_ms is None else cpu_ms,
                    "float_ms": "" if float_ms is None else float_ms,
                    "double_ms": "" if double_ms is None else double_ms,
                    "arm_aligned_speedup": "" if speedup is None else speedup,
                    "max_abs": on.get("error", arm_metric.get("max_abs", "")),
                    "dcu_off_ms": "" if dcu_off_ms is None else dcu_off_ms,
                    "dcu_on_ms": "" if dcu_on_ms is None else dcu_on_ms,
                    "dcu_off_on_speedup": "" if dcu_off_on_speedup is None else dcu_off_on_speedup,
                    "status": "PASS" if off or on or arm_metric else "NO_INDEPENDENT_METRIC",
                    "source_log": on.get("source_log", off.get("source_log", arm_metric.get("source_log", ""))),
                }
            )
    print(f"SUMMARY_FILE={output}")
    print(f"FUNCTION_ROWS={len(manifest)}")
    print(f"METRIC_ROWS={len(metrics)}")


if __name__ == "__main__":
    main()
