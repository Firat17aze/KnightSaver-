# KnightSaver Student Experience

## One app with four bottom-navigation sections

KnightSaver is one shared app, not two separate apps. The bottom navigation contains four sections:

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
   - Opens the business dashboard created by the business-side teammate.
   - Shows live listings, pickup queue, waitlists, payments, and verified impact.
   - Keeps all business operations on one scrollable screen.
   - Shows a persistent **+ List surplus** button above the shared bottom navigation.

The same four-item navigation shell is shared by both developers. The student-side developer owns **Explore**, **My Rescues**, **Impact**, and the shared navigation shell. The business-side developer owns the content inside **Business**.

For a real deployment, the **Business** section must require an authorized staff or manager account. For the hackathon demonstration, the fourth section can be accessible as a clearly labeled demo business view.

## Shared bottom navigation

| Position | Label | Purpose |
|---|---|---|
| 1 | **Explore** | Find and reserve available food |
| 2 | **My Rescues** | Manage reservations, waitlists, payments, and pickup passes |
| 3 | **Impact** | View verified personal savings and rescue history |
| 4 | **Business** | Open the single-page business operations dashboard |

The selected section should be visually clear. Switching sections must not erase active reservations, payment status, waitlist offers, or live business updates because all four sections use the same shared backend and database.

## Contextual student bottom action

The shared four-item navigation remains visible, but the selected listing or reservation may show one additional contextual action immediately above it:

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

## Business

The fourth navigation section loads the business-side teammate's single-page dashboard inside the same KnightSaver app.

It contains:

1. **Location and status**
   - Current business location.
   - Pickup service open or closed.
   - Closing time.
2. **Right now**
   - Portions available.
   - Portions reserved.
   - Students arriving.
   - Portions collected.
3. **Live listings**
   - Food name.
   - Remaining quantity.
   - Price.
   - Pickup deadline.
   - Listing status.
4. **Pickup queue**
   - Student name.
   - Reserved item.
   - Payment status.
   - Contextual **Verify pickup** action.
5. **Waitlist**
   - Number of students waiting.
   - Active offers.
   - Released portions after cancellations.
6. **Today's verified impact**
   - Portions rescued.
   - Food weight.
   - Revenue recovered.
   - Student savings.
   - Pickup completion rate.
7. **Recent activity**
   - Listing published.
   - Reservation created.
   - Payment authorized.
   - Student cancellation.
   - Payment released.
   - Pickup verified.
   - Payment captured.
8. **Persistent business action**
   - **+ List surplus** stays above the shared four-item navigation.
   - It opens **Speak listing**, **Quick form**, and **Use template**.

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

- Build the shared four-item bottom navigation.
- Build **Explore**, **My Rescues**, and **Impact**.
- Provide the route or section where the business dashboard will be mounted.
- Use the shared listing, reservation, waitlist, payment, pickup, and impact states.
- Confirm that business actions update the student experience.

### Business-side developer

- Build one business dashboard screen.
- Provide it as the content for the fourth **Business** section.
- Keep **+ List surplus** above the shared navigation so it does not cover the four tabs.
- Use the same shared listings, reservations, payments, waitlists, pickup verification, and impact data.
- Confirm that student actions update the business dashboard.

### Joint integration requirement

The fourth tab is not a separate app or duplicated project. It is one section inside the shared KnightSaver app. Both developers must agree on the same data fields, status names, and end-to-end demonstration flow before merging their work.
