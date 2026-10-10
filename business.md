# KnightSaver Business Experience

## Start here: developer handoff

This file is the source of truth for the **Business** tab. The sections immediately below describe what is in the repository now, what the business-side developer owns, and the smallest complete hackathon implementation. The rest of the document describes the target product behavior and integration contract.

### Current repository state

- The native SwiftUI app lives in `ios/KnightSaver/KnightSaver/` and targets iOS 17 or later.
- `App/RootView.swift` already contains the shared five-item navigation: Explore, Map, Impact, Business, and Profile.
- The Business destination is currently only a placeholder. Replace that placeholder; do not create a separate app, navigation bar, or role-selection flow.
- Explore and Profile are already implemented. Profile contains the reusable Knight Pass and the student's reservation-management flow, including cancellation.
- Demo data is local. There is no production backend, authentication, Apple Pay capture, AI service, or staff scanner yet.
- `Models/Models.swift` currently defines `SurpriseBag`, `ActiveReservation`, `ReservationStatus`, and `KnightPass`.
- `RootView` currently owns `activeReservations`, so it is the temporary shared source of truth between the student and business experiences.
- Explore currently reads `SurpriseBag.samples` directly. Publishing from Business will not update Explore until the shared listing array is lifted into `RootView` and passed into both views. Coordinate that small interface change with the student-side developer instead of maintaining a second list.
- The current Knight Pass QR payload identifies the signed-in user with a renewable demo token. Continue using QR for the hackathon. A phone can read traditional barcodes, but changing KnightSaver to a student-ID barcode is not part of the agreed product flow and would need a separate security decision.

### Business-side ownership

The business-side developer owns:

- The content rendered when `AppTab.business` is selected.
- Listing creation and editing UI.
- Current-listing controls such as pause, resume, and close.
- A minimal reserved-pickup list used to start verification.
- The Knight Pass scan/verification experience.
- A small today's-rescues summary.
- A selectable weekly or monthly impact report with PDF export.
- One overall restaurant rating displayed near the top of the page.
- Business-specific demo state and components.

The student-side developer continues to own Explore, KnightMap, Impact, Profile, the shared tab bar, and student reservation management. Do not duplicate cancellation controls on the Business page. A student cancellation should disappear from the business pickup queue because both sides read the same reservation state.

### Visible feature set

Only these features need visible space on the one-page Business experience:

1. Create a Surprise Bag manually.
2. Create a Surprise Bag with the AI assistant and approve its draft.
3. Manage current bags: edit, pause, resume, close, or cancel.
4. See a minimal reserved-pickup list containing only the student/reservation identifier, bag quantity, and verification action.
5. Scan the reusable Knight Pass QR code and verify the correct pickup.
6. See a small summary of today's verified rescues.
7. Select a weekly or monthly impact report and export it as a PDF with optional visualizations.
8. See the restaurant's overall verified rating as one number near the top.

Do not add visible payment management, synchronization status, individual feedback, arrival estimates, interactive charts, or detailed reservation metadata. Those are background concerns or outside the Business MVP.

### Files to create or touch

Prefer this structure:

```text
ios/KnightSaver/KnightSaver/
├── App/RootView.swift
├── Models/Models.swift
└── Features/Business/
    ├── BusinessView.swift
    └── BusinessComponents.swift        # optional when BusinessView becomes large
```

- Create `Features/Business/BusinessView.swift` for the page and its sheets.
- Add `BusinessComponents.swift` only when it improves readability; a one-file MVP is acceptable.
- Make the smallest necessary shared changes in `Models/Models.swift` and `App/RootView.swift`.
- Add new Swift files to the Xcode target if the project does not pick them up automatically.
- Avoid editing files under `Features/Explore/` or `Features/Profile/` unless both developers agree on the integration change.

The intended root wiring is conceptually:

```swift
BusinessView(
    listings: $listings,
    reservations: $activeReservations,
    verifiedRescues: $verifiedRescues
)
```

`RootView` should temporarily own these arrays so publishing, cancellation, verification, Explore availability, and Business totals can all react to the same local state. When a backend is added, replace these bindings with a shared observable store rather than preserving separate copies.

For a low-conflict first pass, the business developer can build `BusinessView` against preview/demo bindings. Before merging the end-to-end demo, the team must move `SurpriseBag.samples` into `RootView`, pass the same listings into Explore and Business, and resolve edits to `RootView.swift` together.

