# Elevator HMI

Yocto (Scarthgap) workspace for the elevator car HMI — Compulab CM3566 (RK3566), Qt 6.8 QML, RAUC, and Rockchip BSP layers.

## Prerequisites

- **Disk:** tens of GB free (downloads, sstate, and build output).
- **Tools:** Python 3, Git, and [kas](https://kas.readthedocs.io/) (for example `pip install kas` in a virtualenv, or your distro package).
- **Host packages:** Scarthgap expects standard Yocto host utilities (including `lz4c` from `liblz4-tool` on Debian/Ubuntu). A scripted install is defined in **TASK-002** (`scripts/setup-build-host.sh` — **Ubuntu 22.04 or 24.04 LTS**).

## Building with kas

Always run kas from the **repository root** so `KAS_WORK_DIR` is the project root (paths to `meta-hmi-platform` and `meta-hmi-app` are relative to that directory).

```bash
cd /path/to/elevator-hmi
kas build kas/elevator-hmi.yml
```

Useful variants:

```bash
# Inspect the flattened configuration (no BitBake run)
kas dump kas/elevator-hmi.yml

# Open a shell with BitBake environment (after repos are checked out)
kas shell kas/elevator-hmi.yml
```

The default image target is `core-image-minimal` with `MACHINE = elevator-hmi-em3566` (Boardcon EM3566 v3 bring-up; `conf/machine/elevator-hmi-em3566.conf` in `meta-hmi-platform` requires `rockchip-rk3566-evb` from `meta-rockchip` and overrides `KERNEL_DEVICETREE` only). U-Boot uses **`u-boot-rockchip.bbappend`** in `meta-hmi-platform` for an eMMC-oriented Kconfig fragment (TASK-102).

## Layers in this manifest

| Layer / repo | Role |
|--------------|------|
| `poky` | Yocto 5.0 LTS (Scarthgap), tag `yocto-5.0.16` |
| `meta-openembedded` | `meta-oe` + `meta-python` — **required** by `meta-rockchip` (see upstream README) |
| `meta-rockchip` | Rockchip BSP (`scarthgap` branch) |
| `meta-qt6` | Qt 6 (`lts-6.8.7` — Qt 6.8 LTS, Scarthgap-compatible) |
| `meta-rauc` | RAUC OTA (`scarthgap` branch) |
| `meta-hmi-platform` | Project BSP extensions (kernel, WIC, systemd, …) |
| `meta-hmi-app` | Application recipes (Qt app, PAL, …) |

All upstream repos are pinned to **40-character commit SHAs** in `kas/elevator-hmi.yml` (no floating branches).

## Project layout

| Path | Description |
|------|-------------|
| `kas/elevator-hmi.yml` | kas manifest |
| `meta-hmi-platform/` | Custom BSP layer |
| `meta-hmi-app/` | Custom application layer |
| `CLAUDE.md` | Project context and phase status |
| `AGENTS.md` | Task queue (multi-agent workflow) |

## Documentation

Hardware, roadmap, and ADRs are described in `CLAUDE.md` and the PDFs referenced there.

**Lab bring-up:** [`docs/BRINGUP-CHECKLIST.md`](docs/BRINGUP-CHECKLIST.md) — TASK-002 host, `kas` builds, deploy paths, UART, MIPI LCD, flash doc pointers (no guessed offsets).

**Panel vendor / LCD Mall support (connections → Linux → verification):** [`docs/VENDOR-SUPPORT-LMT101-BRINGUP.md`](docs/VENDOR-SUPPORT-LMT101-BRINGUP.md). **Plain-text email to paste:** [`docs/VENDOR-SUPPORT-LMT101-BRINGUP-EMAIL.txt`](docs/VENDOR-SUPPORT-LMT101-BRINGUP-EMAIL.txt).
