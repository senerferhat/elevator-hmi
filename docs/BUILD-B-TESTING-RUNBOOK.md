# BUILD B (Clock Fix) Target Verification Runbook

This document outlines the step-by-step procedure to flash, measure, and verify the newly compiled **BUILD B (Clock Fix)** image on the Boardcon EM3566 v3 carrier board with the LMT101SX006C display panel.

---

## 1. Artifact Verification & Chain of Custody

Before flashing, verify that the host files match the build environment exactly.

| Parameter | Value |
|---|---|
| **Git HEAD Commit** | `e19ae163b81db9c08b1b04813b313079787f0ff0` |
| **Branch** | `task/TASK-132-vcc3v3-lcd0-active-low-pfet` |
| **Target WIC Image** | `core-image-minimal-elevator-hmi-em3566.rootfs-20260610170030.wic` |
| **WIC SHA-256 Sum** | `dd5be78dec198a984dce271a658219b3e44006df58d04709a3bed66fbb9728ad` |
| **Symlink** | `core-image-minimal-elevator-hmi-em3566.rootfs-fae-clock.wic` |

### Host Verification Commands:
```bash
# Verify Git Commit
git rev-parse HEAD

# Verify WIC Hash
sha256sum build/tmp/deploy/images/elevator-hmi-em3566/core-image-minimal-elevator-hmi-em3566.rootfs-20260610170030.wic
```

---

## 2. Flash Sequence (Host Terminal)

1. Put the board into **Maskrom Mode**:
   - Power **OFF** the board.
   - **Hold** the **RECOVERY** button on the board.
   - Connect the **USB OTG** cable between the board and host.
   - **Release** the button after ~2 seconds.
   - Verify on host: `lsusb | grep 2207` (should return `2207:350a` in Maskrom or `2207:0006` in Loader).

2. Execute Flash Commands (Run from the deploy directory):
   ```bash
   cd build/tmp/deploy/images/elevator-hmi-em3566/
   WIC="core-image-minimal-elevator-hmi-em3566.rootfs-20260610170030.wic"

   # If in Maskrom mode (2207:350a), run the db step:
   sudo rkdeveloptool db loader.bin
   
   # Flash image, idblock, and uboot:
   sudo rkdeveloptool wl 0 "$WIC"
   sudo rkdeveloptool wl 64 idblock.img
   sudo rkdeveloptool wl 0x4000 uboot.img
   
   # Reboot board:
   sudo rkdeveloptool rd
   ```

3. Connect to Serial Console:
   ```bash
   sudo minicom -D /dev/ttyACM0 -b 1500000
   ```

---

## 3. Physical Bench Measurements (Step B1: VDDIN Power Audit)

Perform this audit during the boot sequence to determine if the panel's internal charge pump (booster) fails due to electrical sagging.

### Measurement A: DMM Voltage Probing
1. At the login prompt, measure the voltage on **CON1 pins 5/6** (VCC3V3_LCD) relative to **GND** (pins 3/4).
2. Measure the voltage directly on the **Panel FPC pins 2/3** (VDDIN) to rule out high contact resistance or drop across the FPC interface.
3. Record the voltages in the results worksheet below.

### Measurement B: VDDIN Current Profiling (Decisive)
1. Disconnect the Plan B jumper from CON1 5/6 to the FPC.
2. Hook up an external bench power supply set to **3.3V (current limit 1.0A)** to the Panel FPC pins 2/3 (VDDIN) and GND.
3. Monitor the current draw on the bench supply ammeter during boot, paying close attention to the **3.4 to 4.0 second** window (when the `SLPOUT` command is sent to exit sleep).
4. Record:
   - **Idle current** before the SLPOUT trigger: `________ mA`
   - **Peak/step current** when SLPOUT triggers at ~3.7s: `________ mA`
   - **Steady-state current** after boot completes: `________ mA`

---

## 4. Boot Log Verification (Step B2: Clock Fix)

Log in as `root` (no password) and check `dmesg` to verify driver initialization and check the booster register status:

```bash
dmesg | grep -i jadard
```

### Expected Output Signs:
- [x] Must contain: `jadard: FAE page-4 clock fix (pre-SLPOUT)`
- [x] Must contain: `jadard: FAE TE on (0x35,0x00)`
- [x] Must **NOT** contain: `BIST armed` (BIST is disabled in BUILD B)
- [x] Look for power mode readback: `jadard: GET_POWER_MODE(0x0A) pre-TE=0xXX`

### Register Analysis:
Compare your read value `0xXX` against the target state machine:

| Read Value | Booster (D7) | Sleep-Out (D4) | Normal Mode (D3) | Display On (D2) | Diagnostic Meaning |
|---|---|---|---|---|---|
| **`0x18`** | **0 (OFF)** | 1 (ON) | 1 (ON) | 0 (OFF) | Booster never started; LCD remains pitch black. |
| **`0x9C`** | **1 (ON)** | 1 (ON) | 1 (ON) | 1 (ON) | **PASS** — booster running, panel ready to display pixels. |

---

## 5. DRM Graphics Scanout Verification

1. Mount debugfs to enable plane state inspection:
   ```bash
   mount -t debugfs none /sys/kernel/debug
   ```

2. Confirm Plane 96 (`Smart1-win0`) configuration:
   ```bash
   cat /sys/kernel/debug/dri/0/state | grep -A 15 "plane\[96\]"
   ```
   *Expected:* Plane 96 is assigned to CRTC, showing framebuffer format `XR24`, resolution `800x1280`.

3. Trigger sustained test pattern on the primary plane:
   ```bash
   # Identify connector ID (usually 191)
   CONN=$(modetest -M rockchip 2>&1 | awk '/connected/ && /DSI-1/ {print $1; exit}')
   echo "Connector ID = $CONN"

   # Run test pattern on Plane 96
   modetest -M rockchip -s ${CONN}@112:#0 -P 96@112:800x1280+0+0 -F tiles -v
   ```
   *Observe the glass:*
   - If the glass shows colored tiles $\rightarrow$ **SUCCESS!**
   - If the glass remains black but the console prints `freq: 60.08Hz` continuously $\rightarrow$ **FAIL.** Record the output and proceed to the H4 checklist.

---

## 6. Lab Results Worksheet

Please fill out this worksheet and log it using the **Artifact-Triple Rule**.

### Verification Meta-Data:
* **WIC Filename:** `core-image-minimal-elevator-hmi-em3566.rootfs-20260610170030.wic`
* **WIC SHA-256:** `dd5be78dec198a984dce271a658219b3e44006df58d04709a3bed66fbb9728ad`
* **git rev-parse HEAD:** `e19ae163b81db9c08b1b04813b313079787f0ff0`
* **Target Build Signature Line (`dmesg`):** `________________________________________________`

### Measurements & Register Values:
| Measurement | Value | Expected | PASS / FAIL |
|---|---|---|---|
| **CON1 Pin 5/6 Voltage** | `_______ V` | 3.3 V | |
| **Panel FPC Pins 2/3 Voltage** | `_______ V` | 3.3 V | |
| **Idle Current (VDDIN)** | `_______ mA` | ~20 - 50 mA | |
| **SLPOUT Step Current** | `_______ mA` | Step-up observed | |
| **`GET_POWER_MODE(0x0A)` Value** | `0x_____` | `0x9C` | |
| **Glass Output (test pattern)** | `[ ] Tiles  [ ] Black` | Tiles | |

**Tester:** `____________________`  
**Date:** `____________________`
