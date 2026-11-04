# MgameIO Launcher — GitHub update channel

Official update feed:
https://raw.githubusercontent.com/MOnarh-ja1/RUNIVERSE/main/launcher/catalog.json

MgameIO Launcher **1.0.8** checks this URL on startup and when the user presses Refresh. After verified releases are published, the feed contains their download URL, game version, and SHA-256 checksum.

**Current status:** RUNIVERSE v3.3.1 Classic Restore is a draft release without the original binary attached. The feed is intentionally empty until the original **RUNIVERSE 3.2 FIXED** executable is uploaded to that release and its digest matches the exact SHA-256:

`780654c2c122b19cf7d74813c4fefd0df5125817394645f89e451e507f5ef46b`

The file must be the original 112,322,516-byte EXE. Do not use rebuilt RUNIVERSE 3.3.0: that version changed the gameplay.

The workflow `.github/workflows/classic-restore.yml` listens for publication of v3.3.1, verifies the attached EXE and writes `launcher/catalog.json`. Only an approved, correctly hashed file appears as a download.

**Until then:** launcher 1.0.8 offers the original game from the offline Windows ZIP package. No online installation of the 3.2 FIXED original is claimed yet.

The launcher executable itself is delivered separately. This GitHub feed updates **games**, not the launcher binary.
