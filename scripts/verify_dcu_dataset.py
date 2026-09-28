#!/usr/bin/env python3
"""Verify the file inventory required by the DCU ITK send-test protocol."""

from __future__ import annotations

import argparse
import hashlib
import struct
import sys
from pathlib import Path
from typing import Tuple


COMMON_FILES = {
    "BrainProtonDensitySlice.png": ((181, 217), "ITK 5.4 official source image"),
    "BrainProtonDensitySliceBorder20.png": ((221, 257), "ITK 5.4 official fixed image"),
    "BrainProtonDensitySliceShifted13x17y.png": ((221, 257), "ITK 5.4 official moving image"),
    "BrainProtonDensity1024.png": ((1024, 1024), "ARM-derived 1024x1024 scalar image"),
    "BrainProtonDensity1024_fixed.png": ((1024, 1024), "ARM-derived 1024x1024 fixed image"),
    "BrainProtonDensity1024_moving.png": ((1024, 1024), "ARM-derived 1024x1024 moving image"),
    "BrainProtonDensitySliceBorder20Mask.png": ((221, 257), "ARM supplemental fixed-image mask"),
    "BrainProtonDensitySlice256x256.png": ((214, 256), "ARM supplemental small image"),
}

COMPATIBILITY_FILES = (
    "BrainProtonDensitySlice.png",
    "BrainProtonDensitySliceBorder20.png",
    "BrainProtonDensitySliceShifted13x17y.png",
    "BrainProtonDensity1024.png",
    "BrainProtonDensity1024_fixed.png",
    "BrainProtonDensity1024_moving.png",
)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def png_size(path: Path) -> Tuple[int, int]:
    with path.open("rb") as handle:
        if handle.read(8) != b"\x89PNG\r\n\x1a\n":
            raise ValueError("invalid PNG signature")
        length = struct.unpack(">I", handle.read(4))[0]
        chunk = handle.read(4)
        if chunk != b"IHDR" or length < 8:
            raise ValueError("missing PNG IHDR")
        width, height = struct.unpack(">II", handle.read(8))
        return width, height


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("data_root", type=Path)
    args = parser.parse_args()

    errors = 0
    common_paths = {}
    for name, (expected_size, description) in COMMON_FILES.items():
        path = args.data_root / "common" / name
        if not path.is_file():
            path = args.data_root / name
        common_paths[name] = path
        if not path.is_file():
            print(f"MISSING\t{name}\t{description}\tsearched=common/{name},{name}")
            errors += 1
            continue
        try:
            size = png_size(path)
        except (OSError, ValueError) as exc:
            print(f"INVALID\t{name}\t{exc}")
            errors += 1
            continue
        if expected_size is not None and size != expected_size:
            print(f"SIZE_MISMATCH\t{name}\tactual={size[0]}x{size[1]}\texpected={expected_size[0]}x{expected_size[1]}")
            errors += 1
            continue
        print(f"OK\t{name}\tsize={size[0]}x{size[1]}\tsha256={sha256(path)}\tpath={path.relative_to(args.data_root)}")

    for name in COMPATIBILITY_FILES:
        common_path = common_paths[name]
        compatibility_path = args.data_root / name
        if not common_path.is_file() or not compatibility_path.is_file():
            continue
        common_hash = sha256(common_path)
        compatibility_hash = sha256(compatibility_path)
        if common_hash != compatibility_hash:
            print(f"ALIAS_MISMATCH\t{name}\tcommon={common_hash}\troot={compatibility_hash}")
            errors += 1
        else:
            print(f"ALIAS_OK\t{name}\tsha256={common_hash}")

    if errors:
        print(f"DATASET_INVALID\tmissing_or_invalid={errors}")
        return 2
    print("DATASET_OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
