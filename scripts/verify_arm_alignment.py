#!/usr/bin/env python3
"""Compare ARM reference files and DCU data files by SHA-256."""
import hashlib
import sys
from pathlib import Path


FILES = (
    "BrainProtonDensitySlice.png",
    "BrainProtonDensitySliceBorder20.png",
    "BrainProtonDensitySliceShifted13x17y.png",
    "BrainProtonDensity1024.png",
    "BrainProtonDensity1024_fixed.png",
    "BrainProtonDensity1024_moving.png",
)


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def main():
    if len(sys.argv) != 3:
        raise SystemExit(
            "usage: verify_arm_alignment.py ARM_IMAGE_DIR DCU_DATA_ROOT"
        )
    arm_root = Path(sys.argv[1])
    dcu_root = Path(sys.argv[2])
    dcu_common = dcu_root / "common"
    print("file\tarm_sha256\tdcu_common_sha256\tstatus")
    failed = False
    for name in FILES:
        arm = arm_root / name
        dcu = dcu_common / name
        arm_hash = sha256(arm) if arm.is_file() else "MISSING"
        dcu_hash = sha256(dcu) if dcu.is_file() else "MISSING"
        status = "MATCH" if arm_hash == dcu_hash and arm_hash != "MISSING" else "MISMATCH"
        if status != "MATCH":
            failed = True
        print("{}\t{}\t{}\t{}".format(name, arm_hash, dcu_hash, status))
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
