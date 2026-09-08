# Huawei E5372 — Android kernel 3.10 port (research & bring-up)

Port of the Huawei / Balong Hi6920 (V7R1) router firmware from its stock
**Android 2.3.3 + Linux 2.6.35.7** kernel to a newer **Android 3.10** kernel,
targeting future WireGuard support (kernel module requires >= 3.10).

> Danger: single device, software-only debugging (no UART/JTAG). High brick risk.
> Recovery path planned via `balong_flash` + full partition backups.

## Milestones

1. Reproduce the stock kernel from GPL sources (2.6.35.7) — verify identical output.
2. Set up android-3.10 base kernel (Binder/Ashmem/Alarm/LowMemoryKiller present).
3. Port Balong-specific drivers from 2.6.35: mach-balong, MTD NANDC, MMC_BALONG,
   SERIAL_BALONG_V7R1, LTE modem ICC/SMD interface, chg/led/pmu, Broadcom dhd.
4. Build bootable 3.10 image; test on device; iterate.
5. Add WireGuard (wireguard-linux-compat supports 3.10+).

## What we already know (stock 2.6.35.7)

- Kernel cmdline: `=uw_tty0,115200 rdinit=/init mem=44m lpj=3989504`
- Machine: `MACH_BOARD_ES`, board id `hi6920cs_asic`
- Arch: ARMv7, EABI, **no FPU/NEON** (soft float)
- NAND: Balong NANDC (`MTD_NAND_BALONG_NANDC`), partitions via Ptable
- WiFi: Broadcom BCM43241, driver `dhd` (source ships in Huawei GPL)
- LTE modem on VxWorks; AP<->modem via SMD (`/dev/smd7`) + ICC
- Full original `.config` extracted from zImage (`CONFIG_IKCONFIG`)
  → `stock_firmware/kernel/kernel_config.txt` (reproduced by GPL build.sh)

## Toolchain

- Stock build: CodeSourcery G++ Lite 4.5.1 (`arm-linux-`, prefixed
  `/opt/4.5.1/bin/arm-linux-`), gcc 4.5.1 ctng-1.8.1-FA.
- HOST: build in GitHub Actions (ubuntu), cross-toolchain assembled per job.

## Repo layout

- `tools/` — helper scripts (extract_kernel.py, wiring)
- `docs/` — findings, partition tables, modem IPC notes
- `.github/workflows/` — CI: kernel build, config diff, image assembly