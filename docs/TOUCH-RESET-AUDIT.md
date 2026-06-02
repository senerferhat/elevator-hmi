# TOUCH_RST / XRES GPIO Audit Report

This report documents the hardware and software mapping for the panel/touch reset line on the Boardcon EM3566 v3 carrier board. It reconciles conflicting claims between previous implementations and the schematic/hardware manual.

## 1. Verbatim Schematic & Hardware Manual Pin Map

By cross-referencing the authoritative schematic PDF (owner-locked) and `library/EM3566/Usermanual/EM3566_hardware_manual.md`, we establish the following connections:

### CON1 Connector Pin Definitions (Hardware Manual §2.8):
* **Pin 11**: `TOUCH_RST` (Description: Touch screen reset)
* **Pin 12**: `TOUCH_INT` (Description: Touch screen interrupt)

### SoM Pin Definitions and Mappings to SoC GPIO (Hardware Manual):
* **SoM Pin 131**: `SPI0_CS0_M0` / `GPIO0_C6_d` (3.3V IO voltage)
* **SoM Pin 132**: `SPI0_MISO_M0` / `GPIO0_C5_d` (3.3V IO voltage)

### Correct Hardware PDF Mapping:
* **TOUCH_RST** (CON1 Pin 11) is routed to SoM Pin 131, which is **`GPIO0_C6`** (`SPI0_CS0_M0`).
* **TOUCH_INT** (CON1 Pin 12) is routed to SoM Pin 132, which is **`GPIO0_C5`** (`SPI0_MISO_M0`).

*(Note: The text extraction in `em3566_v3sch.md:1035` contained adjacent-row table transposition errors. The schematic PDF itself confirms the above pin assignment).*

---

## 2. Decompiled DTB Comparison

We compare the DTB binary currently flashed/running on the board against the freshly built DTB at `HEAD`.

### Flashed/Running Board DTB:
* `/sys/kernel/debug/gpio` shows **`gpio-22`** owned by the `"reset"` line of the panel driver (released active-high at idle).
* **`gpio-22`** corresponds to **`GPIO0_C6`** (RK_PC6).
* **Why**: The board is running an older DTB build (from commit `287374c09be9` or similar), where `reset-gpios` was set to `RK_PC6`.

### Freshly Built DTB (Jun 2 23:13 build):
* Decompiling the deployed DTB binary shows:
  ```dts
  panel@0 {
      compatible = "elevator-hmi,lmt101sx006c\0jadard,jd9365da-h3";
      reset-gpios = <0x3a 0x16 0x01>; /* gpio0, 0x16 = 22 = GPIO0_C6 */
  };
  ```
* **`GPIO0_C6`** corresponds to `RK_PC6` (gpio-22).
* **Why**: The DTSI source was reverted to `RK_PC6` in the working tree, and the Yocto kernel has now been successfully rebuilt to compile this into the final deployed DTB binary.

---

## 3. Adjudication: C5 vs C6

Based on the schematic PDF, we adjudicate which pin is the correct panel reset line:

| Net / Function | Schematic Pin / Net Name | SoC GPIO | Linux GPIO |
|---|---|---|---|
| **Panel Reset (XRES)** | CON1 Pin 11 (`TOUCH_RST`) | **GPIO0_C6** | **gpio-22** |
| **Touch Interrupt** | CON1 Pin 12 (`TOUCH_INT`) | **GPIO0_C5** | **gpio-21** |

### Conclusion:
1. **The correct physical reset pin is GPIO0_C6 (gpio-22)**.
2. The current working tree DTS (`RK_PC6` / gpio-22) and freshly built DTB (`0x16`) are **physically correct**.
3. Previous concerns about `GPIO0_C5` (gpio-21) / `vcc3v3_lcd1_n` contention are **irrelevant**, as the reset line does not route to C5.
4. The only contention for `GPIO0_C6` is with `spi0` (which claims it as `SPI0_CS0_M0`). This is fully resolved by having **`spi0` disabled** in the board DTS.

---

## 4. PMU IO-Domain Voltage Verification

In `elevator-hmi-boardcon-em3566-v3.dts`:
```dts
&pmu_io_domains {
    status = "okay";
    pmuio1-supply = <&vcc_3v3_fixed>;
    pmuio2-supply = <&vcc_3v3_fixed>;
};
```
Both `pmuio1` and `pmuio2` (which supply the PMU IO domain containing GPIO0) are tied to `vcc_3v3_fixed` (3.3V).
* **PMU IO-Domain Voltage**: **3.3 V**.
* There is **no voltage mismatch** with the 3.3V level of the panel's reset line.
