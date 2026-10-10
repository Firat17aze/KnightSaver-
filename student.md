# KnightSaver Student Experience

## Product definition

KnightSaver is a campus-focused, pickup-only Surprise Bag platform. Students reserve surplus food without knowing its exact contents in advance. Businesses determine the number of bags, price, pickup location, and exact pickup interval.

KnightSaver is not a delivery app, menu browser, or savings marketplace. Its student experience is built around five differentiators:

1. **EcoKnight AI** — Helps students use what they receive and understand their estimated environmental impact.
2. **KnightMap** — Shows live Surprise Bags around campus and helps students reach pickup locations.
3. **Campus Rescue League** — Turns verified campus food rescue into a weekly community challenge.
4. **Past Surprise Reveals** — Shows optional photos, ratings, and comments from previous verified pickups.
5. **Verified Impact Chain** — Updates impact and leaderboard results only after staff verifies pickup.

The product promise is:

> Discover a Surprise Bag, pick it up, use the food, share the experience, and grow the campus impact.

## One app with five bottom-navigation sections

KnightSaver is one shared app with five bottom-navigation destinations:

| Position | Label | Purpose |
|---|---|---|
| 1 | **Explore** | Browse live Surprise Bags in a feed or on KnightMap |
| 2 | **Rescues** | Manage reservations, waitlists, payments, directions, and QR pickup passes |
| 3 | **Impact** | Open EcoKnight AI, view verified impact, and join the Campus Rescue League |
| 4 | **Business** | Open the authorized business dashboard and AI listing tools |
| 5 | **Profile** | Manage account, location, leaderboard privacy, notifications, and support |

The student-side developer owns **Explore**, **Rescues**, **Impact**, **Profile**, and the shared navigation shell. The business-side developer owns the content inside **Business**.

For the hackathon, Business may remain visible as a clearly labeled demo view. In a real deployment, Business must be visible only to an authorized staff or manager account.

KnightMap, EcoKnight AI, Past Surprise Reveals, and the leaderboard are not additional navigation destinations:

- KnightMap is a feed/map toggle inside Explore.
- EcoKnight AI is opened from a verified rescue and from Impact.
- Past Surprise Reveals appear in Surprise Bag details.
- Campus Rescue League and Knight of the Week live inside Impact.

## Bottom-navigation visual direction

Use a floating white rounded capsule slightly above the bottom safe area.

- Keep five equal-width destinations in one row.
- Use an icon above each short visible label.
- Keep labels visible for active and inactive destinations.
- Give the active destination a soft KnightSaver gold or approved accent background.
- Use outline icons and neutral labels for inactive destinations.
- Keep the active state understandable without color or animation alone.
- Preserve comfortable touch targets and visible keyboard or accessibility focus.
- Do not allow page content or contextual actions to sit behind the navigation.
- Place the Business **+ List surplus** action immediately above the navigation while Business is selected.
- Place student reservation actions immediately above the navigation when needed.

This is structurally inspired by Rakuten-style floating navigation but uses KnightSaver's own identity.

## Contextual student actions

Show only the action that matches the student's current state:

- **Reserve with Apple Pay**
- **Reserve for free**
- **Join waitlist**
- **Accept waitlist offer**
- **View pickup pass**
- **Open EcoKnight AI** after verified pickup

These actions are not navigation destinations.

## Explore

### Primary job

Explore helps a student find an available Surprise Bag they can realistically reach during the business-defined pickup interval.

The visual hierarchy may be inspired by the scanning speed of Uber Eats, but KnightSaver must not copy its branding, delivery features, menu structure, or restaurant-category system.

### Product rules

- Pickup only; never show delivery language.
- Exact contents remain unknown before pickup.
- Use restaurant logos or branded banners as the primary imagery.
- Do not use food-category shortcuts because the contents are uncertain.
- Do not show exact food names, original prices, savings amounts, trust badges, or **Ends today** labels.
- Do not promise dietary suitability, ingredients, allergens, freshness, or specific contents.
- Show the current Surprise Bag price without framing it as money saved.

