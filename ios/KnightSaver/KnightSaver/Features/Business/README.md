# Business tab

SwiftUI code for the 4th navigation destination, following `business.md`. Owner: Hamza.

It is already added to `KnightSaver.xcodeproj` and shown from `RootView` with `BusinessDashboardView()`. Open the project and run. Nothing to drag in.

## What's on the page

One scrollable dashboard:

- **Header**: "Restaurant", the **Scan Knight Pass** button (styled like the Knight Pass card), and a full-width gold **List surplus** button under it.
- **Current Surprise Bags**: status, bags left, price and pickup interval, with **Edit listing** (voice or manual), **Pause/Resume** and close/cancel. The AI bag split is still saved on each listing (`bagSplit`, `staffPackingLines`) but isn't shown on the card.
- **Reserved pickups**: authorized, waitlisted and offer-sent reservations, with **Verify pickup**.
- **Today's verified rescues**: one "Total" row. Tap it to see each verified pickup's price.
- **Impact report**: bags collected (full width), then revenue, estimated CO₂e (tagged Est.), pickup completion and average rating in a 2×2 grid.

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

- Demo data is for Knightro's Kitchen (students see that name; the dashboard header says "Restaurant"). Pickup times are relative to when the app opens.
- Reserved pickups starts with two students: Alex Knight (KS-4821) and Jordan P.
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

## Shared with the student side

`RootView` owns one `BusinessStore` (`@StateObject`). It is passed to `BusinessDashboardView(store:)` and put in the environment for Explore and Profile. The data survives tab switches.

- **Explore** shows `store.surpriseBagsForExplore` first, then the sample restaurants (the sample for this business is hidden to avoid a duplicate). Publishing, editing, pausing, closing, cancelling or selling out updates the card and the open bag details right away. Each bag's `id` is its listing id.
- **Reserve / Join waitlist** on a live bag calls `store.reserve(bagID:studentName:passToken:)`. It lowers the bags left, appears in Business › Reserved pickups, and shows in Profile › My pickups.
- **Cancel** in Profile calls `store.cancelReservation(id:)`. That releases the payment hold and frees the bag or offers it to the waitlist.
- **Verify pickup** in Business changes the student's reservation in Profile to "Pickup verified" and hides the cancel button.
- **KnightMap** (still a placeholder) must read `store.mapPins`: each pin has a bag plus latitude and longitude.
- The student is `KnightPass.sample` until authentication exists.
- `store.events` logs the integration events from business.md ("Listing published", "Pickup verified", …).
