# CLAUDE.md — Elevator HMI Project Master Context

**Read this file fully at the start of every session before taking any action.**
**Update `diary/PROGRESS.md` at the end of every session.**

---

## 1. Project Identity


| Field                        | Value                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| ---------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Product                      | Elevator Car HMI System                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| Target market                | Turkey and regional markets                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| Production volume            | 500–1,000 units/year                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| SoM                          | Compulab CM3566 (RK3566, 2 GB LPDDR4, 16 GB eMMC)                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| Reference carrier (bring-up) | **Boardcon EM3566 v3** — development kit / carrier for CM3566 (sources under `library/EM3566/`: schematic, Linux 6.1 manual, block diagram). Not the production elevator PCB; use it to validate kernel, panel, and RAUC flow.                                                                                                                                                                                                                                                                |
| Display                      | LMT101SX006C — 10.1" portrait, 800×1280, **4-lane** MIPI-DSI (vendor `0x80=0x03` → JD9365D **CMD_DSI_INT0** bits[1:0]=11 in `library/LMT101/LMT101SX006C initial codes.txt`), JD9365D driver IC — **attach to EM3566 v3 `MIPI LCD` connector** for bench work (see §6 R-02)                                                                                                                                                                                                                   |
| Build system                 | Yocto Scarthgap 5.0 LTS                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| Kernel                       | Linux 6.1.99 (Rockchip vendor fork) + JD9365D backport                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| UI                           | Qt 6.8 LTS — QML only, EGLFS backend, Mali-G52 GPU                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| Media                        | GStreamer + gst-plugins-rockchip (zero-copy VPU, H.264/H.265)                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| OTA                          | RAUC A/B partitioning, signed bundles                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| Protocol                     | Abstraction layer (PAL) — **elevator fieldbus PHY deferred** (RS-485 / CAN-FD not planned in Phase 0; revisit when product scope returns). **Interim bring-up link (Phase 0/1):** **UART serial console** on the board (host PC ↔ SoM) to watch **U-Boot/Linux boot**, **loaded image behaviour**, **systemd**, and **RAUC** messages — see §8 PAL; pinout on **EM3566 v3** in `library/EM3566/` (debug / UART headers). This is **lab/diagnostics**, not the ship-time controller interface. |
| Watchdog                     | Two-tier: systemd WDT + RK3566 hardware WDT                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| Operation                    | 24/7 unattended, industrial −20°C to +60°C (R-01: vendor −20°C test passed; see §6 for spec vs recommended range)                                                                                                                                                                                                                                                                                                                                                                             |
| Field life target            | 5+ years                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |


---

## 2. Current Phase Status

> **Update this section when phase changes.**


| Field                        | Value                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Active phase**             | Phase 0 — Foundation & Risk Mitigation                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| **Phase weeks**              | Weeks 1–3                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| **Phase gate**               | All risks resolved or accepted. Hardware ordered. Dev environment operational.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| **Current week**             | Week 1                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| **Blocking risks**           | R-01 / R-02 mitigated (2026-04-15/16); **production** carrier still needs schematic sign-off + formal −20°C acceptance — **EM3566 v3** is the agreed Phase 0/1 reference board                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| **Phase 1 lab (2026-06-02)** | **LMT101 on MIPI LCD:** Linux stack **PASS** (jadard init, DSI **468×4**, DRM plane **96** @ 60 Hz); **backlit black** on glass (**BLK-014**). **BLK-006** closed (XRES **GPIO0_C6**). **Plan B** 3.3 V on CON1 **5/6**. Vendor mail: `**docs/VENDOR-SUPPORT-LMT101-BRINGUP-EMAIL.txt`**. **TASK-106** software lab closed — gate = vendor FAE + MIPI scope. |


### §2.1 — Lab without LCD (owner checklist)

**Context:** **LMT101** not on **MIPI LCD** yet — **BLK-008** / **TASK-106** cannot close **display** validation. **Linux on board** is still useful for **disk, RAUC, logs, and a pre-panel baseline** (feeds **TASK-106** / **BLK-008** “before” when the panel arrives).

