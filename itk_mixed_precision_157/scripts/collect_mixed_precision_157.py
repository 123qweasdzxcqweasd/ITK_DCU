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
PRECISION = re.compile(
    r"UNIFIED_PRECISION\s+domain=(?P<domain>\S+)\s+module=(?P<module>\S+)\s+"
    r"function=(?P<function>\S+)\s+requested=(?P<requested>\S+)\s+"
    r"effective=(?P<effective>\S+)\s+mixed_kernel_observed=(?P<observed>\S+)"
)

def number(value):
    try:
        return float(value)
    except (TypeError, ValueError):
        return None

def load_mode(root, mode):
    rows = {}
    for log in sorted((root / mode).glob("*.log")):
        for line in log.read_text(encoding="utf-8", errors="replace").splitlines():
            match = METRIC.search(line)
            if match:
                item = match.groupdict()
                item["source_log"] = str(log)
                rows[item["function"]] = item
            precision = PRECISION.search(line)
            if precision:
                item = precision.groupdict()
                rows.setdefault(item["function"], {})
                rows[item["function"]].update({
                    "requested": item["requested"],
                    "effective": item["effective"],
                    "observed": item["observed"],
                })
    return rows

def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: collect_mixed_precision_157.py RESULT_ROOT OUTPUT_CSV")
    root = Path(sys.argv[1])
    output = Path(sys.argv[2])
    with (root / "itk_mixed_precision_157.tsv").open(encoding="utf-8-sig", newline="") as handle:
        manifest = list(csv.DictReader(handle, delimiter="\t"))
    off = load_mode(root, "OFF")
    on = load_mode(root, "ON")
    fields = [
        "function", "module", "parallel", "selected_dcu_speedup", "selected_dcu_error_max_abs",
        "off_cpu_ms", "off_dcu_ms", "on_cpu_ms", "on_dcu_ms", "mixed_speedup",
        "mixed_error", "on_requested", "on_effective", "on_mixed_kernel_observed",
        "off_log", "on_log",
    ]
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        for row in manifest:
            old = off.get(row["function"], {})
            new = on.get(row["function"], {})
            off_dcu = number(old.get("dcu"))
            on_dcu = number(new.get("dcu"))
            mixed_speedup = (off_dcu / on_dcu) if off_dcu is not None and on_dcu not in (None, 0) else None
            writer.writerow({
                "function": row["function"],
                "module": row["module"],
                "parallel": row["parallel"],
                "selected_dcu_speedup": row["dcu_speedup"],
                "selected_dcu_error_max_abs": row["dcu_error_max_abs"],
                "off_cpu_ms": old.get("cpu", ""),
                "off_dcu_ms": old.get("dcu", ""),
                "on_cpu_ms": new.get("cpu", ""),
                "on_dcu_ms": new.get("dcu", ""),
                "mixed_speedup": "" if mixed_speedup is None else mixed_speedup,
                "mixed_error": new.get("error", ""),
                "on_requested": new.get("requested", ""),
                "on_effective": new.get("effective", ""),
                "on_mixed_kernel_observed": new.get("observed", ""),
                "off_log": old.get("source_log", ""),
                "on_log": new.get("source_log", ""),
            })
    print(f"SUMMARY_FILE:{output}")
    print(f"FUNCTION_ROWS:{len(manifest)}")
    print(f"OFF_METRICS:{len(off)}")
    print(f"ON_METRICS:{len(on)}")

if __name__ == "__main__":
    main()

