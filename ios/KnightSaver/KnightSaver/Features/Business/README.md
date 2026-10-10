# Business tab

SwiftUI code for the 4th navigation destination, following `business.md`. Owner: Hamza.

It is already added to `KnightSaver.xcodeproj` and shown from `RootView` with `BusinessDashboardView()`. Open the project and run. Nothing to drag in.

## What's on the page

One scrollable dashboard with **+ List surplus** pinned above the shared tab bar:

1. **Current Surprise Bags**: status, remaining/total, price, pickup interval, staff-only inventory, **Edit listing** (voice or manual), **Pause/Resume**, close/cancel, and a compact rating summary.
2. **Reserved pickups**: authorized, waitlisted and offer-sent reservations, with **Verify pickup**.
3. **Today's verified rescues**: only pickups verified with a Knight Pass scan.
4. **Impact report**: bags collected, measured weight, estimated weight, estimated CO₂e, revenue, completion rate and average rating. Estimates are labeled.

## Flows

- **+ List surplus → Speak with AI**: staff dictate with the keyboard microphone. Then:
  1. **What I understood**: an editable list of items and quantities, the pickup interval, and any missing information.
  2. **Proposed listing**: number of bags, price, interval, public description, location confirmation, and how the items are split per bag, with anything unallocated shown.
  3. Nothing goes live until staff tap **Approve and publish**.
- **+ List surplus → Enter manually**: same two screens without AI.
- **Edit listing**: voice ("Change the quantity to six bags and move pickup to 7:15–7:45 PM") shows the proposed changes for approval, or staff edit manually.
- **Scan Knight Pass**: camera QR scan of the student's reusable pass (`knightsaver://verify-user/<token>`). The result is one of:
  - **No valid pickup**.
  - One match → confirm.
  - Several matches → staff select one.
  - **Already verified**: never captured twice.

## Demo notes

- Demo data is for Knightro's Kitchen, and pickup times are relative to when the app opens.
- **Alex Knight's** reservation uses `KnightPass.sample`, so scanning the Knight Pass from Profile on a second phone verifies it.
- The Simulator has no camera. Use the **Demo scans** buttons in the scanner.
- The "…" menu on a reservation simulates student actions:
  - **Student cancels**: the payment hold is released and the waitlist gets an offer.
  - **Student accepts offer**.
  - **Mark as missed**.
- The "AI" is rule-based and runs on the phone, so it works offline. It only uses what staff said, never adds allergens or dietary claims, and always waits for staff approval.

## Files

| File | Purpose |
|---|---|
| `BusinessDashboardView.swift` | The page and its cards |
| `ListSurplusFlow.swift` | + List surplus: AI/manual, What I understood, Proposed listing |
| `EditListingFlow.swift` | Edit with voice / Edit manually |
| `PassScannerView.swift` | Knight Pass camera scanner and verification |
| `SurplusAssistant.swift` | Speech-to-inventory parsing, bag plan and allocation, voice edits |
| `BusinessStore.swift` | Data and actions (publish, edit, waitlist, scan, verify), plus demo data |
| `BusinessModels.swift` | Listing, reservation, payment, feedback, impact and event types |
| `BusinessUI.swift` | Small UI pieces styled with `KnightTheme` |

## Connecting the student side (next step)

- `BusinessStore.surpriseBagsForExplore` returns live listings as `[SurpriseBag]`. To make Explore and KnightMap update instantly:
  - Create one `BusinessStore` in `RootView`.
  - Pass it to `BusinessDashboardView(store:)`.
  - Have Explore read `surpriseBagsForExplore`.
- Status values follow business.md: `SurpriseBagStatus` and `PickupStatus`. The student side's `ReservationStatus` can move to `PickupStatus` when the two sides are merged.
- `store.events` logs the integration events from business.md ("Listing published", "Pickup verified", …).