1. **Image** — Run a `**develop`** build **at or after TASK-111** (RAUC `**p2`/`p3`**, extlinux / DTS fixes). **Reflash** if the running image is older.
2. **Partition audit** — On target: `**lsblk -f`**, `**cat /proc/partitions**`; paste into `**diary/PROGRESS.md**` (optional **BLK-009** audit trail).
3. **GPT** — If `**dmesg`** still reports **backup GPT / header mismatch**: `**sgdisk -e /dev/mmcblk0`** (image includes `**gptfdisk**`), then reboot once.
4. **UART baseline** — Save **one** clean capture: U-Boot → Linux → login (single file or `**PROGRESS.md`** section) for **TASK-106** / **BLK-008** diff later.
5. **Pre-LCD `dmesg`** — Capture `**dmesg**` (or `**dmesg | egrep -i**` for `**vcc3v3_lcd0_n**`, `**vcca_1v8**`, `**backlight**`, `**jd9365**`, `**dsi**`, `**panel**`). In `**diary/PROGRESS.md**`, label the block `**pre-LCD baseline**` — expect some `**-EPROBE_DEFER` / “no panel”** noise with nothing connected; compare after cable-up (**BLK-008**).
6. **RAUC** — `**rauc status`**; note **D-Bus** / **systemd** errors for **TASK-116** (A2) if any.
7. **Optional** — `**ip link`**, `**lsusb**` — documents carrier bring-up without display.
8. **U-Boot countdown** — If `**Hit key to stop autoboot`** still shows `**0**`, rebuild `**u-boot-rockchip**` and reflash `**uboot.img**` so `**CONFIG_BOOTDELAY=5**` applies.

**When LCD arrives:** resume **TASK-106** (power / **MIPI LCD** per Boardcon); repeat `**dmesg`** + photo; **BLK-006** / **BLK-008** only with **cited** schematic or logs (**no invented GPIO**).

### Phase 0 Checklist

- Git repo structure initialized (kas manifest) — TASK-001 DONE 2026-04-15
- Vendor PDF library converted to Markdown — TASK-005 DONE 2026-04-15
- Build host setup script created — TASK-002 DONE 2026-04-15
- eMMC partition layout (WKS file) created — TASK-003 DONE 2026-04-15
- R-03: JD9365D backport patch prepared (panel-jadard-jd9365da-h3.c from Linux 6.2→6.1.99) — TASK-004 DONE 2026-04-15
- Phase 1 prep (kernel/DTS in tree): LMT101SX006C DSI fragment (`elevator-hmi-lmt101sx006c-panel.dtsi`) + optional `reset-gpios` follow-up patch on JD9365 driver/binding — **TASK-101 DONE** 2026-04-15  
- Phase 1 machine + panel integration: `**elevator-hmi-em3566`** machine, board DTS + `**&dsi0**` LMT101 overlay, kas default machine — **TASK-104 DONE** 2026-04-15 (kernel `**kas build virtual/kernel`** smoke: confirm on TASK-002 host — `lz4c` / HOSTTOOLS)  
- Phase 1 U-Boot eMMC bring-up fragment: `**u-boot-rockchip.bbappend**` + `**elevator-hmi-emmc-boot.cfg**`, `**UBOOT_LOCALVERSION**` — **TASK-102 DONE** 2026-04-15 (`kas build … u-boot` smoke: confirm on TASK-002 host)
- R-01: CM3566 −20°C — vendor: **4 h @ −20°C test passed**; datasheet **recommended** op still **0°C–70°C** — **accepted with documented caveat** (see `diary/BLOCKERS.md` BLK-001)
- R-02: MIPI vs LVDS — SoM **DSI/LVDS mux** (pins 25–34). **EM3566 v3** carrier exposes a dedicated **MIPI LCD** connector (same muxed TX bus also branches to optional **LVDS OUT**); use **MIPI LCD** + DT/strap for **MIPI-DSI** with LMT101 (see `diary/BLOCKERS.md` BLK-002); custom production carrier still needs its own review
- R-04: Adaptive backlight strategy documented — accepted — adaptive backlight dimming scheduled for Phase 3 (TASK-3xx). LED lifetime risk documented in R-04.
- Protocol interface — **fieldbus deferred** (no RS-485 / CAN-FD controller PHY for now; see BLK-004); **interim:** **UART console** for SoM bring-up and image diagnostics
- Backlight boost IC — **deferred** (constant backlight acceptable for now; see BLK-003)
- Boardcon **EM3566 v3** reference dev kit (**CM3566**) **on hand** — owner 2026-04-15
- LMT101SX006C panel ordered
- **First serial boot + `root` login** on **EM3566 v3** with `**core-image-minimal`** — **validated 2026-04-18** (see `**diary/PROGRESS.md`**); flash procedure + `**rkdeveloptool**` quirks documented  
- `kas build` / `bitbake core-image-minimal` for `**elevator-hmi-em3566**` — green `**./scripts/kas-build-task-105.sh**` on **TASK-002-class** host + evidence in `**diary/PROGRESS.md`** — **TASK-113 DONE** 2026-04-19  
- **LMT101** on **MIPI LCD** — **2026-06-02:** Linux stack PASS (jadard, DSI, DRM plane 96 @ 60 Hz); **pixels FAIL** backlit black (**BLK-014**); vendor mail in `**docs/VENDOR-SUPPORT-LMT101-BRINGUP-EMAIL.txt`**. **TASK-106** software lab closed; display gate = vendor + scope.
- **Owner — no-LCD lab** (§2.1): `**lsblk`**, optional **GPT** repair, **UART** baseline log, `**pre-LCD baseline`** `**dmesg**`, `**rauc status**`, optional **eth/USB** — capture in `**diary/PROGRESS.md`**  
- Phase 1 lab doc: `**docs/BRINGUP-CHECKLIST.md**` (kas, UART, flash pointers) — **TASK-107 DONE** 2026-04-15  
- **TASK-114** — `**docs/BRINGUP-CHECKLIST.md`** §8 “Lab without LCD” — **DONE** 2026-04-19 (A2 + A1 review; merged `**develop`**)

