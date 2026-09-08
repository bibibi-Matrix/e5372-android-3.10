#!/usr/bin/env python3
"""Extract kernel zImage and ramdisk from Huawei Balong firmware .fw file.

The .fw file structure:
  0x00: magic 0xA55A55AA
  0x04: header size (e.g. 0x69C = 1692)
  ...  balong file header + RSA signature ...
  0x69C: "ANDROID!" Android boot image header
  ...  kernel (gzip zImage) + ramdisk (gzip) ...

Usage: python extract_kernel.py <Kernel_R1.fw> <outdir>
"""
import struct
import sys
import os
import gzip
import shutil


def parse_android_bootimg(data, base=0):
    """Parse Android boot image header. Returns dict."""
    assert data[base:base+8] == b"ANDROID!", "Not an Android boot image"
    vals = struct.unpack_from("<9I", data, base + 8)
    hdr = {
        "magic": data[base:base+8],
        "kernel_size": vals[0],
        "kernel_addr": vals[1],
        "ramdisk_size": vals[2],
        "ramdisk_addr": vals[3],
        "second_size": vals[4],
        "second_addr": vals[5],
        "tags_addr": vals[6],
        "page_size": vals[7],
        "dt_size": vals[8],
    }
    name = data[base+0x30:base+0x30+16]
    cmdline = data[base+0x70:base+0x70+512]
    hdr["name"] = name.rstrip(b"\0").decode("latin1", "replace")
    hdr["cmdline"] = cmdline.rstrip(b"\0").decode("ascii", "backslashreplace")
    return hdr


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    fw = sys.argv[1]
    outdir = sys.argv[2]
    os.makedirs(outdir, exist_ok=True)

    data = open(fw, "rb").read()

    # balong header
    assert data[:4] == b"\x55\xAA\x5A\xA5", "Not a balong .fw file"
    hdr_size = struct.unpack_from("<I", data, 4)[0]
    print(f"balong header size: 0x{hdr_size:x} ({hdr_size})")

    boot = parse_android_bootimg(data, hdr_size)
    print("Android boot image:")
    for k, v in boot.items():
        print(f"  {k}: {v}")

    page = boot["page_size"]
    off = hdr_size + page  # kernel starts on next page boundary

    kernel = data[off:off+boot["kernel_size"]]
    print(f"kernel: {len(kernel)} bytes @ 0x{off:x}")

    with open(os.path.join(outdir, "kernel.gz"), "wb") as f:
        f.write(kernel)

    # decompress kernel
    try:
        with gzip.open(os.path.join(outdir, "kernel.gz"), "rb") as f:
            kimg = f.read()
        print(f"kernel decompressed: {len(kimg)} bytes")
        with open(os.path.join(outdir, "kernel.bin"), "wb") as f:
            f.write(kimg)
    except Exception as e:
        print(f"kernel decompress failed: {e}")

    # ramdisk
    koff = off + ((boot["kernel_size"] + page - 1) // page) * page
    ramdisk = data[koff:koff+boot["ramdisk_size"]]
    print(f"ramdisk: {len(ramdisk)} bytes @ 0x{koff:x}")
    with open(os.path.join(outdir, "ramdisk.gz"), "wb") as f:
        f.write(ramdisk)
    try:
        with gzip.open(os.path.join(outdir, "ramdisk.gz"), "rb") as f:
            rd = f.read()
        print(f"ramdisk decompressed: {len(rd)} bytes")
        with open(os.path.join(outdir, "ramdisk.cpio"), "wb") as f:
            f.write(rd)
    except Exception as e:
        print(f"ramdisk decompress failed: {e}")

    print("DONE")


if __name__ == "__main__":
    main()