# KnightSaver Business Experience

## Start here: developer handoff

This file is the source of truth for the **Business** tab, shown in the app as **Kitchen**. The first part below describes what is built in the repository today and what is still missing. The rest of the document describes the target product behavior and the integration contract.

### Built so far (October 10)

All Business code lives in `ios/KnightSaver/KnightSaver/Features/Business/` (see its `README.md` for a file-by-file map). It runs on local demo data that is shared with the student side.

**Navigation and look**

- The fourth tab is labeled **Kitchen** with a custom sprout-storefront icon (`TabKitchen` / `TabKitchenFill` vector assets). The code name is still `AppTab.business`.
- Every tab starts with the KnightSaver bar: the Helm & Leaf logo left of the "KnightSaver" wordmark (`DesignSystem/KnightSaverBrand.swift`).
- The moon button in the Kitchen header switches the whole app between light and dark mode (`@AppStorage("knightsaver.darkMode")`).

**Shared data**

- One `BusinessStore` is created in `RootView` and shared with Explore, bag details and Profile. There are no parallel copies of listings or reservations.
- Published bags appear in Explore right away. A student reservation from Explore shows up in Reserved pickups, a cancellation from Profile removes it, and a verified pickup updates the student's status.

**Page sections (top to bottom)**

1. **Scan Knight Pass**: opens the camera scanner (AVFoundation, `NSCameraUsageDescription`). In the Simulator it shows demo scan buttons instead. Result states: **No valid pickup**, one match (confirm), several matches (pick one), **Pickup verified**, **Already verified**. Verification is idempotent and accepts an optional measured weight in kg. Scans outside the pickup window (15-minute grace) return **No valid pickup**; there is no override.
2. **+ List surplus**, with two paths:
   - **Speak with AI**: a large microphone button turns speech into text live (Speech framework, `NSMicrophoneUsageDescription` and `NSSpeechRecognitionUsageDescription`). Staff can also type, or tap **Use example (demo)**. Next comes **What I understood** (editable items, pickup times, price, missing or uncertain notes), then the proposed plan.
   - **Enter manually**: staff type the items, then plan the bags.
   - The plan lets staff edit the number of bags, price, pickup times and the public description, and choose the pickup spot from six campus locations.
   - **The lineup · staff only** lists each bag by a knight-themed name and shows how the items are split. A **Surprise Bag** switch keeps contents secret; turned off, the listing becomes a **Rescue Bag** whose contents students can see.
   - Nothing is published until staff tap **Approve and publish**.
   - The AI is Gemini (`SurplusAI`), with the local rule-based parser (`SurplusAssistant.swift`) as the offline fallback. Either way: one bag per 3 items, $5.99 when no price is said.
3. **Current Surprise Bags**: status chip, price, pickup window, bags left and pickup spot.
   - **Edit listing** works by voice (same microphone, proposed changes are approved first) or manually (bags available, price, times, spot, description).
   - **Pause** / **Resume**, and a ••• menu with **Close listing** and **Cancel listing**.
4. **Reserved pickups**: name and code, number of bags, **Verify pickup**. The ••• menu holds **Mark as missed** and **Student cancels (demo)**.
5. **Today's verified rescues**: one **Total** row; tapping it lists each verified pickup's price.
6. **Impact report** (updates only after a verified pickup):
   - **CO₂e avoided** card with an "Est." tag, a green bar toward a 10 kg goal and a "≈ km not driven" comparison (0.17 kg CO₂e per car-km).
   - Four tiles: **Bags collected**, **Revenue recovered**, **Pickup completion** (with a small bar) and **Average rating**.