---

## 3. Technology Decisions (ADR-001 — Non-negotiable)

These decisions are final. Do not propose alternatives without a new ADR entry.


| Component        | Decision                         | Reason summary                                         |
| ---------------- | -------------------------------- | ------------------------------------------------------ |
| OS/Build         | Yocto Scarthgap 5.0 LTS          | Reproducible, minimal, RAUC-compatible, 5yr LTS        |
| Kernel           | Linux 6.1.99 Rockchip fork       | VPU/GPU maturity; mainline deferred to Phase 2 review  |
| Qt               | Qt 6.8 LTS                       | Qt 6.5 EOL April 2026; EGLFS, no Wayland/X11 overhead  |
| Media            | GStreamer + gst-plugins-rockchip | Zero-copy VPU decode mandatory for 24/7 thermal budget |
| OTA              | RAUC A/B                         | Signed, rollback-capable, Yocto native                 |
| Android 14       | REJECTED                         | Wrong model, slow boot, no RAUC, poor Qt integration   |
| Debian Buildroot | REJECTED                         | Non-reproducible, no A/B OTA, runtime apt is liability |
| Kirkstone        | REJECTED                         | EOL April 2025                                         |
| Qt 6.5           | REJECTED                         | EOL April 2026                                         |


---

## 4. Yocto Layer Architecture

```
meta-rockchip          # Community BSP. NEVER modified. Pinned to a commit hash.
meta-qt6               # Community Qt 6. NEVER modified. Pinned to a commit hash.
meta-rauc              # Community RAUC. NEVER modified. Pinned to a commit hash.
meta-hmi-platform      # Project BSP extensions:
                       #   - Kernel recipe with JD9365D backport patch
                       #   - Backlight driver recipe
                       #   - Partition layout (.wks file)
                       #   - systemd unit files for platform services
meta-hmi-app           # Application layer:
                       #   - Qt 6.8 QML application recipe
                       #   - GStreamer pipeline configuration
                       #   - Protocol abstraction service (PAL daemon) recipe
                       #   - RAUC bundle recipe
```

**Rule:** Community layers are read-only. All project modifications live in `meta-hmi-platform` and `meta-hmi-app`. No exceptions.

---

## 5. Partition Layout (Fixed at Image Build — Cannot Change Without Full Reflash)

**Source of truth:** `meta-hmi-platform/wic/elevator-hmi-emmc.wks.in` and `meta-hmi-platform/recipes-images/files/system.conf` (RAUC).

