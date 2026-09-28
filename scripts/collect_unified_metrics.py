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

def load_mode(result_root: Path, mode: str):
    rows = {}
    mode_root = result_root / mode
    for log in sorted(mode_root.glob("*.log")):
        for line in log.read_text(encoding="utf-8", errors="replace").splitlines():
            match = METRIC.search(line)
            if match:
                item = match.groupdict()
                item["mode"] = mode
                item["source_log"] = str(log)
                rows[item["function"]] = item
            precision = PRECISION.search(line)
            if precision:
                item = precision.groupdict()
                rows.setdefault(item["function"], {"function": item["function"]})
                rows[item["function"]].update({
                    "requested": item["requested"],
                    "effective": item["effective"],
                    "mixed_kernel_observed": item["observed"],
                })
    return rows

def load_manifest(path: Path):
    with path.open(encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))

def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: collect_unified_metrics.py RESULT_ROOT OUTPUT_CSV")
    result_root = Path(sys.argv[1])
    output = Path(sys.argv[2])
    manifest = load_manifest(result_root / "dcu_285_test_manifest.tsv") if (result_root / "dcu_285_test_manifest.tsv").exists() else []
    off = load_mode(result_root, "OFF")
    on = load_mode(result_root, "ON")
    names = [row["function"] for row in manifest] if manifest else sorted(set(off) | set(on))
    output.parent.mkdir(parents=True, exist_ok=True)
    fields = [
        "function", "module", "executable", "off_cpu_ms", "off_dcu_ms", "off_error",
        "on_cpu_ms", "on_dcu_ms", "on_error", "on_requested", "on_effective",
        "on_mixed_kernel_observed", "off_log", "on_log",
    ]
    with output.open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        for name in names:
            row = next((item for item in manifest if item["function"] == name), {})
            old = off.get(name, {})
            new = on.get(name, {})
            writer.writerow({
                "function": name,
                "module": row.get("module", old.get("module", new.get("module", ""))),
                "executable": row.get("suggested_executable", ""),
                "off_cpu_ms": old.get("cpu", ""),
                "off_dcu_ms": old.get("dcu", ""),
                "off_error": old.get("error", ""),
                "on_cpu_ms": new.get("cpu", ""),
                "on_dcu_ms": new.get("dcu", ""),
                "on_error": new.get("error", ""),
                "on_requested": new.get("requested", ""),
                "on_effective": new.get("effective", ""),
                "on_mixed_kernel_observed": new.get("mixed_kernel_observed", ""),
                "off_log": old.get("source_log", ""),
                "on_log": new.get("source_log", ""),
            })
    print(f"SUMMARY_FILE:{output}")
    print(f"FUNCTION_ROWS:{len(names)}")
    print(f"OFF_METRICS:{len(off)}")
    print(f"ON_METRICS:{len(on)}")

if __name__ == "__main__":
    main()
