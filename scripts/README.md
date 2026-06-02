# Scripts

## `setup-build-host.sh`

Prepares an **Ubuntu 22.04 or 24.04 LTS** machine for Yocto Scarthgap builds (kas, BitBake host dependencies, lz4, SDL for QEMU menus, and related tools).

Requirements:

- sudo for `apt-get`
- Run on Ubuntu **22.04** or **24.04** LTS (`/etc/os-release` `VERSION_ID` — other releases exit with an error).

Usage:

```bash
./scripts/setup-build-host.sh
```

Afterwards:

- Ensure `~/.local/bin` is on your `PATH` if you rely on `pip install --user kas`.
- `kas --version` should print the installed version.
- `bitbake --version` is verified using a **cached shallow** `poky` checkout at `yocto-5.0.16` under `${XDG_CACHE_HOME:-$HOME/.cache}/elevator-hmi/poky-yocto-5.0.16` (first run downloads it).

Project images are built via kas from the repository root — see the root `README.md`.

**On-target (minimal image):** `libgpiod-tools` provides `gpiodetect`, `gpioinfo`, `gpioset`. Panel **XRES** is **`gpiochip0` line 22** (CON1 pin 11). While `jadard` is loaded, `gpioset` on that line should return **EBUSY** — see `docs/LMT101-XRES-SCOPE-PROCEDURE.md`.

## `kas-build-task-105.sh`

Runs **TASK-105** kas smoke targets in order (`**u-boot-rockchip`**, `**virtual/kernel`**, default `**core-image-minimal**`) and tees stdout/stderr into `**build-logs/**` (gitignored).

Requirements:

- Same host prep as `**setup-build-host.sh**` (Ubuntu **22.04** or **24.04**; `**liblz4-tool`** so `**lz4c`** is on `**PATH`** for BitBake **HOSTTOOLS**).
- Run from anywhere; the script `**cd`**s to the repository root.

Usage:

```bash
./scripts/kas-build-task-105.sh
```

## `rauc-gen-keys.sh`

**TASK-108:** generates **development-only** RAUC signing material under `**certs/`** (gitignored). Read the script header — **never** commit generated keys; production keys are offline / HSM only.

```bash
./scripts/rauc-gen-keys.sh
```

See `**certs/README.md**`.

## `convert-library.sh`

Vendor PDF → Markdown conversion helper (see script header for usage).