### 1. Campus pickup context

The top of Explore shows:

- **Pickup near UCF Main Campus**
- The detected campus area or selected pickup zone
- Location-permission status
- A control for changing the pickup area
- Pickup-only language

If location permission is unavailable, allow the student to choose a campus area manually.

### 2. Search and filters

Search is limited to current businesses and published Surprise Bags:

> **Search businesses or Surprise Bags**

Do not search for exact foods that the business cannot guarantee.

Useful filters are:

- Distance
- Pickup time
- Rating
- Available now

Useful sorting options are:

- Recommended
- Nearest
- Pickup time
- Highest rated

There is no food-category row.

### 3. Feed and KnightMap toggle

Explore has two views of the same live data:

- **Feed** — Scannable Surprise Bag cards
- **Map** — KnightMap with live campus locations

Changing the view must preserve the active search and filters.

### 4. Surprise Bag cards

Each feed card shows:

- Restaurant logo or branded banner
- Restaurant rating overlaid on the banner
- Restaurant name
- **Surprise Bag** label
- Distance from the student's detected or selected location
- Exact pickup interval, such as **7:00–7:30 PM**
- Number of bags available
- Current price
- Optional short business-provided description
- **View Surprise Bag** or **Reserve** action
- Optional feedback count or short Past Reveals preview

Example content hierarchy:

> **Knightro's Kitchen** — 4.7  
> Surprise Bag  
> 0.4 mi  
> Pickup 7:00–7:30 PM  
> 3 bags available · $5.99

Cards do not show food photography, exact contents, original prices, savings, delivery estimates, trust signals, category labels, **Closing soon**, or **Ends today**.

### 5. KnightMap

KnightMap displays live participating businesses around campus.

Each marker or selected-marker sheet shows:

- Restaurant logo
- Restaurant name and rating
- Available Surprise Bag quantity
- Pickup interval
- Distance
- Current availability
- **View bag**
- **Get directions**

Directions may open the device's preferred mapping application. When reliable walking-route data is available, KnightMap may also show:

- Walking-route duration
- A calculated **Leave by** time
- Whether the pickup is reachable before the interval ends

These calculations use only the current time, location, walking route, and pickup interval. KnightSaver does not pretend to know a student's class schedule.

### 6. Surprise Bag details

Opening a card or map marker shows:

- Restaurant logo or banner
- Restaurant name and rating
- Surprise Bag price
- Available quantity
- Exact pickup interval
- Pickup address
- Distance and directions
- General business-provided description
- Reservation and cancellation explanation
- Past Surprise Reveals
- Ratings and comments

Always include this expectation:

> Surprise Bag contents change with the business's available surplus. Past Reveals show previous student experiences and do not guarantee future contents.

The contextual action is:

- **Reserve with Apple Pay** when available
- **Reserve for free** when the price is zero
- **Join waitlist** when fully reserved

### 7. Past Surprise Reveals and feedback

Only a student with a staff-verified pickup can submit feedback for that rescue.

The student may optionally provide:

- A photograph of what they received
- A written comment
- Overall rating
- Portion rating
- Surprise-quality rating
- Pickup-experience rating
- **Would you reserve again?**

Past Reveals are historical evidence, not a promise of future contents. Photos and comments must support reporting and moderation.

EcoKnight AI may summarize common feedback only from real submitted reviews. The summary must remain clearly labeled as AI-generated and must not invent claims.

### 8. Reservation result

After successful Apple Pay authorization:

- Show **Reservation confirmed**.
- Explain that payment is authorized and captured after staff verifies pickup.
- Move the reservation into My Rescues.
- Reduce live availability in Explore and Business.
- Provide **View my rescue** and **Continue exploring**.

### Required Explore states

Explore must handle:

1. Bags available
2. Only a few bags remaining
3. Fully reserved with waitlist available
4. No matching businesses or bags
5. Location permission unavailable
6. Payment authorization failed
7. Another student reserved the final bag first
8. Listing cancelled or paused by the business
9. Loading or connection failure