### Hackathon MVP: build this first

The minimum complete Business experience is one scrollable page with a compact business header, four sections, and one persistent action. The header shows the business name and one overall rating number; it does not open a detailed feedback feed.

1. **Current Surprise Bags**
   - Show at least one demo listing.
   - Show remaining/total quantity, price, pickup interval, and status.
   - Support edit and pause/resume.
2. **Reserved pickups**
   - Read from the shared active reservations.
   - Show only the student display name or reservation identifier, Surprise Bag quantity, and **Verify pickup**.
   - Do not show expected-arrival language, pickup time, reservation status, payment status, or waitlist details on this page.
3. **Today's rescue summary**
   - Keep this visually small and show only a few totals, such as verified pickups and bags rescued today.
   - Do not render a long list of completed reservations.
   - Repeated verification must not add a second rescue or impact record.
4. **Business impact report**
   - Let staff choose **This week** or **This month**.
   - Show a concise text-and-number summary on the page, without charts.
   - Provide **Export PDF**. The exported report may contain charts or other visualizations because those do not consume dashboard space.
   - Derive verified bag count, food weight, estimated environmental impact, revenue recovered, and pickup completion from verified rescues.
   - Label weight and environmental values as estimates unless measured input exists.
5. **+ List surplus**
   - Keep it immediately above the shared bottom navigation while Business is selected.
   - Open **Speak with AI** and **Enter manually**.
   - Require review before publishing.

For the hackathon, camera scanning and AI generation may use honest local demo behavior:

- **Scanner:** Provide a simulated scan/manual reservation selection in Simulator. If a real camera scanner is added, keep the same verification result states.
- **AI:** Use a deterministic sample or local parser to show the two review stages. Clearly label it as a draft and never publish automatically.

Any payment processing and student-facing synchronization happen in the background. Do not add payment controls, payment status, or a “shared live data” card to the Business page.

### Shared model changes needed for the MVP

Do not build parallel business-only copies of student data. Extend the shared models so both sides can observe the same records.

| Object | MVP fields or changes |
|---|---|
| `SurpriseBag` | Stable `id`; business ID/name; address/location; total quantity; remaining quantity; price; pickup start/end; description; `ListingStatus`; created/updated time. Coordinates can be added now or when KnightMap is connected. |
| `ActiveReservation` | Stable ID; student display name or demo identifier; bag/listing ID; quantity; reservation status; created time. Payment state may remain in the shared background model but is not shown on the Business page. |
| `VerifiedRescue` | Reservation ID; listing ID; quantity; verified time; captured amount; optional measured weight; optional estimated weight. |
| `ListingStatus` | `draft`, `available`, `fullyReserved`, `paused`, `closed`, `cancelled`. |
| `ReservationStatus` | Expand beyond the current demo cases so it can represent authorized, waitlisted, offer sent, cancelled, pickup verified, payment captured, refunded, and missed. |

During the local prototype, values may remain in memory. Preserve stable IDs across edits so verification and cancellation affect the correct record.

### State transition rules

- Publishing changes a reviewed draft to **Available** and makes it visible to Explore and KnightMap.
- Reserving reduces remaining quantity once and creates one authorized reservation.
- Student cancellation removes the reservation from the pickup queue, releases its demo authorization, and restores one unit or advances the waitlist.
- Pausing keeps the listing visible to staff but prevents new student reservations.
- Fully reserved means remaining quantity is zero; it may still accept waitlist entries.
- Verifying a pickup changes the reservation to **Pickup verified**, creates one verified rescue, and updates impact. Any payment processing happens in the background.
- Verification is idempotent: if that reservation was already verified, show **Already verified** and make no further changes.
- Closing or cancelling a listing disables new reservations and immediately updates the student-facing state.

### Verification result states

Whether the demo uses a camera, manual code entry, or a reservation picker, the staff flow must visibly handle:

1. **Ready to scan**
2. **No valid pickup**
3. **One matching reservation** — show it and require staff confirmation
4. **Multiple matching reservations** — require staff to select the exact pickup
5. **Pickup verified**
6. **Already verified**
7. **Outside pickup window** — warn staff and require an explicit demo override if supported

