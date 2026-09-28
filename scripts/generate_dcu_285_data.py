#!/usr/bin/env python3
"""Generate deterministic MetaImage inputs for the 244-function DCU test scope."""

from __future__ import annotations

import argparse
import array
import csv
import math
import struct
import sys
from pathlib import Path


def write_mha(path: Path, dims: tuple[int, ...], values, element_type: str, channels: int = 1) -> None:
    values = list(values)
    if element_type == "MET_FLOAT":
        packed = array.array("f", values)
    elif element_type == "MET_DOUBLE":
        packed = array.array("d", values)
    elif element_type == "MET_UCHAR":
        packed = array.array("B", values)
    elif element_type == "MET_USHORT":
        packed = array.array("H", values)
    else:
        raise ValueError(f"unsupported element type: {element_type}")
    if sys.byteorder != "little" and packed.itemsize > 1:
        packed.byteswap()

    header = [
        "ObjectType = Image",
        "NDims = " + str(len(dims)),
        "BinaryData = True",
        "BinaryDataByteOrderMSB = False",
        "CompressedData = False",
        "TransformMatrix = " + " ".join("1" if i % (len(dims) + 1) == 0 else "0"
                                        for i in range(len(dims) * len(dims))),
        "Offset = " + " ".join("0" for _ in dims),
        "CenterOfRotation = " + " ".join("0" for _ in dims),
        "ElementSpacing = " + " ".join("1" for _ in dims),
        "DimSize = " + " ".join(str(x) for x in dims),
        f"ElementType = {element_type}",
    ]
    if channels != 1:
        header.append(f"ElementNumberOfChannels = {channels}")
    header.append("ElementDataFile = LOCAL")
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("wb") as handle:
        handle.write(("\n".join(header) + "\n").encode("ascii"))
        handle.write(packed.tobytes())


def scalar_values(width: int, height: int, variant: int):
    for y in range(height):
        for x in range(width):
            if variant == 0:
                yield 0.25 + 0.01 * ((x + 1) * (y + 1) % 4096)
            elif variant == 1:
                yield 0.5 + 0.007 * ((3 * x + 5 * y) % 113)
            elif variant == 2:
                yield -4.0 + 0.013 * x + 0.031 * y + ((x * y) % 17)
            else:
                yield -0.35 + 0.0004 * x - 0.0002 * y


def volume_values(width: int, height: int, depth: int):
    for z in range(depth):
        for y in range(height):
            for x in range(width):
                yield -3.0 + 0.25 * x + 1.5 * y + 2.25 * z + ((x * z) % 7)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path)
    parser.add_argument("--width", type=int, default=1024)
    parser.add_argument("--height", type=int, default=1024)
    parser.add_argument("--depth", type=int, default=32)
    args = parser.parse_args()

    root = args.output
    w, h, d = args.width, args.height, args.depth
    small_w, small_h = w // 4, h // 4

    write_mha(root / "scalar_f32.mha", (w, h), scalar_values(w, h, 0), "MET_FLOAT")
    write_mha(root / "scalar_f64.mha", (w, h), scalar_values(w, h, 0), "MET_DOUBLE")
    write_mha(root / "scalar_signed_f32.mha", (w, h), scalar_values(w, h, 3), "MET_FLOAT")
    write_mha(root / "binary_u8.mha", (w, h),
              (1 if (x - w / 2) ** 2 + (y - h / 2) ** 2 < (min(w, h) * 0.23) ** 2 else 0
               for y in range(h) for x in range(w)), "MET_UCHAR")
    write_mha(root / "labels_u16.mha", (w, h),
              (((x // 64) + 2 * (y // 64)) % 17 for y in range(h) for x in range(w)),
              "MET_USHORT")
    write_mha(root / "volume_f32.mha", (small_w, small_h, d),
              volume_values(small_w, small_h, d), "MET_FLOAT")
    write_mha(root / "vector3_f32.mha", (w, h), (
        value
        for y in range(h)
        for x in range(w)
        for value in (0.01 * x, 0.02 * y, 0.01 * (x + y))
    ), "MET_FLOAT", channels=3)
    write_mha(root / "complex2_f32.mha", (w, h), (
        value
        for y in range(h)
        for x in range(w)
        for value in (
            0.5 + 0.001 * ((5 * x + 7 * y) % 300),
            -0.25 + 0.001 * ((3 * x + 11 * y) % 200),
        )
    ), "MET_FLOAT", channels=2)
    write_mha(root / "rgb_u8.mha", (w, h), (
        value
        for y in range(h)
        for x in range(w)
        for value in ((3 * x + 20) % 255, (5 * y + 40) % 255, (x + 2 * y + 60) % 255)
    ), "MET_UCHAR", channels=3)
    write_mha(root / "tensor6_f32.mha", (small_w, small_h, d), (
        value
        for z in range(d)
        for y in range(small_h)
        for x in range(small_w)
        for value in (
            1.0 + 0.001 * x,
            0.2 + 0.0005 * y,
            0.1 + 0.0003 * z,
            1.2 + 0.001 * y,
            0.15 + 0.0002 * x,
            0.9 + 0.0004 * z,
        )
    ), "MET_FLOAT", channels=6)

    with (root / "pointset_2d.csv").open("w", newline="", encoding="ascii") as handle:
        writer = csv.writer(handle)
        writer.writerow(["id", "x", "y", "value"])
        for i in range(4096):
            angle = 2.0 * math.pi * i / 4096.0
            writer.writerow([i, 256.0 + 200.0 * math.cos(angle),
                             256.0 + 150.0 * math.sin(angle), 0.5 + i / 4096.0])

    with (root / "dataset_manifest.tsv").open("w", encoding="utf-8") as handle:
        handle.write("name\tpath\tdimensions\ttype\tseed_or_pattern\n")
        handle.write(f"scalar_f32\tscalar_f32.mha\t{w}x{h}\tfloat32\tanalytic-v0\n")
        handle.write(f"scalar_f64\tscalar_f64.mha\t{w}x{h}\tdouble\tanalytic-v0\n")
        handle.write(f"scalar_signed_f32\tscalar_signed_f32.mha\t{w}x{h}\tfloat32\tanalytic-signed\n")
        handle.write(f"binary_u8\tbinary_u8.mha\t{w}x{h}\tuint8\tcenter-disk\n")
        handle.write(f"labels_u16\tlabels_u16.mha\t{w}x{h}\tuint16\tblock-labels\n")
        handle.write(f"volume_f32\tvolume_f32.mha\t{small_w}x{small_h}x{d}\tfloat32\tanalytic-3d\n")
        handle.write(f"vector3_f32\tvector3_f32.mha\t{w}x{h}x3\tvector-float32\tanalytic-vector\n")
        handle.write(f"complex2_f32\tcomplex2_f32.mha\t{w}x{h}x2\tcomplex-components-float32\tanalytic-complex\n")
        handle.write(f"rgb_u8\trgb_u8.mha\t{w}x{h}x3\trgb-uint8\tanalytic-rgb\n")
        handle.write(f"tensor6_f32\ttensor6_f32.mha\t{small_w}x{small_h}x{d}x6\ttensor-float32\tpositive-definite-diagonal\n")
        handle.write(f"pointset_2d\tpointset_2d.csv\t4096x2\tcsv\tparametric-ring\n")

    print(f"generated deterministic mixed-precision data under {root}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
