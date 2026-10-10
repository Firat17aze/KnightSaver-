# KnightSaver Student Experience

## One app with five bottom-navigation sections

KnightSaver is one shared app, not two separate apps. The bottom navigation contains five sections:

1. **Explore**
   - Discover available surplus food.
   - Search and filter current listings.
   - Open food details.
   - Reserve with Apple Pay or join a waitlist.
2. **My Rescues**
   - View active reservations.
   - See pickup deadlines and directions.
   - Manage waitlist offers.
   - Open the QR pickup pass.
   - Cancel a reservation and view payment release or refund status.
3. **Impact**
   - View completed and staff-verified rescues.
   - See portions collected, money saved, and food weight.
   - Review recent rescue activity.
4. **Business**
   - Opens the simplified dashboard created by the business-side teammate.
   - Shows AI listing, current listings, reserved spots, today's rescues, and the impact report.
   - Keeps all business operations on one scrollable screen.
   - Shows a persistent **+ List surplus** button above the shared bottom navigation.
5. **Profile**
   - Manages account information, food preferences, notifications, payment settings, and app support.
   - Shows the user's student or authorized business role.

The same five-item navigation shell is shared by both developers. The student-side developer owns **Explore**, **My Rescues**, **Impact**, **Profile**, and the shared navigation shell. The business-side developer owns the content inside **Business**.

For a real deployment, the **Business** section must require an authorized staff or manager account. For the hackathon demonstration, the fourth section can be accessible as a clearly labeled demo business view.

## Shared bottom navigation

| Position | Label | Purpose |
|---|---|---|
| 1 | **Explore** | Find and reserve available food |
| 2 | **Rescues** | Open **My Rescues** to manage reservations, waitlists, payments, and pickup passes |
| 3 | **Impact** | View verified personal savings and rescue history |
| 4 | **Business** | Open the single-page business operations dashboard |
| 5 | **Profile** | Manage account, preferences, notifications, payment settings, and support |

The selected section should be visually clear. Switching sections must not erase active reservations, payment status, waitlist offers, profile settings, or live business updates because all five sections use the same shared backend and database.

## Bottom-navigation visual direction

Use a Rakuten-inspired navigation structure while keeping KnightSaver's own identity.

### Overall shape

- A floating white rounded capsule sits slightly above the bottom safe area.
- The navigation has a soft shadow and subtle separation from the page content.
- It contains five equal-width destinations.
- Each destination uses an icon above a short text label.
- Labels remain visible for both active and inactive destinations.
- The navigation stays visible while switching between the five main sections.

### Active destination

- The active destination receives a soft KnightSaver accent background behind the icon and label.
- Use KnightSaver gold or another approved brand accent instead of Rakuten purple.
- The active icon and label use the strongest brand color.
- The selected area is rounded and visibly larger than the icon alone, similar to a soft oval or circular segment.
- Selection movement may use a short, restrained transition.
- The active state must remain understandable without animation or color alone.

### Inactive destinations

- Use simple outline icons.
- Use neutral dark labels with enough contrast.
- Do not place every inactive tab inside its own visible container.
- Avoid badges unless a time-sensitive reservation or waitlist offer genuinely needs attention.

### Navigation labels and icons

| Position | Visible label | Suggested icon | Destination |
|---|---|---|---|
| 1 | **Explore** | Search or compass | Food discovery |
| 2 | **Rescues** | Ticket, bag, or check-circle | Page title remains **My Rescues** |
| 3 | **Impact** | Leaf | Verified savings and rescue history |
| 4 | **Business** | Storefront | Simplified business dashboard |
| 5 | **Profile** | Person | Account and preferences |

Use **Rescues** in the navigation instead of **My Rescues** if space is tight. The page itself can still be titled **My Rescues**.

### Mobile behavior

- Keep all five destinations on one row.
- Preserve comfortable touch targets for every destination.
- Respect the phone's bottom safe area.
- Do not allow page content or the **+ List surplus** action to sit behind the navigation.
- On the Business section, place **+ List surplus** immediately above the floating navigation capsule.
- If a student action such as **Reserve with Apple Pay** is fixed near the bottom, place it above the navigation with clear spacing.

This is a structural reference, not a direct copy: KnightSaver uses its own icons, labels, color system, spacing, and brand identity.

## Contextual student bottom action

The shared five-item navigation remains visible, but the selected listing or reservation may show one additional contextual action immediately above it:

- **Reserve with Apple Pay** — Authorizes payment and secures an available portion.
- **Join waitlist** — Appears when all portions are reserved.
- **Accept offer with Apple Pay** — Appears when a waitlisted portion becomes available.
- **View pickup pass** — Appears after the student has an active reservation.

The app shows only the contextual action that matches the student's current state. These are not additional navigation sections.

## Explore

### Location and search

- Current campus location.
- Search by food or business.
- Optional natural-language search.
- Filters for price, walking time, pickup deadline, and confirmed dietary information.

### Available food

- Food name and image.
- Business location.
- Remaining quantity.
- Free or discounted price.
- Walking time.
- Pickup deadline.
- Available, closing soon, or fully reserved status.

### Food details

- Portion description.
- Confirmed dietary information.
- Allergen and cross-contact information.
- Pickup instructions.
- Total price.
- Contextual **Reserve with Apple Pay** or **Join waitlist** action.

## My Rescues