The reusable Knight Pass identifies the student; the app then finds reservations valid for the current business and pickup window. Do not place a raw student ID, payment data, or complete reservation details inside the QR payload.

### Demo data and scope

- Reuse the current sample businesses and reservations in `Models/Models.swift` so the Business tab matches what Explore and Profile show.
- Use one selected demo business for the Business page; do not build multi-location management.
- The earlier UCF dining-location research can later seed onboarding, but the Business MVP does not need the full campus directory.
- Keep Surprise Bag contents general in student-facing text. Internal surplus items may be detailed only inside the staff review flow.

### Definition of done

The Business MVP is done when all of these can be demonstrated without restarting the app:

- A staff user creates a reviewed Surprise Bag draft and publishes it.
- The published listing appears in the shared local listing state.
- An active student reservation appears in Reserved pickups.
- Cancelling that reservation from Profile removes it from Reserved pickups and restores availability.
- Staff can verify a valid pickup once.
- A second verification attempt does not duplicate the rescue or impact.
- The verified pickup leaves the active queue and updates the small today's-rescues summary.
- Business metrics update from the verified record.
- Staff can switch the impact report between this week and this month.
- Staff can export the selected report as a PDF containing clear metrics and optional charts.
- Pause/resume and edit actions change the same listing used by the student experience.
- The page works with Dynamic Type, VoiceOver labels, reduced motion, safe areas, and the shared bottom navigation.
- The project builds successfully for an iOS Simulator.

## Business-side purpose

The Business section lets authorized staff turn uncertain surplus into live pickup-only Surprise Bags, manage listings, verify collection, and produce credible impact records.

The business-side developer owns the content inside the fourth **Business** navigation destination. The student-side developer owns the shared navigation shell and the other four destinations.

For the hackathon, Business may remain visible as a clearly labeled demo view. In a real deployment, it must require an authorized staff or manager account.

## Position inside the shared app

KnightSaver uses five bottom-navigation destinations:

1. **Explore**
2. **Map** (opens **KnightMap**)
3. **Impact**
4. **Business**
5. **Profile**

Business remains the fourth destination. Do not create a second business navigation bar or a separate business app.

The Business page is one focused, scrollable dashboard. Keep **+ List surplus** immediately above the shared bottom navigation while Business is selected.

## Shared product rules

- KnightSaver is pickup only.
- Listings are **Surprise Bags** with unknown exact contents.
- Businesses set the price, available quantity, pickup location, and exact pickup interval.
- Student Explore uses restaurant logos or branded banners, not promised food photography.
- Explore remains discovery-focused; the student's reusable Knight Pass lives in Profile.
- KnightMap is a dedicated second navigation destination rather than a toggle inside Explore.
- Do not require an exact food name or category.
- Do not promise ingredients, allergens, dietary suitability, freshness, or specific contents.
- Do not provide original-price or student-savings fields for Explore.
- Business updates must immediately update the student feed and KnightMap.

## Business data required by Explore and KnightMap

Each published Surprise Bag needs:

- Business identifier
- Business name
- Restaurant logo or branded banner
- Business rating, derived from verified student feedback
- **Surprise Bag** listing label
- Current price
- Total and remaining bag quantity
- Pickup start time
- Pickup end time
- Pickup address
- Latitude and longitude for KnightMap
- Optional general description that does not guarantee exact contents
- Listing status
- Created and updated timestamps

The business profile may provide the logo, address, and map coordinates so staff do not need to re-enter them for every listing.

Recommended listing statuses:

- **Draft**
- **Available**
- **Fully reserved**
- **Paused**
- **Closed**
- **Cancelled**

Recommended reservation statuses:

- **Authorized**
- **Waitlisted**
- **Offer sent**
- **Cancelled**
- **Pickup verified**
- **Payment captured**
- **Refunded**
- **Missed**

Both developers must use the same status values.

## Main business action

### + List surplus

Tapping **+ List surplus** gives staff two choices:

- **Speak with AI**
- **Enter manually**

### Speak with AI

Staff describe the actual surplus inventory they have and any known pickup constraints. They do not need to decide the number of Surprise Bags first.

Example:

> “We have 12 bagels, 6 pastries, and 4 sandwiches left. Pickup can be from 7:00 to 7:30 PM.”

AI processes the input in two visible stages.

#### Stage 1: What AI understood