### Explore MVP

Build first:

- Campus location context
- Search by business
- Distance, pickup-time, rating, and availability filters
- Feed/KnightMap toggle
- Surprise Bag cards
- Surprise Bag details
- Directions
- Apple Pay reservation
- Waitlist state
- Reservation-success state
- Past Reveals preview

Do not prioritize delivery tracking, menus, food categories, tipping, promotional banners, or complicated pre-pickup personalization.

## My Rescues

### Active reservation

Show:

- Restaurant and Surprise Bag
- Pickup address
- Pickup interval
- Distance and directions
- Reservation status
- Payment status
- **View pickup pass**
- **Cancel reservation**

### Waitlist

Show:

- Restaurant and Surprise Bag
- Waiting status
- Time-limited offer when a bag becomes available
- **Accept offer with Apple Pay**
- Offer expired or declined status

### Pickup and payment

- Use a single-use QR pickup pass.
- Payment is authorized at reservation.
- Payment is captured after staff verifies pickup.
- Cancellation releases the authorization according to the stated policy.
- Show refund status if a captured payment is reversed.
- Store a verified pickup receipt.

### Completed rescue

After verification, the rescue provides:

- **Open EcoKnight AI**
- **Share a Past Reveal**
- **Leave feedback**
- **View verified impact**

## EcoKnight AI

EcoKnight AI is an environmental rescue assistant grounded in approved environmental guidance and verified KnightSaver data. Do not claim custom model training unless it is actually implemented.

After verified pickup, a student may photograph or manually enter the bag contents. The student must confirm AI-identified items before receiving item-specific suggestions.

EcoKnight AI may:

- Suggest dorm-friendly meals
- Work with microwave, mini-fridge, or no-oven limitations
- Suggest ways to use confirmed items
- Explain general storage guidance
- Suggest which confirmed items to use first
- Suggest responsible sharing when the student has excess food
- Explain the student's estimated rescue impact
- Answer general food-waste and carbon-footprint questions

EcoKnight AI must not:

- Guarantee item identity from an image
- Guarantee ingredients, allergens, freshness, expiration, or safety
- Replace business-provided labeling or professional safety guidance
- Invent availability, impact measurements, or environmental statistics
- Present estimated carbon impact as an exact measurement

## Impact

Impact is based only on completed, staff-verified pickups.

### Verified personal impact

Show:

- Verified Surprise Bags rescued
- Measured and estimated food weight as separate values
- Estimated environmental impact
- Recent verified rescues
- Weekly rescue streak

Do not present money saved as the primary impact.

### Campus impact

Show:

- Total verified campus rescues
- Campus-wide weekly goal
- Measured and estimated food weight
- Estimated environmental impact
- Residence hall and student-organization participation

### Campus Rescue League

Offer weekly and all-time views for:

- Individual students
- Residence halls
- Student organizations

Rules:

- Participation is optional.
- Students may use a nickname.
- Full names are not shown by default.
- Only staff-verified QR pickups count.
- Cancelled reservations, missed pickups, and unverified claims earn no points.
- To discourage hoarding, no more than one rescue per student per day contributes leaderboard points.
- Measured and estimated impact remain clearly labeled.

### Knight of the Week

At the weekly reset, the eligible leader receives:

- A sponsor-funded free Surprise Bag or meal
- A temporary **Rescue Knight** badge
- Leaderboard recognition
- An in-app winner notification

The reward must not silently remove normal Surprise Bag inventory or leave the participating business uncompensated. A real launch requires sponsor approval and published competition terms. The hackathon may use clearly labeled demo reward data.

## Profile

### Account

- Profile photo or initials
- Full name
- UCF email
- Student, staff, or manager role
- Authorized business location when applicable

### Pickup preferences

- Default maximum pickup distance
- Preferred campus area
- Location permission and manual-location fallback
- Preferred directions application

Food preferences must not be used to predict unknown Surprise Bag contents. User-entered allergies may be stored as a reminder but never treated as proof that a bag is safe.

