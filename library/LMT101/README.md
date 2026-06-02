# LMT101 class panel — library notes (Elevator HMI)

Project product panel is **LMT101SX006C** (portrait **800×1280**; **MIPI DSI** routed as **four** lanes on CON1 harness; **`{0x80,0x03}`** in vendor init sets **JD9365D CMD_DSI_INT0** to **four** lanes), JD9365D per [`CLAUDE.md`](../../CLAUDE.md). This folder holds **vendor connector and electrical notes** extracted from datasheets when available.

| File | Contents |
|------|----------|
| [`LMT101-40pin-FPC-input-terminals.md`](LMT101-40pin-FPC-input-terminals.md) | Section 3 pin list (40-pin FPC) + §8.1 DC characteristics (summary) |
| [`EM3566-CON1-to-panel-40pin-mapping.md`](EM3566-CON1-to-panel-40pin-mapping.md) | **FPC pin ↔ CON1 pin** signal map (MIPI, 3.3 V, GND) + reset/backlight notes |
| [`LMT101SX006C initial codes.txt`](LMT101SX006C%20initial%20codes.txt) | **LCD Mall** JD9365D MIPI DCS init — **single source of truth** for **`lmt101sx006c_init_cmds[]`** (**TASK-125** / `0003-*-vendor-init.patch`). Tracked in Git. A duplicate at repo root is optional for local editing only; prefer this path for reviews. (**`{0x80,0x03}`** ⇒ **4** lanes.) |

**Bring-up:** Use **`LMT101SX006C initial codes.txt`** + kernel **`0003-*-vendor-init.patch`** only. Ignore other ad-hoc init sources in this folder unless A1 documents them.

**Vendor support message (full hardware + Linux + verification matrix):** [`docs/VENDOR-SUPPORT-LMT101-BRINGUP.md`](../../docs/VENDOR-SUPPORT-LMT101-BRINGUP.md).

**Original PDF (owner):** place a copy here as `1756115401449443.pdf` (or symlink) if you want it versioned with the repo; otherwise keep under your vault and cite path in commits when wiring changes.

**Vendor line on excerpt:** LCD Mall / AllTouchDisplay (`www.AllTouchDisplay.com`).

**Board map:** EM3566 v3 **CON1** — see [`../EM3566/Usermanual/EM3566_hardware_manual.md`](../EM3566/Usermanual/EM3566_hardware_manual.md) §2.8 and [`../EM3566/Schematic/em3566_v3sch.md`](../EM3566/Schematic/em3566_v3sch.md) (MIPI_DSI_TX0_* / `LCD_BL_PWM`, `VCC3V3_LCD`, etc.).