Before proposing a listing, show the staff a structured summary:

- Surplus items AI heard
- Quantity of each item
- Pickup start and end time
- Any price or other constraint mentioned
- Any missing or uncertain information

Example:

> **What I understood**  
> 12 bagels  
> 6 pastries  
> 4 sandwiches  
> Pickup 7:00–7:30 PM

Staff can correct the interpreted inventory before continuing.

#### Stage 2: Proposed Surprise Bag plan

Using only the confirmed staff input and approved business rules, AI proposes:

- Number of Surprise Bags to publish
- Suggested distribution of the entered surplus across those bags
- Proposed price
- Pickup interval
- Public-facing general description
- Default pickup location
- Total inventory accounted for and any items not allocated

Example:

> **Proposed listing**  
> 7 Surprise Bags  
> $5.99 each  
> Pickup 7:00–7:30 PM  
> Public description: “A mix of today's surplus items.”

Staff can edit every field. Nothing is published until staff taps **Approve and publish**.

The internal inventory summary helps staff review the proposal. Students still see a Surprise Bag and do not receive a guarantee of exact contents.

AI must not:

- Publish without staff confirmation
- Add inventory that staff did not report
- Allocate more items than staff confirmed
- Hide unallocated inventory from the review
- Invent allergens or dietary claims
- Approve food safety
- Change the business location without confirmation

### Enter manually

The manual fallback first records the actual surplus inventory and then lets staff define:

- Surplus item names and quantities for internal planning
- Number of Surprise Bags
- Price
- Pickup start time
- Pickup end time
- Optional public general description
- Location confirmation

The restaurant logo comes from the business profile unless staff explicitly replaces it.

## Simplified business dashboard

The hackathon dashboard is one focused page. At the top, show the business name and its overall verified rating as one number, for example **4.7**. Do not place individual reviews, rating breakdowns, or comments on the page.

Below the header, show four primary sections.

### 1. Current Surprise Bags

Show every active or recently changed listing with:

- Surprise Bag label
- Remaining and total quantity
- Price
- Pickup interval
- Available, fully reserved, paused, closed, or cancelled status
- **Edit listing**
- **Pause** or **Resume**

Staff may edit through:

- **Edit with voice**
- **Edit manually**

Example voice edit:

> “Change the quantity to six bags and move pickup to 7:15–7:45 PM.”

AI presents proposed changes. Staff approve them before live data changes.

Publishing or editing a listing must update:

- Explore feed
- KnightMap marker
- Available quantity
- Pickup interval
- Student detail view

### 2. Reserved pickups

Keep this section minimal. For each active reservation, show only:

- Student display name or reservation identifier
- Surprise Bag quantity
- **Verify pickup**

Do not show expected-arrival labels, courtesy or arrival estimates, pickup time, reservation status, payment authorization, or waitlist details. Those are either student-facing or background concerns.

If a student cancels, remove the reservation from this section automatically and restore the appropriate availability in the shared data. Do not add cancellation-management controls to the Business page.

### 3. Today's rescue summary

Use a compact summary rather than a detailed completed-pickup list. Show only a few totals, such as:

- Verified pickups today
- Surprise Bags rescued today
- Optional estimated food weight rescued today

The totals update only after staff scans the student's reusable Knight Pass and verifies a matching pickup.

The scanner checks valid reservations for the current business and pickup window. No match returns **No valid pickup**. One match can be verified directly. Multiple matches require staff to select the exact reservation. Verification must be idempotent so repeated scans cannot create a second rescue or award impact twice.

QR verification triggers the following background updates:

1. Reservation becomes **Pickup verified**.
2. Today's rescue totals update.
3. The selected weekly or monthly impact record updates.
4. Any payment processing happens without adding payment controls or status to this page.
5. Verified student and campus impact update.
6. Campus Rescue League receives the eligible point.
7. EcoKnight AI and verified feedback become available to the student.

The verification action must be protected against accidental double scanning.

### 4. Business impact report

Let staff select one reporting interval:

- **This week**
- **This month**

Show concise totals for the selected interval:

- Verified Surprise Bags collected
- Measured food weight
- Estimated food weight, separately labeled
- Estimated environmental impact
- Revenue recovered
- Pickup completion rate

Impact updates only after verified pickup. Never present estimated weight or carbon impact as measured data.

