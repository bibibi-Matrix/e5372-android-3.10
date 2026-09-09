#!/bin/bash
# Apply the Balong (E5372 / Hi6920CS) platform layer from the GPL 2.6.35 tree
# into a vanilla linux-3.10.108 tree. Idempotent: safe to re-run.
#
# Usage: apply-balong-310.sh <gpl-root> <linux-3.10-root>
set -u

GPL="${1:?usage: apply-balong-310.sh <gpl-root> <linux-3.10-root>}"
V="${2:?usage: apply-balong-310.sh <gpl-root> <linux-3.10-root>}"

if [ ! -d "$GPL/arch/arm/mach-balong" ]; then
    echo "ERROR: $GPL is not the GPL android-2.6.35 tree" >&2
    exit 1
fi
if [ ! -d "$V/arch/arm" ] || [ ! -f "$V/arch/arm/Kconfig" ]; then
    echo "ERROR: $V is not a linux 3.10 tree" >&2
    exit 1
fi

V=$(cd "$V" && pwd)
GPL=$(cd "$GPL" && pwd)
cd "$V"

# --- 1. platform directory ------------------------------------------------
if [ ! -d arch/arm/mach-balong ]; then
    cp -r "$GPL/arch/arm/mach-balong" arch/arm/mach-balong
    echo "mach-balong: copied"
else
    echo "mach-balong: already present"
fi

# --- 2. balong generated headers (FeatureConfig, MemoryMap, BSP_*) --------
mkdir -p include/generated
for f in BSP_GLOBAL.h BSP_IPF.h BSP_MEMORY.h BSP_VERSION.h DrvInterface.h \
         FeatureConfig.h FeatureConfig.mak FeatureConfigDRV.h FeatureConfigGAS.h \
         FeatureConfigNAS.h FeatureConfigOAM.h FeatureConfigTTF.h FeatureConfigWAS.h \
         FileSysInterface.h memMapGlobal.h MemoryConfig.h MemoryLayout.h MemoryMap.h \
         product_config.h TtfDrvInterface.h TtfLinkInterface.h TtfMemoryMap.h Version.h; do
    if [ -f "$GPL/include/generated/$f" ]; then
        cp "$GPL/include/generated/$f" "include/generated/$f"
    else
        echo "WARN: $GPL/include/generated/$f missing" >&2
    fi
done
echo "generated headers: applied"

# --- 3. arch/arm/Kconfig: ARCH_BALONG + source ----------------------------
if ! grep -q "config ARCH_BALONG" arch/arm/Kconfig; then
    awk '
        /source "arch\/arm\/mach-vexpress\/Kconfig"/ {
            print "config ARCH_BALONG"
            print "\tbool \"Hisilicon Balong family\""
            print "\tselect ARM_AMBA"
            print "\tselect GENERIC_CLOCKEVENTS"
            print "\tselect ARCH_WANT_OPTIONAL_GPIOLIB if GPIOLIB"
            print "\thelp"
            print "\t\tThis enables support for Hisilicon(R) Balong(R) boards."
            print ""
        }
        { print }
    ' arch/arm/Kconfig > arch/arm/Kconfig.new && mv arch/arm/Kconfig.new arch/arm/Kconfig
    echo "arch/arm/Kconfig: ARCH_BALONG added"
else
    echo "arch/arm/Kconfig: ARCH_BALONG already present"
fi

if ! grep -q "mach-balong/Kconfig" arch/arm/Kconfig; then
    sed -i '/source "arch\/arm\/mach-vexpress\/Kconfig"/a source "arch/arm/mach-balong/Kconfig"' arch/arm/Kconfig
    echo "arch/arm/Kconfig: balong source added"
else
    echo "arch/arm/Kconfig: balong source already present"
fi

# --- 4. arch/arm/Makefile: machine hook ------------------------------------
if ! grep -q "machine-\$(CONFIG_ARCH_BALONG)" arch/arm/Makefile; then
    sed -i '/machine-\$(CONFIG_ARCH_VEXPRESS)/a machine-\$(CONFIG_ARCH_BALONG)\t+= balong' arch/arm/Makefile
    echo "arch/arm/Makefile: balong machine hook added"
else
    echo "arch/arm/Makefile: balong machine hook already present"
fi

# --- 5. minimal defconfig ---------------------------------------------------
if [ ! -f arch/arm/configs/balong_min_defconfig ]; then
    cat > arch/arm/configs/balong_min_defconfig <<'EOF'
CONFIG_ARCH_BALONG=y
CONFIG_ARCH_SOC_VERSION_V7R1_C00=y
CONFIG_MACH_BOARD_ES=y
CONFIG_BALONG_EASY_SHELL=y
CONFIG_BALONG_OM=y
CONFIG_BALONG_MEMORY_SPINLOCK=y
CONFIG_HAS_BALONG_DEBUG_UART_PHYS=y
CONFIG_BALONG_DEBUG_UART0=y
CONFIG_ARM=y
CONFIG_ARM_AMBA=y
CONFIG_AEABI=y
CONFIG_CPU_V7=y
CONFIG_EXPERT=y
CONFIG_EMBEDDED=y
CONFIG_PRINTK=y
CONFIG_GENERIC_CLOCKEVENTS=y
CONFIG_CLKSRC_MMIO=y
CONFIG_SERIAL_CORE=y
CONFIG_SERIAL_CORE_CONSOLE=y
EOF
    echo "defconfig: balong_min_defconfig created"
else
    echo "defconfig: already present"
fi

echo "=== apply-balong-310.sh done ==="