The shipping WIC defines a **four-partition GPT** on eMMC (not six). **Phase 1 bring-up** uses reduced sizes for reliable flashing; see the WKS file header. **Planned for Phase 2 image build:** expand rootfs and `/data` per WKS comments (e.g. **rootfs 2048 MiB**, **data 4096 MiB**) — **slot device numbers stay `p2` / `p3` for RAUC** unless a new TASK explicitly changes the layout.

  /dev/mmcblk0p1   boot      vfat  64M   (U-Boot + SPL + kernel + DTB)
  /dev/mmcblk0p2   rootfs_a  ext4  1024M (RAUC slot 0 — active)
  /dev/mmcblk0p3   rootfs_b  ext4  1024M (RAUC slot 1 — OTA target)
  /dev/mmcblk0p4   data      ext4  512M  (persistent — never erased by OTA)

Bring-up sizes. Production expansion: rootfs → 2048M, data → 4096M, planned Phase 2.

Note — CLAUDE.md previously described a 6-partition layout (with separate kernel_a/kernel_b partitions) that was never implemented. Corrected 2026-04-19.

**RAUC:** Rootfs slots in `system.conf` are `/dev/mmcblk0p2` and `/dev/mmcblk0p3` (**TASK-111**); must stay aligned with the WKS part order.

---

## 6. Open Risks


| ID   | Risk                                                                                                                                                                                                                                       | Severity          | Status                                                                                                                                                                                                                                                                                            |
| ---- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| R-01 | Datasheet “recommended” 0°C–70°C vs project −20°C.                                                                                                                                                                                         | High → **Medium** | **MITIGATED** — vendor reliability test **4 h @ −20°C ±2°C** passed; continuous −20°C still outside *recommended* wording — owner acceptance on file (BLK-001)                                                                                                                                    |
| R-02 | Debian “LVDS” vs LMT101 MIPI-DSI.                                                                                                                                                                                                          | High → **Low**    | **MITIGATED** — **EM3566 v3** block diagram: **MIPI LCD** connector is the intended DSI attach point; signals remain the SoM’s **shared LVDS/MIPI TX** bus (also routed to optional LVDS OUT). **Action:** DSI mode + LMT101 on **MIPI LCD**; validate on dev kit before custom carrier (BLK-002) |
| R-03 | JD9365D driver not in Linux 6.1.x. Mainline merge was 6.2.                                                                                                                                                                                 | Medium            | **MITIGATED** — TASK-004 backport patch + bbappend in `meta-hmi-platform` (validate on hardware in Phase 1)                                                                                                                                                                                       |
| R-04 | LED backlight lifetime ~2.3yr at 24/7 full brightness. Target is 5yr.                                                                                                                                                                      | Medium            | **ACCEPTED** — adaptive dimming in Phase 3                                                                                                                                                                                                                                                        |
| R-05 | JD9365D XRES reset on EM3566 v3 — `reset-gpios` on **GPIO0_C6** (CON1 pin 11). | Medium → **Low** | **MITIGATED (software)** — **BLK-006** closed **2026-06-02**; dmesg XRES pulse OK. Residual pixel failure tracked under **BLK-014** (not reset mapping). Optional scope on FPC pin 5 at production sign-off. |
| R-06 | LMT101SX006C absolute-max operating range **−20°C to 60°C** — project target **−20°C** sits exactly at the limit. | **Medium** | **OPEN** — spec PDF pages 6/7 confirm abs-max. Continuous operation at −20°C = panel at its rated boundary; no margin for transients or measurement error. **Phase 2+ review:** extended-temperature qualification or de-rating strategy. Not a bring-up blocker. |


---

## 7. Agent Roles

### This agent (Claude Code) — Lead

- Maintains this file and all files in `diary/`
- Owns `AGENTS.md` task queue — writes task specs for Composer2, marks them done
- Reviews all Composer2 output before it is merged
- Runs integration checks after each Composer2 task
- Escalates risks and blockers to project owner
- Updates phase status and decision log
- Is the single source of truth for project state

### Composer2 (Cursor) — Implementation

- Picks tasks from `AGENTS.md` task queue — only tasks marked `[READY]`
- Implements exactly as specified; does not deviate from architecture
- Reports completion by updating task status to `[REVIEW]` in `AGENTS.md`
- **Branching (mandatory):** creates and uses a branch named `task/TASK-NNN-short-description` for every task — never commit directly to `main` or `develop`; merge only after A1 marks `[DONE]`
- Never modifies community Yocto layers
- Never changes partition layout or RAUC key material
- See `.cursor/rules/elevator-hmi.mdc` for full rules