Keep the in-app report free of charts so the one-page dashboard remains compact. Provide **Export PDF** for the selected interval. The PDF may include:

- Business name and reporting period
- The same verified totals shown in the app
- Simple charts or visual summaries
- A generated date
- Clear labels distinguishing measured and estimated values

PDF export must not include student names, Knight Pass tokens, payment credentials, or other private identifiers.

The Campus Rescue League and Knight of the Week are student-facing features. The business dashboard does not need to manage the competition. A sponsoring business may be represented by demo configuration outside the dashboard.

## Restaurant rating

Show only the restaurant's overall verified rating as one compact number near the top of the Business page. Do not show individual reviews, written comments, Past Reveal photos, rating categories, or a detailed feedback section on this page.

Only verified pickups may contribute to the overall rating. Detailed feedback may remain in the shared data for future use, but it is outside the one-page Business MVP.

## Business relationship to KnightMap

KnightMap is owned by the student-side developer, but Business supplies the live data.

Business must ensure that each listing has:

- A valid pickup address
- Valid map coordinates
- An exact pickup start and end time
- Current remaining quantity
- Current status

If a listing is paused, closed, cancelled, or fully reserved, the map marker and student actions must update immediately.

The business side does not need to build routing or directions.

## Essential business flow

1. Staff taps **+ List surplus**.
2. Staff chooses voice AI or manual entry.
3. Staff describes or enters the actual surplus inventory.
4. AI shows what it understood.
5. Staff corrects or confirms the interpreted inventory.
6. AI proposes the number of Surprise Bags and related listing details.
7. Staff edits, approves, and publishes the plan.
8. The listing appears in Explore and KnightMap.
9. A student reserves a Surprise Bag.
10. The reservation appears in Reserved pickups.
11. A cancellation disappears from Reserved pickups and updates availability in the background.
12. Staff scans the student's Knight Pass and verifies the matching reservation.
13. Today's rescue summary updates.
14. The weekly or monthly business impact report updates.
15. Background payment, student impact, and leaderboard state update as required.
16. EcoKnight AI and verified feedback unlock for the student.

## Two-to-three-minute demo responsibility

The business-side portion of the demo should take approximately 20–35 seconds:

1. Open Business.
2. Tap **+ List surplus**.
3. Describe the actual surplus, for example: “We have 12 bagels, 6 pastries, and 4 sandwiches left. Pickup can be from 7:00 to 7:30.”
4. Show the **What I understood** inventory summary.
5. Show AI's proposed number of Surprise Bags and listing details.
6. Correct the draft if needed, then tap **Approve and publish**.
7. Later, scan the student's Knight Pass and verify the matching reservation.
8. Show today's rescue total increase.
9. Switch the report between **This week** and **This month**, then show **Export PDF**.

The student demo then shows KnightMap, reservation, EcoKnight AI, Past Surprise Reveals, verified impact, and the Campus Rescue League.

## Shared integration contract

The two developers must agree on these shared objects:

- Business
- Staff surplus inventory input
- AI interpretation and proposed bag plan
- Surprise Bag listing
- Reservation
- Waitlist entry
- Payment state
- Pickup verification
- Review
- Past Surprise Reveal
- Impact record
- Leaderboard event

The most important integration events are:

- **Surplus inventory confirmed**
- **AI bag plan approved**
- **Listing published**
- **Listing updated**
- **Reservation created**
- **Reservation cancelled**
- **Waitlist offer created**
- **Pickup verified**
- **Payment captured**
- **Impact recorded**
- **Leaderboard credited**
- **Feedback submitted**

Payment capture, student-side synchronization, leaderboard updates, and feedback processing remain background integration events. They must not become visible cards or controls on the Business dashboard.

## Features intentionally excluded from the hackathon business page

Do not prioritize:

- Multiple business locations
- Detailed historical analytics beyond the weekly and monthly summaries
- Interactive charts on the Business page; charts are allowed in the exported PDF
- Staff scheduling
- Customer messaging
- Full accounting or payout reconciliation
- Advanced AI forecasting
- Business management of the weekly competition
- Detailed feedback feeds or individual reviews
- Separate pages for listings, reservations, or feedback

The goal is a compact one-page loop between AI/manual publishing, listing management, minimal pickup verification, today's rescue summary, and exportable weekly or monthly impact.