### Leaderboard privacy

- Opt in or out of public ranking
- Choose a leaderboard nickname
- Select a residence hall or student organization when applicable
- Control whether the profile badge is visible

### Notifications

- Reservation confirmations
- Pickup reminders
- Waitlist offers
- Offer-expiration warnings
- Cancellation and payment updates
- Knight of the Week result
- Campus challenge milestones

### Payment and support

- Apple Pay availability
- Payment and refund history
- Accessibility preferences
- Pickup instructions
- Report a problem
- Privacy and terms
- Sign out

KnightSaver does not store full card details. Apple Pay or the payment provider handles sensitive payment credentials.

## Business section inside the shared app

The fourth navigation destination loads the business-side teammate's single-page dashboard. Its detailed requirements live in business.md.

From the student side, Business must support:

- AI voice intake that turns staff-described surplus inventory into a proposed Surprise Bag plan
- A review screen showing what AI understood, the proposed number of bags, and the proposed listing details
- Staff approval before any AI-generated listing is published
- Manual Surprise Bag creation as a fallback
- Live quantity and price
- Exact pickup start and end time
- Pickup address and map coordinates
- Logo or branded banner
- Reservation and waitlist updates
- QR pickup verification
- Verified impact updates

Changes made in Business must immediately update the Explore feed and KnightMap.

## Shared data and verified impact chain

Both sides use the same businesses, listings, reservations, waitlists, payments, pickup records, reviews, reveals, impact records, and leaderboard events.

The verified chain is:

1. Business publishes a Surprise Bag.
2. The bag appears in Explore and KnightMap.
3. Student authorizes payment and reserves.
4. Availability decreases for both sides.
5. Student opens the QR pickup pass.
6. Staff verifies the QR code.
7. Payment is captured.
8. The rescue moves to completed status.
9. Verified impact and leaderboard points update.
10. EcoKnight AI and Past Reveal submission become available.

Cancellation releases the payment authorization and may offer the bag to the next waitlisted student. It does not create impact or leaderboard credit.

## Two-to-three-minute demonstration flow

1. Business staff describes the real surplus inventory and pickup constraints to voice AI.
2. AI shows what it understood and proposes the number of Surprise Bags, price, pickup interval, and public description.
3. Staff corrects the draft if needed, approves it, and publishes.
4. The listing appears immediately on KnightMap.
5. Student sees the restaurant logo, rating, distance, availability, and pickup interval.
6. Student reserves with Apple Pay.
7. Business verifies the student's QR pickup pass.
8. Impact and the Campus Rescue League update.
9. Student opens EcoKnight AI and confirms the received items.
10. AI suggests a dorm-friendly way to use the food.
11. Show a Past Reveal and the Knight of the Week reward.

## Integration responsibilities

### Student-side developer

- Build the shared five-item bottom navigation.
- Build Explore, My Rescues, Impact, Profile, KnightMap, EcoKnight AI entry points, Past Reveals, and the Campus Rescue League.
- Provide the route where the Business dashboard is mounted.
- Use shared listing, reservation, waitlist, payment, pickup, review, impact, and leaderboard states.
- Confirm that business actions update the student experience.

### Business-side developer

- Build the single-page Business dashboard described in business.md.
- Accept a voice description of the real surplus inventory and pickup constraints.
- Show staff what AI understood before proposing a listing.
- Let AI propose the number of Surprise Bags and related listing details from that inventory.
- Require staff review and approval before publication.
- Support manual listing as a fallback.
- Publish the logo, approved price, approved quantity, pickup interval, and map location required by Explore.
- Manage reservations and waitlists.
- Verify QR pickup passes.
- Trigger payment capture, verified impact, leaderboard credit, EcoKnight AI access, and feedback eligibility.
- Confirm that student actions update Business.

### Joint integration requirement

The Business tab is not a second app. Both developers must agree on shared field names, statuses, and the end-to-end demo flow before merging implementation work.
