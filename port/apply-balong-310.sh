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

# 3.10 Kconfig: GPIOLIB already depends on ARCH_WANT_OPTIONAL_GPIOLIB; the 2.6
# board 'select ARCH_WANT_OPTIONAL_GPIOLIB' lines create a recursive cycle.
sed -i '/select ARCH_WANT_OPTIONAL_GPIOLIB/d' arch/arm/mach-balong/Kconfig
echo "mach-balong/Kconfig: ARCH_WANT_OPTIONAL_GPIOLIB selects stripped"

# --- 1b. GPL-only global headers used by balong (BSP.h, DrvInterface.h, ...) -
# The 2.6 tree ships them in drivers/include; vanilla 3.10 has no such dir.
if [ ! -d drivers/include ]; then
    cp -r "$GPL/drivers/include" drivers/include
    echo "drivers/include: copied"
else
    echo "drivers/include: already present"
fi

# mach-balong/product_info references -Idrivers/mtd/nand/{ptable,nandc} for
# ptable_def.h etc.; vanilla 3.10 has neither directory.
if [ ! -d drivers/mtd/nand/ptable ]; then
    cp -r "$GPL/drivers/mtd/nand/ptable" drivers/mtd/nand/ptable
    echo "drivers/mtd/nand/ptable: copied"
fi
if [ ! -d drivers/mtd/nand/nandc ]; then
    cp -r "$GPL/drivers/mtd/nand/nandc" drivers/mtd/nand/nandc
    echo "drivers/mtd/nand/nandc: copied"
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

# 2.6 had bare-name mirrors in include/ (product_config.h is included without a
# path prefix from <mach/memMapGlobal.h>); 3.10 core does not ship them.
for f in product_config.h vxprintk.h; do
    if [ -f "$GPL/include/$f" ] && [ ! -f "include/$f" ]; then
        cp "$GPL/include/$f" "include/$f"
        echo "include/$f: mirrored"
    fi
done

# Balong-specific headers that 2.6 kept in include/linux/ (BSP_CHGC_DRV.h etc.).
# Copy additively whatever 3.10 does not already have.
for h in "$GPL"/include/linux/BSP_*.h "$GPL"/include/linux/bsp_*.h \
         "$GPL"/include/linux/syswatch_*.h; do
    [ -f "$h" ] || continue
    n=$(basename "$h")
    if [ ! -e "include/linux/$n" ]; then
        cp "$h" "include/linux/$n"
        echo "include/linux/$n: copied"
    fi
done

# Balong driver trees that the platform code reaches through relative includes
# ("../../../drivers/..." from mach-balong, "../drivers/..." from
# pwrctrl/sleepMgr). Vanilla 3.10 lacks them; copy from the GPL tree.
cp_driver_dir() { # <gpl-rel-dir>
    src="$GPL/$1"
    dst="$1"
    if [ -d "$src" ] && [ ! -d "$dst" ]; then
        cp -r "$src" "$dst"
        echo "$1: copied from GPL drivers"
    fi
}
cp_driver_dir drivers/led_drv
cp_driver_dir drivers/mntn
cp_driver_dir drivers/SoftTimer
cp_driver_dir drivers/nvim
cp_driver_dir drivers/input/keyboard/balong_keyboard
cp_driver_dir drivers/staging/balong_oled_emi
cp_driver_dir drivers/staging/balong_tft_emi
if [ -f "$GPL/drivers/rtc/balong_rtc.h" ] && [ ! -e "drivers/rtc/balong_rtc.h" ]; then
    cp "$GPL/drivers/rtc/balong_rtc.h" drivers/rtc/balong_rtc.h
    echo "drivers/rtc/balong_rtc.h: copied"
fi

