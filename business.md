# KnightSaver Business Experience

## Position inside the shared app

KnightSaver is one app with four bottom-navigation sections:

1. **Explore**
2. **My Rescues**
3. **Impact**
4. **Business**

The business dashboard is the fourth section. It is one simple, scrollable page connected to the same listings, reservations, payments, waitlists, pickups, and impact data used by the student sections.

For a real deployment, the **Business** section requires an authorized staff or manager account. During the hackathon, it may be shown as a clearly labeled demo business view.

## Main business action

**+ List surplus**

This button remains immediately above the shared four-item navigation while the **Business** section is selected.

When tapped, staff choose one of two methods:

- **Speak with AI** — Staff describe the food, quantity, price, and pickup time. AI creates an editable draft.
- **Enter manually** — Staff complete the short listing form themselves.

Staff always review and confirm a listing before it is published. AI cannot invent allergens or approve food safety.

## Simplified business page

The business page contains only four important sections.

### 1. Current listings

Shows food currently available to students:

- Food name.
- Remaining quantity.
- Price.
- Pickup deadline.
- Available, fully reserved, paused, or closed status.
- **Edit listing** action.

Staff can edit an existing listing in two ways:

- **Edit with voice** — For example: “Change the bagels to six portions and move pickup to 7:30.”
- **Edit manually** — Change the quantity, price, food details, or pickup deadline in a form.

AI converts voice instructions into proposed changes. Staff see the changes and approve them before the live listing updates.

### 2. Reserved spots

Shows upcoming student pickups:

- Student name.
- Reserved item and quantity.
- Pickup deadline.
- Authorized payment status.
- Waitlist status when relevant.
- **Verify pickup** action.

When the student cancels, the authorized payment is released and the portion is offered to the next waitlisted student.

### 3. Today’s rescues

Shows completed, staff-verified pickups from today:

- Student or reservation identifier.
- Food and quantity collected.
- Pickup time.
- Payment captured status.
- Verified rescue status.

A reservation appears here only after staff verifies the QR pickup pass.

### 4. Impact report

Shows only the most useful proof for judges:

- Verified portions rescued.
- Measured or estimated food weight.
- Revenue recovered.
- Student savings.
- Pickup completion rate.

Impact updates only after a verified pickup. Measured and estimated food weight must remain clearly labeled.

## Essential business flow

1. Staff taps **+ List surplus**.
2. Staff creates the listing by AI voice or manual entry.
3. Staff reviews and publishes the listing.
4. The listing appears in the student **Explore** section.
5. Student authorizes payment and reserves.
6. The reservation appears in **Reserved spots**.
7. If the student cancels, payment is released and the waitlist is triggered.
8. Staff verifies the final student's QR pickup pass.
9. Payment is captured.
10. The pickup moves into **Today’s rescues**.
11. The **Impact report** updates.

## Features intentionally excluded from the hackathon page

To keep the business experience reliable, do not prioritize:

- Multiple business locations.
- Detailed historical analytics.
- Complex charts.
- Staff scheduling.
- Customer messaging.
- Full accounting or payout reconciliation.
- Advanced AI forecasting.
- Separate pages for listings, reservations, and reports.
