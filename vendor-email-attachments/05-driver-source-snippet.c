/*
 * Excerpted from our Linux kernel DRM panel driver for LMT101SX006C / JD9365D.
 * Provided to LCD Mall / vendor FAE for direct review against your reference
 * implementation. Not a complete file — three functions/structs relevant to
 * the "digitally perfect but timing controller never starts" symptom.
 *
 * Full driver: drivers/gpu/drm/panel/panel-jadard-jd9365da-h3.c (backported
 * from upstream Linux 6.2 to our 6.1.99 Rockchip vendor kernel), extended
 * with vendor-supplied init table + our own diagnostic reads (DIAG15).
 */

/* ------------------------------------------------------------------------
 * 1) Reset sequence — called once at panel power-up.
 * ------------------------------------------------------------------------ */
static int jadard_prepare(struct drm_panel *panel)
{
	struct jadard *jadard = panel_to_jadard(panel);
	int ret;

	ret = regulator_enable(jadard->vccio);
	if (ret)
		return ret;

	ret = regulator_enable(jadard->vdd);
	if (ret)
		return ret;

	msleep(10);   /* wait after rails before touching RESX */

	if (jadard->reset) {
		/* GPIO_ACTIVE_LOW in DT: set_value(0) = pad HIGH, set_value(1) = pad LOW */
		gpiod_set_value(jadard->reset, 0);
		msleep(5);                          /* RESX high settle, per vendor init file */

		gpiod_set_value(jadard->reset, 1);  /* RESX asserted (LOW) */
		msleep(20);                         /* vendor Q1 diagram: 20 ms low pulse */

		gpiod_set_value(jadard->reset, 0);  /* RESX released (HIGH) */
	}

	msleep(jadard->desc->post_reset_delay ?: 120); /* before first MIPI command */

	return 0;
}

/* ------------------------------------------------------------------------
 * 2) Init + power-on sequence — called once per modeset.
 * ------------------------------------------------------------------------ */
static int jadard_enable(struct drm_panel *panel)
{
	struct jadard *jadard = panel_to_jadard(panel);
	struct mipi_dsi_device *dsi = jadard->dsi;
	u8 reg, id[3], selfdiag, scanline;
	int ret;

	/* Vendor's 196-entry table, byte-identical to LMT101SX006C initial
	 * codes.txt, sent as one MIPI generic/DCS write per register pair. */
	ret = jadard_init_sequence(jadard);
	if (ret) {
		dev_err(&dsi->dev, "jadard: init table failed: %d\n", ret);
		return ret;
	}
	dev_info(&dsi->dev, "jadard: init table: 196 cmds, rc=0\n");

	/* Vendor "Test-1" page-4 clock fix, sent immediately before Sleep Out */
	{
		static const u8 clockfix[][2] = {
			{0xE0, 0x04}, {0x37, 0x58}, {0x35, 0x08},
			{0x36, 0x49}, {0x2C, 0x06}, {0xE0, 0x00},
		};
		for (int i = 0; i < ARRAY_SIZE(clockfix); i++)
			mipi_dsi_dcs_write_buffer(dsi, clockfix[i], 2);
		dev_info(&dsi->dev, "jadard: FAE page-4 clock fix (pre-SLPOUT)\n");
	}

	mipi_dsi_dcs_exit_sleep_mode(dsi);   /* 0x11 SLPOUT */
	msleep(120);
	dev_info(&dsi->dev, "jadard: SLPOUT sent\n");

	{
		static const u8 page0[2] = {0xE0, 0x00};
		mipi_dsi_dcs_write_buffer(dsi, page0, 2);
	}

	mipi_dsi_dcs_set_display_on(dsi);    /* 0x29 DISON */
	dev_info(&dsi->dev, "jadard: DISON sent\n");

	msleep(50);

	mipi_dsi_dcs_read(dsi, MIPI_DCS_GET_POWER_MODE, &reg, 1);
	dev_info(&dsi->dev, "jadard: GET_POWER_MODE(0x0A) pre-TE=0x%02x\n", reg);
	/* -> observed 0x1c on every build/rate tested */

	mipi_dsi_dcs_read(dsi, MIPI_DCS_GET_DISPLAY_ID, id, 3);
	dev_info(&dsi->dev, "jadard: DIAG15 ID=0x%02x 0x%02x 0x%02x (expect 93 65 04)\n",
		 id[0], id[1], id[2]);
	/* -> observed 0x93 0x00 0x00 (manufacturer ID correct, module ID reads 0) */

	mipi_dsi_dcs_read(dsi, MIPI_DCS_GET_DIAGNOSTIC_RESULT, &selfdiag, 1);
	dev_info(&dsi->dev, "jadard: DIAG15 self-diag=0x%02x "
		 "(0xC0=OK 0x80=func-fault 0x40=reg-fault 0x00=dead)\n", selfdiag);
	/* -> observed 0xc0 (IC self-test reports healthy) */

	msleep(5);
	{
		static const u8 te_on[2] = {0x35, 0x00};
		mipi_dsi_dcs_write_buffer(dsi, te_on, 2);
		dev_info(&dsi->dev, "jadard: FAE TE on (0x35,0x00)\n");
	}
	msleep(20);

	mipi_dsi_dcs_read(dsi, MIPI_DCS_GET_SCANLINE, &scanline, 1);
	dev_info(&dsi->dev, "jadard: DIAG15 scanline=0x%02x (non-0=timing-ctrl-running)\n",
		 scanline);
	/* -> observed 0x00 on EVERY build, EVERY rate, EVERY test to date.
	 *    This is the core unresolved symptom: TCON self-reports healthy
	 *    (0x0F=0xC0) but never actually starts running (0x45 stays 0x00),
	 *    and the glass stays backlit black. */

	return 0;
}

/* ------------------------------------------------------------------------
 * 3) Panel timing descriptor — matches vendor init-file porches exactly.
 * ------------------------------------------------------------------------ */
static const struct drm_display_mode lmt101sx006c_mode = {
	.clock       = 70000,             /* kHz; matches vendor PLL_CLOCK reference */
	.hdisplay    = 800,
	.hsync_start = 800 + 40,           /* hfront_porch = 40 */
	.hsync_end   = 800 + 40 + 20,      /* + hsync_len   = 20 */
	.htotal      = 800 + 40 + 20 + 20, /* + hback_porch = 20 */
	.vdisplay    = 1280,
	.vsync_start = 1280 + 30,          /* vfront_porch = 30 */
	.vsync_end   = 1280 + 30 + 4,      /* + vsync_len   = 4  */
	.vtotal      = 1280 + 30 + 4 + 10, /* + vback_porch = 10 */
};

static const struct jadard_panel_desc lmt101sx006c_desc = {
	.mode              = &lmt101sx006c_mode,
	.lanes             = 4,
	.format            = MIPI_DSI_FMT_RGB888,
	.post_reset_delay  = 120,
	.sleep_mode_delay  = 0,
	.display_init_delay= 120,
	.display_on_delay  = 5,
	/* MIPI_DSI_MODE_VIDEO_BURST intentionally NOT set for this panel
	 * (patch 0019) so the host computes a non-burst rate. With no
	 * `rockchip,lane-rate` DT override this yields ~468 Mbps/lane; with
	 * the override set to <420> it yields exactly your stated
	 * PLL_CLOCK=420 Mbps/lane. Both produce identical panel registers. */
};
