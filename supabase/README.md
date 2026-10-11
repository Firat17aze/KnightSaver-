# KnightSaver Supabase backend

Hosted hackathon project: `prbohivlnyodesbiavyu` (`us-east-1`). The iOS app uses only the project's publishable key; secret and service-role keys must never be added to the app or repository.

`migrations/202610100001_initial_schema.sql` is the source of truth for the database schema, policies, and transactional RPCs. `seed.sql` supplies the UCF campus, Knightro's, its pickup location, and one demo listing.

Demo identities are intentionally limited to:

- `alex@ucf.edu` — student
- `manager@knightros.example` — Knightro's manager

Both use the hackathon-only password `KnightSaverDemo!2026`. Rotate or remove these accounts before any production launch.

After either account signs in, the iOS app calls `bootstrap_demo_identity()`. The manager account is then assigned to the seeded business and location. Remove that bootstrap function before a production launch and provision staff through an admin-only workflow.

## Student sign-up with a UCF email code

Students create an account in the app with their name, an `@ucf.edu` email and a password. Supabase emails them a one-time code; once they enter it, the account is verified and the password is saved, so later sign-ins use email and password. `migrations/202610110001_ucf_student_emails.sql` makes the database refuse new accounts that aren't `@ucf.edu` (the demo manager excepted).

Dashboard setup, once:

1. **Custom SMTP** (Authentication › Emails › SMTP Settings). Supabase's built-in sender only delivers to members of the project's team, 2 emails an hour. Any SMTP service works; for the hackathon, a Gmail account with an [app password](https://myaccount.google.com/apppasswords) is quickest: host `smtp.gmail.com`, port `465`, the Gmail address as username and sender, the app password as password. Then raise the email rate limit under Authentication › Rate Limits.
2. **Email templates** (Authentication › Emails › Templates). New students get the **Confirm signup** email and returning addresses get the **Magic Link or OTP** email, so use the same code template in both, with subject `Your KnightSaver verification code` and body:
   ```html
   <h2>Your KnightSaver verification code</h2>
   <p>Enter this code in the KnightSaver app to verify your UCF email:</p>
   <p style="font-size:32px;font-weight:700;letter-spacing:6px">{{ .Token }}</p>
   <p>This code expires in one hour. If you did not request it, you can ignore this email.</p>
   ```
3. **The UCF-only rule**: run `migrations/202610110001_ucf_student_emails.sql` in the SQL Editor.

## Bag limit per listing

Each business has `businesses.max_bags_per_listing` (1–100, default 10): the most Surprise Bags one listing may have. Managers set it from the app's Profile tab through `set_max_bags_per_listing`, and the app reads it with `get_business_settings`. A trigger on `listings` refuses any new listing above the limit and any edit that grows a listing past it, so neither the AI proposal nor manual entry can beat it. Apply it by running `migrations/202610120001_business_bag_limit.sql` in the SQL Editor.

## Rewards

`migrations/202610130001_rewards.sql` backs the app's Rewards tab. Everything counts staff-verified pickups only (one `impact_events` row per verified pickup):

- **Saver Cash**: `reward_milestones` says what each number of pickups unlocks. Earned cash isn't stored, it follows from the pickups; `saver_cash_spends` records what staff took off bills, so the balance is earned minus spent.
- **Partner rewards**: toys, a keychain, a seed kit and a bike tune-up from shops off campus (`reward_partners`, demo names). The shops don't use KnightSaver: the student calls `redeem_partner_reward` at the counter and shows the one-time code, recorded once in `partner_reward_redemptions`.
- **Campus Rescue League**: one point per campus-local day with a verified pickup. Only students who joined are listed, by nickname. `league_demo_entries` holds hackathon rivals so the board isn't empty; delete them before launch. Raw `leaderboard_events` rows are now readable only by their owner.
- Students call `get_my_rewards()`, `get_league('week' | 'all_time')`, `set_league_profile(opt_in, nickname)` and `redeem_partner_reward(reward_id)`.
- Kitchen staff scan the student's Saver Cash QR and call `scan_rewards` and `redeem_saver_cash` (idempotent per bill, can't overspend). Both default to the staff member's own location.

The same migration fixes `get_knight_pass_token` and `scan_knight_pass`: they called pgcrypto without its `extensions.` schema, so on Supabase they failed with "function gen_random_bytes(integer) does not exist" and the app fell back to a random pass token.

`seed_rewards_demo.sql` (optional, hackathon only) gives `alex@ucf.edu` six earlier verified pickups at Knightro's and joins Alex to the league as "Sir Alex", so the server-backed Rewards tab has something to show.

## Applying the migrations

Run these in the SQL Editor, in order. Each is safe to run again:

1. `migrations/202610110001_ucf_student_emails.sql`
2. `migrations/202610120001_business_bag_limit.sql`
3. `migrations/202610130001_rewards.sql`
4. Optional: `seed_rewards_demo.sql` (after both demo accounts have signed in once)

Critical writes are RPC-only:

- `reserve_listing` locks inventory so the final bag cannot be oversold.
- `cancel_reservation` restores inventory and advances one waitlist entry.
- `scan_knight_pass` limits matches to the staff member's location and pickup window.
- `verify_pickup` is idempotent and creates impact and optional leaderboard credit once.

The current hackathon reservation RPC records a simulated authorization for paid bags. Stripe manual authorization/capture belongs in an Edge Function and webhook before launch.

The native client lives in `ios/KnightSaver/KnightSaver/App/KnightSaverBackend.swift`. It deliberately uses `URLSession` instead of another package dependency and falls back to the existing local demo if the service cannot be reached.
