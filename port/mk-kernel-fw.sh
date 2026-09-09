#!/bin/bash
# Build a flashable Kernel_R1.fw component for E5372 (Balong V7R1) from a
# balong 3.10 zImage.
#
# The stock update partition component "05-00000105-Kernel_R1.fw" has the
# layout:
#   [0x0000, 0x0E9C) - balong component header (55 AA 5A A5 ... + signature)
#   [0x0E9C, 0x????) - the kernel image (zImage, NOP head 00 00 A0 E1 ...)
#   [0x????, EOF)    - zero padding
# The bootloader (BootROM) verifies only that the magic "55 AA 5A A5 ..." is
# present and does NOT enforce signature correctness on unlocked devices (the
# stock file's signature bytes are kept verbatim), so replacing the payload
# region with a custom zImage yields a flashable partition.
#
# Usage: mk-kernel-fw.sh <custom-zImage> [stock=unpacked/05-00000105-Kernel_R1.fw]
# Output: 05-00000105-Kernel_R1.fw  (ready for balongflash / flashtool)

set -euo pipefail

ZIMAGE="${1:?usage: mk-kernel-fw.sh <custom-zImage> [stock-component]}"
STOCK="${2:-$(dirname "$0")/../stock_firmware/unpacked/05-00000105-Kernel_R1.fw}"
OUT="05-00000105-Kernel_R1.fw"

PAYLOAD_OFF=0x0E9C            # verified payload offset in stock component
STOCK_PAYLOAD_LEN=3111580     # == stock kernel.gz size
STOCK_TOTAL=3264156           # component file size stays unchanged

test -f "$ZIMAGE" || { echo "zImage not found: $ZIMAGE" >&2; exit 1; }

head -c 4 "$ZIMAGE" | od -An -tx1 | grep -q "00 00 a0 e1" \
    || { echo "warning: $ZIMAGE does not look like a zImage (NOP head)" >&2; }

ZIMGLEN=$(stat -c %s "$ZIMAGE")
[ "$ZIMGLEN" -le "$STOCK_PAYLOAD_LEN" ] || {
    echo "zImage ($ZIMGLEN) larger than stock payload slot ($STOCK_PAYLOAD_LEN); abort" >&2
    exit 1
}

echo "== stock component: $STOCK"
head -c "$PAYLOAD_OFF" "$STOCK" > "$OUT"

echo "== payload: $ZIMAGE ($ZIMGLEN bytes)"
cat "$ZIMAGE" >> "$OUT"

PAD=$(( STOCK_PAYLOAD_LEN - ZIMGLEN ))
echo "== padding $PAD zero bytes ($STOCK_PAYLOAD_LEN total payload)"
head -c "$PAD" /dev/zero >> "$OUT"

head -c "$(( STOCK_TOTAL - PAYLOAD_OFF - STOCK_PAYLOAD_LEN ))" "$STOCK" >> "$OUT"

echo "== wrote $OUT ($(stat -c %s "$OUT") bytes, stock=$STOCK_TOTAL)"
echo
echo "Flash with (e.g. Windows balong_flash from godload mode):"
echo "  balong_flash -l <COMx> -d <dir-with-$OUT>"
echo "or goto-download mode (MENU+power), then run balong_flash with this dir."