# KnightSaver Business Experience

## Business-side purpose

The Business section lets authorized staff turn uncertain surplus into live pickup-only Surprise Bags, manage expected pickups, verify collection, and produce credible impact records.

The business-side developer owns the content inside the fourth **Business** navigation destination. The student-side developer owns the shared navigation shell and the other four destinations.

For the hackathon, Business may remain visible as a clearly labeled demo view. In a real deployment, it must require an authorized staff or manager account.

## Position inside the shared app

KnightSaver uses five bottom-navigation destinations:

1. **Explore**
2. **Rescues**
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

The hackathon dashboard contains four primary sections.

### 1. Current Surprise Bags

Show every active or recently changed listing with:

- Surprise Bag label
- Remaining and total quantity
- Price
- Pickup interval
- Available, fully reserved, paused, closed, or cancelled status
- **Edit listing**
- **Pause** or **Resume**
- Optional rating and feedback summary

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

Show upcoming student pickups:

- Student display name or reservation identifier
- Surprise Bag quantity
- Pickup interval
- Reservation status
- Authorized payment status
- Waitlist status when relevant
- **Verify pickup**

If a student cancels:

- Release the payment authorization according to the payment policy.
- Increase availability or offer the bag to the next waitlisted student.
- Update Explore and KnightMap immediately.
- Do not create impact or leaderboard credit.

### 3. Today's verified rescues

Show completed pickups from today:

- Student display name or reservation identifier
- Surprise Bag quantity
- Verified pickup time
- Payment-captured status
- Verified rescue status

A reservation appears here only after staff verifies the student's single-use QR pickup pass.

QR verification triggers:

1. Reservation becomes **Pickup verified**.
2. Payment capture begins.
3. The rescue enters today's verified rescues.
4. Verified student and campus impact update.
5. Campus Rescue League receives the eligible point.
6. EcoKnight AI becomes available for that rescue.
7. The student becomes eligible to submit a rating, comment, and Past Surprise Reveal.

The verification action must be protected against accidental double scanning.

### 4. Business impact report

Show concise proof for judges:

- Verified Surprise Bags collected
- Measured food weight
- Estimated food weight, separately labeled
- Estimated environmental impact
- Revenue recovered
- Pickup completion rate
- Average verified rating

Impact updates only after verified pickup. Never present estimated weight or carbon impact as measured data.

The Campus Rescue League and Knight of the Week are student-facing features. The business dashboard does not need to manage the competition. A sponsoring business may be represented by demo configuration outside the dashboard.

## Student feedback and Past Surprise Reveals

Only verified pickups can create feedback.

The business side needs read access to:

- Overall rating
- Portion rating
- Surprise-quality rating
- Pickup-experience rating
- Written comment
- Optional Past Reveal photo
- **Would you reserve again?**

For the hackathon, a compact rating summary and recent comments may appear inside Current Surprise Bags or the business profile. A separate feedback page is not required.

Past Reveal photos show historical student experiences and never guarantee the next bag's contents.

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
9. A student authorizes payment and reserves.
10. The reservation appears in Reserved pickups.
11. Cancellation releases the authorization and triggers the waitlist when relevant.
12. Staff verifies the final student's QR pickup pass.
13. Payment is captured.
14. The pickup moves into Today's verified rescues.
15. Verified impact and leaderboard state update.
16. EcoKnight AI and Past Reveal submission unlock for the student.

## Two-to-three-minute demo responsibility

The business-side portion of the demo should take approximately 20–35 seconds:

1. Open Business.
2. Tap **+ List surplus**.
3. Describe the actual surplus, for example: “We have 12 bagels, 6 pastries, and 4 sandwiches left. Pickup can be from 7:00 to 7:30.”
4. Show the **What I understood** inventory summary.
5. Show AI's proposed number of Surprise Bags and listing details.
6. Correct the draft if needed, then tap **Approve and publish**.
7. Later, scan or verify the student's QR pickup pass.
8. Show the listing move into Today's verified rescues.

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

## Features intentionally excluded from the hackathon business page

Do not prioritize:

- Multiple business locations
- Detailed historical analytics
- Complex charts
- Staff scheduling
- Customer messaging
- Full accounting or payout reconciliation
- Advanced AI forecasting
- Business management of the weekly competition
- Separate pages for listings, reservations, reports, or feedback

The goal is a reliable live loop between business publishing, student reservation, QR verification, and verified impact.