# pwrctrl/sleepMgr reaches the balong driver headers via "../drivers/...";
# mirror them under pwrctrl/drivers so the relative include resolves.
mirror_driver_dir() { # <gpl-rel-dir>
    src="$GPL/drivers/$1"
    dst="arch/arm/mach-balong/pwrctrl/drivers/$1"
    if [ -d "$src" ] && [ ! -d "$dst" ]; then
        mkdir -p "$(dirname "$dst")"
        cp -r "$src" "$dst"
        echo "$dst: mirrored from GPL drivers"
    fi
}
mirror_driver_dir input/keyboard/balong_keyboard
mirror_driver_dir led_drv
mirror_driver_dir SoftTimer
mirror_driver_dir nvim
dst="arch/arm/mach-balong/pwrctrl/drivers/rtc/balong_rtc.h"
if [ -f "$GPL/drivers/rtc/balong_rtc.h" ] && [ ! -e "$dst" ]; then
    mkdir -p "$(dirname "$dst")"
    cp "$GPL/drivers/rtc/balong_rtc.h" "$dst"
    echo "$dst: mirrored"
fi

# linux/sysdev.h was removed in 3.x; balong platform files still #include it
# (mostly without using it). Provide a minimal empty shim.
if [ ! -f include/linux/sysdev.h ]; then
    cat > include/linux/sysdev.h <<'EOF'
#ifndef __LINUX_SYSDEV_COMPAT_H
#define __LINUX_SYSDEV_COMPAT_H
/* sysdev was removed from the kernel; kept as an empty shim for the
 * Balong 2.6 platform code that still lists it in its includes. */
#endif
EOF
    echo "include/linux/sysdev.h: shim created"
fi
if [ ! -f arch/arm/include/asm/leds.h ]; then
    cat > arch/arm/include/asm/leds.h <<'EOF'
#ifndef ASM_ARM_LEDS_COMPAT_H
#define ASM_ARM_LEDS_COMPAT_H
/* Led event interface was removed; empty shim for Balong platform code. */
#endif
EOF
    echo "asm/leds.h: shim created"
fi

# mmi.c pulls #include <../include/asm/uaccess.h>, which resolves to a bare
# include/asm/uaccess.h wrapper; forward it to the real ARM header.
if [ ! -f include/asm/uaccess.h ]; then
    mkdir -p include/asm
    cat > include/asm/uaccess.h <<'EOF'
#ifndef __BALONG_UACCESS_SHIM_H
#define __BALONG_UACCESS_SHIM_H
/* 2.6 balong code used <../include/asm/uaccess.h>; forward to the real one. */
#include_next <asm/uaccess.h>
#endif
EOF
    echo "include/asm/uaccess.h: shim created"
fi

