VENDOR EMAIL #3 — EXPORT FOLDER
================================
Everything in this folder is ready to attach to the LCD Mall follow-up email.
Location: /home/sener/Projects/elevator-hmi/vendor-email-attachments/

WHAT'S HERE (ready to send):

  01-EMAIL-TO-SEND.txt
      Full email body, To/Cc/From/Subject already filled in. Copy-paste
      directly into your email client, or attach as-is if your client
      supports plain-text attachments.

  02-LMT101-VENDOR-FINAL-SUMMARY.md
      Full historical ledger (2026-06-13 vendor-match milestone) — gives
      the vendor's engineer full background if they want more than the
      email summary.

  03-dmesg-468Mbps-today-2026-07-04.txt
      Raw target console capture from today's clean-reads build (SHA
      962c58eb...). Verbatim, including the two terminal-truncated lines,
      with a note explaining exactly what was cut off and why — so nothing
      here can be mistaken for a fabricated number.

  04-dmesg-420Mbps-2026-06-13-historical.txt
      The vendor-rate (420 Mbps) reference capture. Labeled honestly as
      historical (2026-06-13 build), not re-captured live today — every
      420 Mbps attempt this week hit internal read timeouts unrelated to
      panel behavior (explained in the file; not vendor-actionable, so it's
      not in the main email body).

  05-driver-source-snippet.c
      Standalone, syntactically complete C excerpt of jadard_prepare(),
      jadard_enable(), and the panel timing descriptor — exactly what's
      compiled into the kernel today. Easiest thing to hand directly to
      their JD9365D application engineer for a line-by-line check.

STILL NEEDED FROM YOU BEFORE SENDING (I can't produce these):

  [ ] Photo of the glass — backlit black, external light bleed only.
      Drop it in this folder (e.g. 06-glass-photo.jpg) and it's ready to
      attach alongside the rest. If you already sent a photo in an earlier
      email in this thread, you can skip this and just note "photo
      previously sent" when you reply.

  [ ] Optional: full-width dmesg recapture if you want to hand the vendor
      an untruncated bandwidth line instead of the truncated one with the
      footnote (not required — footnote already explains it honestly).

HOW TO SEND:
  1. Open your email client, hit Reply on the LCD Mall thread
     ("Technical Support Request: JD9365D Initialization Array for
     LMT101SX006C").
  2. Paste the body of 01-EMAIL-TO-SEND.txt (skip the To/Cc/Subject header
     lines at the top since Reply already fills those in — just check the
     Subject line matches or update it).
  3. Attach files 02 through 05, plus your glass photo once added.
  4. Send.
