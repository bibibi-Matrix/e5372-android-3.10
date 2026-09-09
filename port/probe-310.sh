#!/bin/bash
set -euo pipefail

K310_URL="https://cdn.kernel.org/pub/linux/kernel/v3.x/linux-3.10.108.tar.xz"
cd "$GITHUB_WORKSPACE"

# 1. vanilla 3.10.108
curl -sL -o k310.tar.xz "$K310_URL"
tar xf k310.tar.xz
cd linux-3.10.108

# 2. toolchain sanity + generic ARM build (proves gcc 4.5.1 can build 3.10)
export ARCH=arm
export CROSS_COMPILE=arm-none-linux-gnueabi-

echo "=== vexpress_defconfig ==="
make vexpress_defconfig > /dev/null
set +e
make -j2 zImage HOSTCFLAGS="-fcommon" > "$GITHUB_WORKSPACE/probe-310.log" 2>&1
rc=$?
set -e
echo "=== probe make exit: $rc ==="
tail -40 "$GITHUB_WORKSPACE/probe-310.log"
test -f arch/arm/boot/zImage && echo "=== PROBE ZIMAGE OK ===" || echo "=== PROBE ZIMAGE MISSING ==="
exit $rc