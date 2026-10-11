# KnightSaver Supabase backend

Hosted hackathon project: `prbohivlnyodesbiavyu` (`us-east-1`). The iOS app uses only the project's publishable key; secret and service-role keys must never be added to the app or repository.

`migrations/202610100001_initial_schema.sql` is the source of truth for the database schema, policies, and transactional RPCs. `seed.sql` supplies the UCF campus, Knightro's Kitchen, its pickup location, and one demo listing.

Demo identities are intentionally limited to:

- `alex@ucf.edu` — student
- `manager@knightros.example` — Knightro's Kitchen manager

Both use the hackathon-only password `KnightSaverDemo!2026`. The app's one-tap demo buttons sign into these real Supabase accounts. Rotate or remove them before any production launch.

After either account signs in, the iOS app calls `bootstrap_demo_identity()`. The manager account is then assigned to the seeded business and location. Remove that bootstrap function before a production launch and provision staff through an admin-only workflow.

Critical writes are RPC-only:

- `reserve_listing` locks inventory so the final bag cannot be oversold.
- `cancel_reservation` restores inventory and advances one waitlist entry.
- `scan_knight_pass` limits matches to the staff member's location and pickup window.
- `verify_pickup` is idempotent and creates impact and optional leaderboard credit once.

The current hackathon reservation RPC records a simulated authorization for paid bags. Stripe manual authorization/capture belongs in an Edge Function and webhook before launch.

The native client lives in `ios/KnightSaver/KnightSaver/App/KnightSaverBackend.swift`. It deliberately uses `URLSession` instead of another package dependency and falls back to the existing local demo if the service cannot be reached.