# --- 3. arch/arm/Kconfig: ARCH_BALONG + source ----------------------------
if ! grep -q "config ARCH_BALONG" arch/arm/Kconfig; then
    awk '
        /source "arch\/arm\/mach-vexpress\/Kconfig"/ {
            print "config ARCH_BALONG"
            print "\tbool \"Hisilicon Balong family\""
            print "\tselect ARM_AMBA"
            print "\tselect GENERIC_CLOCKEVENTS"
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

# 3.10 requires ARCH_WANT_OPTIONAL_GPIOLIB to enable CONFIG_GPIOLIB.
# The 2.6 board selects were '... if GPIOLIB' (recursive) and got stripped; add
# an unconditional select in the ARCH_BALONG block instead (idempotent insertion).
awk '
    /config ARCH_BALONG/ { inbal = 1 }
    inbal && /select ARM_AMBA/ && !done {
        print "\tselect ARCH_WANT_OPTIONAL_GPIOLIB"
        done = 1
    }
    inbal && /^config [A-Z_0-9]+/ && !/^config ARCH_BALONG$/ { inbal = 0 }
    { print }
' arch/arm/Kconfig > arch/arm/Kconfig.new && mv arch/arm/Kconfig.new arch/arm/Kconfig
echo "arch/arm/Kconfig: ARCH_BALONG selects ARCH_WANT_OPTIONAL_GPIOLIB"

# --- 4. arch/arm/Makefile: machine hook ------------------------------------
if ! grep -q "machine-\$(CONFIG_ARCH_BALONG)" arch/arm/Makefile; then
    sed -i '/machine-\$(CONFIG_ARCH_VEXPRESS)/a machine-\$(CONFIG_ARCH_BALONG)\t+= balong' arch/arm/Makefile
    echo "arch/arm/Makefile: balong machine hook added"
else
    echo "arch/arm/Makefile: balong machine hook already present"
fi

# --- 4b. compat headers: 2.6-style gic/vic for balong -------------------------
# 3.10 moved GIC/VIC into drivers/irqchip and dropped the old
# <asm/hardware/{gic,vic}.h> headers; add thin 2.6-compatible shims so the
# ported platform code compiles unchanged.
mkdir -p arch/arm/include/asm/hardware
if [ ! -f arch/arm/include/asm/hardware/gic.h ]; then
    cat > arch/arm/include/asm/hardware/gic.h <<'EOF'
#ifndef __ASM_HARDWARE_GIC_COMPAT_H
#define __ASM_HARDWARE_GIC_COMPAT_H
#include <linux/types.h>
#include <linux/init.h>
extern void __init gic_init_bases(unsigned int gic_nr, int irq_start,
				  void __iomem *dist_base, void __iomem *cpu_base,
				  u32 percpu_offset);
static inline void __init gic_init(unsigned int start, unsigned int nr,
				   void __iomem *dist_base,
				   void __iomem *cpu_base)
{
	gic_init_bases(0, start, dist_base, cpu_base, 0);
}
#endif
EOF
    echo "compat gic.h: created"
fi
if [ ! -f arch/arm/include/asm/hardware/vic.h ]; then
    cat > arch/arm/include/asm/hardware/vic.h <<'EOF'
#ifndef __ASM_HARDWARE_VIC_COMPAT_H
#define __ASM_HARDWARE_VIC_COMPAT_H
#include <linux/types.h>
#include <linux/init.h>
extern void __init vic_init(void __iomem *base, unsigned int irq_start,
			    u32 vic_sources, u32 resume_sources,
			    struct device_node *node);
#endif
EOF
    echo "compat vic.h: created"
fi

# --- 4c. kbuild flag renames for copied balong Makefiles ---------------------
# 3.10 moved EXTRA_CFLAGS to ccflags-y (EXTRA_CFLAGS is dead there); without
# this the -I... flags in product_info/Makefile are silently ignored.
find arch/arm/mach-balong -name Makefile -exec \
    sed -i 's/EXTRA_CFLAGS/ccflags-y/' {} \;
echo "mach-balong Makefiles: EXTRA_CFLAGS renamed to ccflags-y"

# --- 4d. machine_desc / mem-types compatibility for 3.10 ----------------------
# 3.10 dropped .phys_io/.io_pg_offst/.boot_params/.timer, replaced sys_timer by
# .init_time, renamed MT_MEMORY_NONCACHED_READ_ONLY, and does not know the
# BALONG_V100R001 machine id (3339 from the 2.6 mach-types.h).
MACH_FILE=arch/arm/mach-balong/balong_v7r1asic.c
sed -i \
    -e 's/MT_MEMORY_NONCACHED_READ_ONLY/MT_MEMORY_NONCACHED/g' \
    -e '/static struct sys_timer pv500v1_timer = {/,/^};/d' \
    -e '/\.phys_io[[:space:]]*=/d' \
    -e '/\.io_pg_offst[[:space:]]*=/d' \
    -e 's/\.boot_params[[:space:]]*=/ .atag_offset =/' \
    -e 's/\.timer[[:space:]]*=[[:space:]]*&pv500v1_timer,/ .init_time = pv500v1_timer_init,/' \
    "$MACH_FILE"
echo "balong_v7r1asic.c: 3.10 machine_desc cleanups applied"

if ! grep -q "BALONG_V100R001" arch/arm/tools/mach-types; then
    printf 'balong_v100r001\tARCH_BALONG_V100R001\t\tBALONG_V100R001\t\t3339\n' \
        >> arch/arm/tools/mach-types
    echo "arch/arm/tools/mach-types: BALONG_V100R001=3339 added"
else
    echo "arch/arm/tools/mach-types: BALONG_V100R001 already present"
fi

# balong_core_v7r1asic.c carries its own clk_* (clk_enable/clk_disable/
# clk_get_rate/clk_get/clk_put); with CONFIG_COMMON_CLK=y these collide with the
# core clocks at link time (multiple definition). The CCF provides working
# wrappers, so drop the balong copies.
CORE_FILE=arch/arm/mach-balong/balong_core_v7r1asic.c
perl -0pi -e 's/\n+int clk_enable[^\n]*\n.*?\nvoid clk_put[^\n]*\n\}\n(\n*)/\n/* clk_* stubs from 2.6 removed: CCF provides them in 3.10 *\/\n/s' \
    "$CORE_FILE"
echo "balong_core_v7r1asic.c: clk_* stubs removed (CCF conflict)"

# BSP_DEVICE_EVENT.h publishes its device/key/event enums only under
# __VXWORKS__; in the 2.6 stock kernel the same Linux definitions lived in a
# patched <linux/netlink.h> (DEVICE_ID, USB_EVENT, KEY_EVENT, ...). 3.10 vanilla
# netlink.h lacks them, so carry that block over into BSP_DEVICE_EVENT.h which
# BSP.h always pulls in for Linux builds.
DVE=drivers/include/BSP_DEVICE_EVENT.h
if ! grep -q "^typedef enum _DEVICE_ID$" "$DVE"; then
    sed -n '/^typedef enum _DEVICE_ID$/,/^extern int device_event_handler_register/p' \
        "$GPL/include/linux/netlink.h" >> "$DVE"
    echo "BSP_DEVICE_EVENT.h: device/key event enums appended (from 2.6 netlink.h)"
else
    echo "BSP_DEVICE_EVENT.h: event enums already present"
fi

# BSP_PWC_SLEEPMGR.c: 2.6 .ioctl member does not exist in 3.10 file_operations;
# convert to unlocked_ioctl (inode param dropped, return long).
SLEEP_FILE=arch/arm/mach-balong/pwrctrl/sleepMgr/BSP_PWC_SLEEPMGR.c
sed -i \
    -e 's/^int PWRCTRL_Ioctl(struct inode \*inode,struct file \*file, unsigned int cmd,unsigned long data)/long PWRCTRL_Ioctl(struct file *file, unsigned int cmd, unsigned long data)/' \
    -e 's/^\([[:space:]]*\)\.ioctl[[:space:]]*= PWRCTRL_Ioctl,/\1.unlocked_ioctl = PWRCTRL_Ioctl,/' \
    "$SLEEP_FILE"
echo "BSP_PWC_SLEEPMGR.c: ioctl -> unlocked_ioctl"

# --- 4e. top-level Makefile: balong -D board/chip flags ---------------------
# Vanilla 3.10 does not know BOARD_TYPE/VERSION_TYPE; the GPL features rely on
# -DBOARD_ASIC -DCHIP_BB_6920CS (fixed E5372 / hi6920cs_asic target).
# Force the mach include dir too: with ARCH_MULTIPLATFORM=y the standard
# -I$(machdirs)include injection is disabled, so add it unconditionally.
if ! grep -q "\-DBOARD_ASIC \-DCHIP_BB_6920CS" Makefile; then
    cat >> Makefile <<'EOF'

# --- balong platform flags (E5372 / hi6920cs_asic) ---
KBUILD_CFLAGS += -DBOARD_ASIC -DCHIP_BB_6920CS
KBUILD_CPPFLAGS += -Iarch/arm/mach-balong/include
KBUILD_CPPFLAGS += -Idrivers/include
EOF
    echo "Makefile: balong -D flags + include dirs added"
else
    echo "Makefile: balong -D flags already present"
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