---

## 8. Coding Conventions

### Yocto recipes

- Recipe format: Yocto Scarthgap compatible (no deprecated syntax)
- All kernel patches named: `NNNN-description-of-patch.patch` (4-digit prefix)
- Patch applied via `SRC_URI` in kernel recipe, not by modifying kernel source directly
- All recipes in `meta-hmi-platform` or `meta-hmi-app` — never in community layers

### Qt / QML

- No C++ UI code — all UI is QML
- C++ backend exposes state to QML via `Q_PROPERTY` and signals only
- EGLFS backend — no Wayland, no X11, no window manager
- All QML files in `src/qml/`, mirrored in `meta-hmi-app` recipe

### Protocol Abstraction Layer (PAL)

- PAL is a separate systemd daemon — not part of the Qt application process
- Qt application communicates with PAL via D-Bus or Unix domain socket (TBD Phase 2)
- **Phase 0/1 — bring-up “comms” to the SoM:** use **UART serial console** (115200 8N1 typical on Rockchip BSPs — confirm in `meta-rockchip` / vendor U-Boot/kernel docs) from the **host PC** to the board’s **debug or UART header** (EM3566 v3 exposes UART1, UART2, and a **debug** port per board docs in `library/EM3566/`). Use it to see **what the loaded image is doing** (boot, login/getty, RAUC, application logs). **Image recipes** should keep **kernel command line + systemd** logging on that console until PAL fieldbus exists.
- **Phase 0/1:** elevator **fieldbus** (RS-485 / CAN-FD) **deferred** — no PHY/BOM for controller link until product scope returns; PAL remains the **software** abstraction for that future link.
- When fieldbus returns: PAL handles hardware protocol details (framing, retries, timeouts) without leaking bus headers into Qt
- Application layer never includes CAN or Modbus headers

### General

- All code committed with meaningful messages: `[phase][component] what changed and why`
- No WIP commits to main branch
- Branch naming: `task/TASK-NNN-short-description` for all A2 task branches
- Integration test results logged in `diary/PROGRESS.md`

---

## 9. Key Source References (in library/)


| Document                                                                 | What it covers                                      |
| ------------------------------------------------------------------------ | --------------------------------------------------- |
| `library/EM3566/Usermanual/CM3566_Hardware_Manual_V3.md`                 | CM3566 hardware manual — GPIO, pinout, interfaces   |
| `library/EM3566/Datasheet/Rockchip_RK3566_Datasheet_V1.5-20241211.md`    | RK3566 SoC datasheet (latest)                       |
| `library/EM3566/Linux6.1/Usermanual/EM3566 linux6.1 user manual_V1.0.md` | Linux 6.1 BSP user manual                           |
| `library/EM3566/Schematic/em3566_v3sch.md`                               | EM3566 schematic (text extraction)                  |
| `library/EM3566/Datasheet/K101-IM2KYL02-L3_MIPI.md`                      | MIPI panel datasheet (R-02 reference)               |
| `docs/roadmap-v1.md`                                                     | Full 32-week roadmap, phase gates, deliverable list |
| `docs/platform-decisions-v1.md`                                          | ADR-001 — all technology decisions with rationale   |


*Note: LMT101SX006C, SKD41, ACM reference PDFs not yet in library/ — add when obtained.*

---

## 10. Session Start Protocol

1. Read this file (`CLAUDE.md`) fully.
2. Read `diary/PROGRESS.md` — last 10 entries minimum.
3. Read `AGENTS.md` — check task queue status.
4. Check `diary/BLOCKERS.md` — any open blockers?
5. Then proceed with the session goal.

## 11. Session End Protocol

1. Update `diary/PROGRESS.md` with what was done, any findings, next actions.
2. Update `AGENTS.md` — add new tasks for Composer2 if applicable, update task statuses.
3. Update `diary/BLOCKERS.md` — add new blockers, close resolved ones.
4. Update section 2 (Current Phase Status) if phase or checklist changed.
5. Commit all diary/status changes with message: `[diary] YYYY-MM-DD session summary`

