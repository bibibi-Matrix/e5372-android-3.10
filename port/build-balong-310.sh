#!/bin/bash
# First iteration: apply Balong platform into vanilla 3.10.108 and try to
# build a balong zImage. Goals: (1) verify Kconfig/machine wiring, (2) collect
# the first wave of compile errors from mach-balong, (3) iterate.
set -euo pipefail

K310_URL="https://cdn.kernel.org/pub/linux/kernel/v3.x/linux-3.10.108.tar.xz"
cd "$GITHUB_WORKSPACE"
GPL="$GITHUB_WORKSPACE/gpl_source/android-2.6.35"

curl -sL -o k310.tar.xz "$K310_URL"
tar xf k310.tar.xz
cd linux-3.10.108

bash "$GITHUB_WORKSPACE/port/apply-balong-310.sh" "$GPL" "$PWD"

export ARCH=arm
export CROSS_COMPILE=arm-none-linux-gnueabi-

echo "=== base: vexpress_defconfig ==="
make vexpress_defconfig > /dev/null

echo "=== switch platform to ARCH_BALONG ==="
scripts/config \
    --disable ARCH_VEXPRESS \
    --enable ARCH_BALONG \
    --enable ARCH_SOC_VERSION_V7R1_C00 \
    --enable MACH_BOARD_ES \
    --enable BALONG_EASY_SHELL \
    --enable BALONG_OM \
    --enable BALONG_MEMORY_SPINLOCK \
    --enable HAS_BALONG_DEBUG_UART_PHYS \
    --enable BALONG_DEBUG_UART0
make olddefconfig

set +e
make -j4 zImage HOSTCFLAGS="-fcommon" > "$GITHUB_WORKSPACE/balong-310.log" 2>&1
rc=$?
set -e

echo "=== balong-310 make exit: $rc ==="
grep -E "^(arch/arm/mach-balong|drivers/|.*\.c:.*error:|error:)|\*\*\*" \
    "$GITHUB_WORKSPACE/balong-310.log" | tail -80
echo "--- tail ---"
tail -40 "$GITHUB_WORKSPACE/balong-310.log"
test -f arch/arm/boot/zImage && echo "=== BALONG ZIMAGE OK ===" || echo "=== BALONG ZIMAGE MISSING ==="
echo "=== error count: $(grep -c 'error:' "$GITHUB_WORKSPACE/balong-310.log" || true) ==="
exit $rc