# KnightSaver Student Experience

## Main bottom action

The student sees one main action at a time based on the selected food or reservation state:

- **Reserve with Apple Pay** — Authorizes payment and secures an available portion.
- **Join waitlist** — Appears when all portions are reserved.
- **Accept offer with Apple Pay** — Appears when a waitlisted portion becomes available.
- **View pickup pass** — Appears after the student has an active reservation.

The app should not display all four actions together. It shows only the action that matches the student's current state.

## Everything else on the same page

1. **Location and search**
   - Current campus location.
   - Search by food or business.
   - Optional natural-language search.
   - Filters for price, walking time, pickup deadline, and confirmed dietary information.
2. **Active reservation**
   - Reserved food.
   - Business and pickup location.
   - Pickup deadline.
   - Payment status.
   - **View pickup pass** button.
   - **Cancel reservation** action.
3. **Available food**
   - Food name and image.
   - Business location.
   - Remaining quantity.
   - Free or discounted price.
   - Walking time.
   - Pickup deadline.
   - Available, closing soon, or fully reserved status.
4. **Food details**
   - Portion description.
   - Confirmed dietary information.
   - Allergen and cross-contact information.
   - Pickup instructions.
   - Total price.
   - Contextual **Reserve with Apple Pay** or **Join waitlist** action.
5. **Waitlist**
   - Food the student is waiting for.
   - Waiting status.
   - Time-limited offer countdown.
   - **Accept offer with Apple Pay** action.
   - Offer expired or declined status.
6. **Pickup and payment**
   - Single-use QR pickup pass.
   - Authorized payment amount.
   - Payment captured after staff verifies pickup.
   - Payment authorization released after cancellation.
   - Refund status if a captured payment is reversed.
   - Verified pickup receipt.
7. **My verified impact**
   - Completed rescues.
   - Portions collected.
   - Money saved.
   - Measured and estimated food weight shown separately.
8. **Recent activity**
   - Reservation created.
   - Payment authorized.
   - Waitlist joined.
   - Waitlist offer received.
   - Reservation cancelled.
   - Payment released.
   - Pickup verified.
   - Payment captured or refunded.

## Important student flow

1. Student discovers available food.
2. Student selects a portion and taps **Reserve with Apple Pay**.
3. Payment is authorized and the reservation becomes active.
4. If the student cancels before pickup, the authorization is released and the portion goes to the waitlist.
5. The next student receives a time-limited offer and authorizes their own payment.
6. The student presents the QR pickup pass.
7. Staff verifies the pickup.
8. Payment is captured and the rescue appears in the student's verified impact.