### Active reservation

- Reserved food.
- Business and pickup location.
- Pickup deadline.
- Payment status.
- **View pickup pass** action.
- **Cancel reservation** action.

### Waitlist

- Food the student is waiting for.
- Waiting status.
- Time-limited offer countdown.
- **Accept offer with Apple Pay** action.
- Offer expired or declined status.

### Pickup and payment

- Single-use QR pickup pass.
- Authorized payment amount.
- Payment captured after staff verifies pickup.
- Payment authorization released after cancellation.
- Refund status if a captured payment is reversed.
- Verified pickup receipt.

## Impact

- Completed staff-verified rescues.
- Portions collected.
- Money saved.
- Measured and estimated food weight shown separately.
- Recent rescue activity.
- Payment receipt history connected to completed rescues.

## Profile

The fifth navigation section contains account and preference settings. It should remain short and should not duplicate the detailed rescue history already available in **My Rescues** or **Impact**.

### Account

- Profile photo or initials.
- Full name.
- UCF email.
- Student, staff, or manager role.
- Authorized business location when applicable.

### Food preferences

- Vegetarian, vegan, halal, kosher, or other selected preferences.
- Allergies entered by the user.
- Default maximum walking distance.
- Preferred pickup area.

Preferences help filter listings but do not replace business-confirmed dietary and allergen information.

### Notifications

- Reservation confirmations.
- Pickup reminders.
- Waitlist offers.
- Offer-expiration warnings.
- Cancellation, payment release, capture, and refund updates.

### Payment settings

- Apple Pay availability or connected status.
- Default payment option.
- Link to payment and refund history.

KnightSaver does not store full card details. Apple Pay or the payment provider handles sensitive payment credentials.

### App and support

- Accessibility preferences.
- Help and pickup instructions.
- Report a problem.
- Privacy information.
- Terms.
- Sign out.

## Business

The fourth navigation section loads the business-side teammate's simplified dashboard inside the same KnightSaver app.

It contains only the most important hackathon features:

### AI listing and editing

- **+ List surplus** stays immediately above the shared five-item navigation.
- **Speak with AI** converts a staff voice description into an editable listing draft.
- **Enter manually** opens a short listing form.
- Existing listings can be changed with **Edit with voice** or **Edit manually**.
- Staff review every AI-proposed change before it updates the live listing.
- AI does not invent allergens or approve food safety.

### Current listings

- Food currently available to students.
- Remaining quantity.
- Price.
- Pickup deadline.
- Available, fully reserved, paused, or closed status.
- Contextual **Edit listing** action.

### Reserved spots

- Students expected for pickup.
- Reserved item and quantity.
- Pickup deadline.
- Authorized payment status.
- Waitlist status.
- Contextual **Verify pickup** action.

If a student cancels, the payment authorization is released and the portion is offered to the waitlist.

### Today’s rescues

- Pickups verified by staff today.
- Food and quantity collected.
- Pickup time.
- Payment captured status.
- Verified rescue status.

A reservation appears here only after the business verifies the student's QR pickup pass.

### Impact report

- Verified portions rescued.
- Measured or estimated food weight.
- Revenue recovered.
- Student savings.
- Pickup completion rate.

The impact report updates only after verified pickup. Measured and estimated weight stay clearly labeled.

## Student-to-business communication

Both sides use the same listings, quantities, reservations, payments, waitlists, pickup records, and impact data.

1. Business publishes a listing in the **Business** section.
2. The listing appears in **Explore**.
3. Student reserves with Apple Pay.
4. The business sees reduced inventory and an authorized payment.
5. Student cancellation releases the payment authorization and portion.
6. The next waitlisted student receives an offer in **My Rescues**.
7. That student accepts and authorizes payment.
8. Business verifies the QR pickup.
9. Payment is captured.
10. Student **Impact** and business verified impact update together.

## Important student flow

1. Student opens **Explore** and discovers available food.
2. Student selects a portion and taps **Reserve with Apple Pay**.
3. Payment is authorized and the reservation appears in **My Rescues**.
4. If the student cancels before pickup, the authorization is released and the portion goes to the waitlist.
5. The next student receives a time-limited offer and authorizes their own payment.
6. The student presents the QR pickup pass from **My Rescues**.
7. Staff verifies the pickup from **Business**.
8. Payment is captured and the rescue appears in **Impact**.

## Integration responsibilities

### Student-side developer

- Build the shared five-item bottom navigation.
- Build **Explore**, **My Rescues**, **Impact**, and **Profile**.
- Provide the route or section where the business dashboard will be mounted.
- Use the shared listing, reservation, waitlist, payment, pickup, and impact states.
- Confirm that business actions update the student experience.

### Business-side developer

- Build one simplified business dashboard screen.
- Include AI/manual listing, current listings, reserved spots, today’s rescues, and the impact report.
- Provide it as the content for the fourth **Business** section.
- Keep **+ List surplus** above the shared navigation so it does not cover the four tabs.
- Support voice or manual editing with staff confirmation before changes go live.
- Use the same shared listings, reservations, payments, waitlists, pickup verification, and impact data.
- Confirm that student actions update the business dashboard.

### Joint integration requirement

The fourth **Business** tab is not a separate app or duplicated project. It is one section inside the shared KnightSaver app. Both developers must agree on the same data fields, status names, and end-to-end demonstration flow before merging their work.
