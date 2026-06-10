# FAE diagnostic images — BUILD A (BIST) and BUILD B (clock fix)

**Vendor:** LCD Mall FAE reply 2026-06 — two tests, **never combined in one image**.

| Build | Patch selector | Purpose |
|-------|----------------|---------|
| **BUILD A — BIST** | `0012` → `FAE_BIST` | Isolated self-test (vendor Test 2) |
| **BUILD A v2 — BIST** | `0012` + `0014` | BIST + **500 ms** after unlock + **no VIDEO_BURST** |
| **BUILD B — CLOCK** | `0013` → `FAE_CLOCK` | Page-4 MIPI fix + TE `0x35,0x00` (vendor Test 1) |

**Shared:** `0001`–`0011` + **`0014`** (0014 is inert on CLOCK build). Trace **0009** / **0010** enabled.

**`bbappend` default (2026-06):** **BUILD B** active (`0013`, not `0012`).

---

## Run order (mandatory)

1. **Flash BUILD A** → cold boot → **look at glass only** (ignore modetest).
2. Report: pattern vs backlit-black.
3. **Then** flash BUILD B → re-check `0x0A`, modetest, glass.

---

## Build commands

From repo root on TASK-002-class host.

### BUILD A — BIST

Ensure `linux-rockchip_%.bbappend` includes **0011** + **0012** and does **not** include **0013**:

```bash
kas shell kas/elevator-hmi.yml -c "\
  bitbake virtual/kernel -c compile -f && \
  bitbake virtual/kernel -c deploy -f && \
  bitbake core-image-minimal -c image_wic -f && \
  bitbake core-image-minimal -c image_complete -f"
```

**Latest BUILD A artifact (2026-06-06 — isolated BIST, no post-unlock 0x0A read):**

```
build/tmp/deploy/images/elevator-hmi-em3566/core-image-minimal-elevator-hmi-em3566.rootfs.wic
  → core-image-minimal-elevator-hmi-em3566.rootfs-20260606151107.wic
SHA-256: d2ce5af79091531f1e2a25ede10b90a91bb06f7c21e9e0c08714bc8884f92a1c
```

### BUILD B — clock fix (active in tree)

`bbappend` uses **0013** (not **0012**). Rebuild:

```bash
kas shell kas/elevator-hmi.yml -c "\
  bitbake linux-rockchip -c cleansstate && \
  bitbake virtual/kernel -c compile && bitbake virtual/kernel -c deploy && \
  bitbake core-image-minimal -c image_wic -f && \
  bitbake core-image-minimal -c image_complete -f"
```

**Latest BUILD B artifact (2026-06-06):**

```
build/tmp/deploy/images/elevator-hmi-em3566/core-image-minimal-elevator-hmi-em3566.rootfs-fae-clock.wic
  → core-image-minimal-elevator-hmi-em3566.rootfs-20260606161029.wic
SHA-256: 28e8037744454d69652074a89cb03cf9aa676485ca3462950fadf025c3725a3b
```

**Bench after flash (Step A):**

```bash
dmesg | grep -i jadard
# Expect: FAE page-4 clock fix (pre-SLPOUT), SLPOUT, DISON,
#         GET_POWER_MODE(0x0A) pre-TE=0x.., FAE TE on (0x35,0x00)
modetest -M rockchip -s 191@112:#0 -P 96@112:800x1280+0+0 -F tiles -v
```

### BUILD A v2 — BIST (optional retest)

In `linux-rockchip_%.bbappend`: comment **0013**, enable **0012** + keep **0014**; rebuild.

Expect: `FAE BIST path — VIDEO without BURST`, `BIST armed (500ms post-unlock)`.

**Latest BUILD A v2 artifact (2026-06-06):**

```
build/tmp/deploy/images/elevator-hmi-em3566/core-image-minimal-elevator-hmi-em3566.rootfs-fae-bist-v2.wic
  → core-image-minimal-elevator-hmi-em3566.rootfs-20260606161609.wic
SHA-256: 889d071d0dd4427be8901481e5d8bfeac966b6c0868f24a02a0e9e01f8923996
```

**Bench (Step B — optional retest before/after BUILD B):**

```bash
dmesg | grep -i jadard
# Expect: burst=0 in mode_flags line, "VIDEO without BURST",
#         "BIST armed (500ms post-unlock)" — look at glass only
```

---

## `bbappend` selector (manual)

File: `meta-hmi-platform/recipes-kernel/linux/linux-rockchip_%.bbappend`

**BUILD B (clock — flash now):**

```
SRC_URI += "file://0011-…-fae-bist-clock-seq.patch"
SRC_URI += "file://0014-…-fae-bist-v2-delay-noburst.patch"
# SRC_URI += "file://0012-…-fae-bist-desc.patch"
SRC_URI += "file://0013-…-fae-clock-desc.patch"
```

**BUILD A v2 (BIST retest):** comment **0013**, uncomment **0012** (keep **0014**).

---

## On-target PASS lines

### BUILD A

```bash
dmesg | grep -i jadard
```

Expect:

- `jadard: SLPOUT sent` / `jadard: DISON sent`
- `jadard: BIST armed` — **no** `GET_POWER_MODE` line after this (isolated BIST)

**Visual:** BIST pattern on glass = panel OK → proceed to BUILD B for MIPI path.

### BUILD B

Expect additionally:

- `jadard: FAE page-4 clock fix (pre-SLPOUT)`
- `jadard: GET_POWER_MODE(0x0A) pre-TE=0x..` (~50 ms after DISON, **before** TE)
- `jadard: FAE TE on (0x35,0x00)`

**pre-TE 0x0A:** sleep-out bit (0x10) and display-on (0x04) should be set if DISON latched.

```bash
modetest -M rockchip -s 191@112:#0 -P 96@112:800x1280+0+0 -F tiles -v
```

---

## FAE register map (byte-for-byte)

**Clock (before 0x11):** `E0,04` → `37,58` → `35,08` → `36,49` → `2C,06` → `E0,00`  
**Tail:** `0x11` → 120 ms → `0x29` → 5 ms → `35,00`

**BIST (after 0x11/0x29):** `F0,55` → `F1,AA` → `E0,01` → `E3,01`

---

## References

- Clock audit: `docs/LMT101-CLOCK-RATE-AUDIT.md`
- Lab cheat sheet Phase H: `docs/LAB-LMT101-TEST-CHEATSHEET.md`
- Vendor thread: `docs/VENDOR-SUPPORT-LMT101-BRINGUP-EMAIL.txt`