**Demo data**: Knightro's (UCF's north campus dining hall) with two live listings, three reserved pickups (Alex Knight's matches the Profile Knight Pass) and three pickups already verified today.

### Not built yet

- **This week / This month** switch for the impact report, and **Export PDF**.
- The overall rating as a number in the header. Average rating is currently a tile in the Impact report.
- **Outside pickup window** override in the scanner.
- A real AI service, payments, a backend and authentication. The business-role gate is off for the prototype, so every account sees Kitchen.

### Business-side ownership

The business-side developer owns:

- The content rendered when `AppTab.business` (Kitchen) is selected.
- Listing creation and editing UI.
- Current-listing controls such as pause, resume, and close.
- A minimal reserved-pickup list used to start verification.
- The Knight Pass scan/verification experience.
- A small today's-rescues summary.
- A selectable weekly or monthly impact report with PDF export.
- One overall restaurant rating displayed near the top of the page.
- Business-specific demo state and components.

The student-side developer continues to own Explore, Impact, Profile, the shared tab bar, and student reservation management. Do not duplicate cancellation controls on the Business page. A student cancellation disappears from the business pickup queue because both sides read the same reservation state.

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

### State transition rules

- Publishing changes a reviewed draft to **Available** and makes it visible in Explore.
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
7. **Outside pickup window** — warn staff and require an explicit demo override if supported (not built yet; such scans currently return **No valid pickup**)

The reusable Knight Pass identifies the student; the app then finds reservations valid for the current business and pickup window. Do not place a raw student ID, payment data, or complete reservation details inside the QR payload.

### Definition of done

The Business MVP is done when all of these can be demonstrated without restarting the app:

- [x] A staff user creates a reviewed Surprise Bag draft and publishes it.
- [x] The published listing appears in the shared local listing state.
- [x] An active student reservation appears in Reserved pickups.
- [x] Cancelling that reservation from Profile removes it from Reserved pickups and restores availability.
- [x] Staff can verify a valid pickup once.
- [x] A second verification attempt does not duplicate the rescue or impact.
- [x] The verified pickup leaves the active queue and updates the small today's-rescues summary.
- [x] Business metrics update from the verified record.
- [ ] Staff can switch the impact report between this week and this month.
- [ ] Staff can export the selected report as a PDF containing clear metrics and optional charts.
- [x] Pause/resume and edit actions change the same listing used by the student experience.
- [ ] The page works with Dynamic Type, VoiceOver labels, reduced motion, safe areas, and the shared bottom navigation. (Reduced motion, VoiceOver labels and safe areas are in place; Dynamic Type still needs a pass.)
- [ ] The project builds successfully for an iOS Simulator. (To be confirmed in Xcode after each merge.)

## Business-side purpose

The Business section lets authorized staff turn uncertain surplus into live pickup-only Surprise Bags, manage listings, verify collection, and produce credible impact records.

The business-side developer owns the content inside the **Kitchen** destination. The student-side developer owns the shared navigation shell and the student destinations.

For the hackathon, Business may remain visible as a clearly labeled demo view. In a real deployment, it must require an authorized staff or manager account.

## Position inside the shared app

Student accounts see **Explore**, **Impact** and **Profile**. Business accounts see:

1. **Kitchen** (the Business destination)
2. **Profile**

Kitchen is the business account's first destination. Do not create a second business navigation bar or a separate business app.

The Business page is one focused, scrollable dashboard. Keep **+ List surplus** immediately above the shared bottom navigation while Business is selected.

## Shared product rules

- KnightSaver is pickup only.
- Listings are **Surprise Bags** with unknown exact contents.
- Businesses set the price, available quantity, pickup location, and exact pickup interval.
- Student Explore uses restaurant logos or branded banners, not promised food photography.
- Explore remains discovery-focused; the student's reusable Knight Pass lives in Profile.
- Do not require an exact food name or category.
- Do not promise ingredients, allergens, dietary suitability, freshness, or specific contents.
- Do not provide original-price or student-savings fields for Explore.
- Business updates must immediately update the student feed.

## Business data required by Explore

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
- Latitude and longitude (used for distance in Explore)
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

Staff tap the microphone and describe the actual surplus inventory they have and any known pickup constraints; the words appear as they speak and can be corrected by typing. They do not need to decide the number of Surprise Bags first.

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
- Pickup spot, chosen from the campus locations
- Whether it is a **Surprise Bag** (contents secret) or a **Rescue Bag** (contents shown to students)

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

## Essential business flow

1. Staff taps **+ List surplus**.
2. Staff chooses voice AI or manual entry.
3. Staff describes or enters the actual surplus inventory.
4. AI shows what it understood.
5. Staff corrects or confirms the interpreted inventory.
6. AI proposes the number of Surprise Bags and related listing details.
7. Staff edits, approves, and publishes the plan.
8. The listing appears in Explore.
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

The student demo then shows reservation, EcoKnight AI, Past Surprise Reveals, verified impact, and the Campus Rescue League.

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
