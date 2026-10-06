#!/usr/bin/env python3
"""Create the 584-function ARM-aligned DCU test manifest.

The source manifest remains the authoritative function list. This script adds
the input and metric contract used by the ARM lingsheng592 protocol.
"""
import csv
import sys
from pathlib import Path
from typing import Tuple


def profile(function: str, module: str) -> Tuple[str, str, str, str]:
    name = function.lower()
    mod = module.lower()

    if any(token in name for token in ("registration", "metric", "transform")):
        return (
            "package_file:BrainProtonDensity1024_fixed.png+BrainProtonDensity1024_moving.png",
            "1024x1024 fixed/moving",
            "float_vs_double",
            "max_abs_or_domain_metric",
        )
    if any(token in name for token in ("hough", "thinning", "pruning")):
        return (
            "internal_deterministic:synthetic_binary_64",
            "64x64 synthetic binary",
            "float_vs_double",
            "max_abs_or_binary_consistency",
        )
    if any(token in name for token in ("mesh", "polyline", "path", "pointset", "quadedge")):
        return (
            "internal_deterministic:official_object_protocol",
            "fixed object size from benchmark",
            "float_vs_double",
            "domain_metric",
        )
    if any(token in name for token in ("fft", "frequency", "complex")):
        return (
            "internal_deterministic:complex_frequency_protocol",
            "1024x1024 complex or frequency input",
            "float_vs_double",
            "complex_domain_error",
        )
    if any(token in name for token in ("label", "binary", "connected", "regiongrow", "region_grow")):
        return (
            "package_file:labels_u16.mha+binary_u8.mha",
            "1024x1024 label/binary",
            "float_vs_double",
            "binary_or_label_consistency",
        )
    if "gpu" in mod or "gpu" in name:
        return (
            "internal_deterministic:gpu_interface_protocol",
            "interface-defined input",
            "float_vs_double",
            "domain_metric",
        )
    return (
        "package_file:BrainProtonDensity1024.png",
        "1024x1024 scalar gray",
        "float_vs_double",
        "max_abs",
    )


def main() -> int:
    if len(sys.argv) != 3:
        raise SystemExit("usage: build_arm_aligned_manifest.py SOURCE.tsv OUTPUT.tsv")

    source = Path(sys.argv[1])
    output = Path(sys.argv[2])
    with source.open(encoding="utf-8-sig", newline="") as handle:
        rows = list(csv.DictReader(handle, delimiter="\t"))

    fields = [
        "id",
        "module",
        "function",
        "parallel",
        "suggested_executable",
        "arm_input_profile",
        "dimensions_or_object",
        "precision_mode",
        "error_metric",
        "warmups",
        "measured_runs",
        "arm_aligned_speedup",
        "dcu_off_on_speedup",
        "status",
    ]
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, delimiter="\t")
        writer.writeheader()
        for row in rows:
            input_profile, dimensions, precision_mode, error_metric = profile(
                row["function"], row["module"]
            )
            writer.writerow(
                {
                    "id": row["id"],
                    "module": row["module"],
                    "function": row["function"],
                    "parallel": row["parallel"],
                    "suggested_executable": row["suggested_executable"],
                    "arm_input_profile": input_profile,
                    "dimensions_or_object": dimensions,
                    "precision_mode": precision_mode,
                    "error_metric": error_metric,
                    "warmups": "1",
                    "measured_runs": "3",
                    "arm_aligned_speedup": "",
                    "dcu_off_on_speedup": "",
                    "status": "待按ARM对齐口径重测",
                }
            )
    print(f"MANIFEST={output}")
    print(f"ROWS={len(rows)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
