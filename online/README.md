# RUNIVERSE online accounts and leaderboard (development only)

This folder is a work-in-progress implementation. It does **not** change the compiled classic RUNIVERSE 3.2 FIXED.

**Server:** Node.js (Express, google-auth-library, SQLite). `POST /api/auth/google` verifies a Google ID token; `GET /api/profile` shows profile and best distance; `GET /api/leaderboard` returns worldwide top 100; `POST /api/scores` adds a run.

Before going live: create Google Cloud OAuth credentials, set up a secure HTTPS server and database, implement desktop browser OAuth + PKCE and connect it in the editable original Godot game project; add game-result attestation/anti-cheat, profile privacy controls, and test on Windows.

The current GitHub launcher catalog must remain on verified classic 3.3.1 until an actual playable updated EXE is built and tested. Please do **not** publish this backend code as an advertised game update.
