# KnightSaver

KnightSaver is a campus-focused, pickup-only platform that helps students rescue surplus food through discounted **Surprise Bags** while giving participating businesses a practical way to publish surplus, verify collection, and measure credible impact.

The product is designed around one simple loop:

> A business publishes surplus, a student reserves a Surprise Bag, staff verifies the pickup, and only then does KnightSaver record impact and unlock the post-pickup experience.

## What we are building

KnightSaver is one shared iOS app with five primary areas:

| Area | Purpose |
|---|---|
| **Explore** | Find available Surprise Bags, search participating businesses, filter results, and reserve a pickup. |
| **Map / KnightMap** | See live pickup locations across campus and open the same reservation flow used by Explore. |
| **Impact** | View verified rescue impact, Campus Rescue League progress, Past Reveals, and EcoKnight AI after pickup. |
| **Business** | Let authorized staff publish surplus, manage reservations, scan student passes, and verify pickups. |
| **Profile** | Manage the student account and open the reusable Knight Pass. |

KnightSaver is not a delivery service or restaurant menu. Surprise Bag contents intentionally remain unknown until pickup because each bag depends on that business's real surplus.

## The Knight Pass

Students have **one reusable Knight Pass** in Profile rather than receiving a separate Wallet pass for every reservation.

- The same card is used for every KnightSaver pickup.
- The QR code identifies a secure KnightSaver user session; it should not contain a raw student ID or reservation details.
- Staff scans the card from the authenticated Business experience.
- The server checks only reservations valid for the staff member's current business and location.
- No match returns **No valid pickup**.
- One match opens that pickup for confirmation.
- Multiple matches show a short list so staff can select the exact reservation being collected.
- Verification must be idempotent so the same pickup cannot be claimed twice.

The reusable pass may be added to Apple Wallet once. A production implementation requires a signed Wallet pass, an Apple pass certificate, and a backend pass-update service. Those credentials and generated pass files must never be committed to this repository.

## Product principles

- **Pickup only.** Do not introduce delivery language or delivery tracking.
- **Surprise means surprise.** Never promise exact contents, dietary suitability, ingredients, allergens, or freshness.
- **Verified impact only.** Payment capture, impact totals, leaderboard credit, EcoKnight AI, and review eligibility begin only after staff verifies pickup.
- **Human approval for business AI.** AI may interpret staff-provided surplus and propose a listing, but staff must review and approve it before publication.
- **Historical evidence is not a guarantee.** Past Surprise Reveals show previous verified experiences and do not predict the next bag.
- **Accessible by default.** Controls should support VoiceOver, Dynamic Type, reduced motion, safe areas, and iOS touch-target guidance.

## Current iOS prototype

The repository includes a native SwiftUI prototype targeting iOS 17 and later.

### Implemented

- Shared five-item bottom navigation
- Explore campus-location context
- Search, availability filters, and sorting
- Branded Surprise Bag cards
- Surprise Bag details, pickup information, and Past Reveals examples
- Reservation confirmation using local demo state
- One reusable, debit-card-inspired Knight Pass in Profile
- Card flip interaction with a generated QR code
- Background-tap and close-button dismissal
- Native Add to Apple Wallet control with an honest setup state
- Reduced-motion handling and accessibility labels for key interactions

### Planned or still mocked

- Authentication and real student profiles
- Backend listings, reservations, waitlists, and inventory synchronization
- Apple Pay authorization and payment capture
- Signed Apple Wallet pass generation and updates
- Staff QR scanner and server-side pickup validation
- KnightMap implementation
- Business publishing and reservation dashboard
- EcoKnight AI and verified post-pickup flows
- Campus Rescue League, verified impact, reviews, and Past Reveal uploads
- Production restaurant branding and real-time availability

No production backend, payment credentials, Apple signing material, or private user data is included.

## Run the app

Requirements:

- macOS with Xcode
- An iOS 17-or-later Simulator

Steps:

1. Open `ios/KnightSaver/KnightSaver.xcodeproj` in Xcode.
2. Select an iPhone Simulator.
3. Press **Run** or use `Command-R`.

If the Simulator displays an older build, stop the app, delete the installed KnightSaver app from the Simulator, and run it again from Xcode.

## Repository structure

```text
.
├── README.md
├── student.md                         # Student product and experience specification
├── business.md                        # Business product and staff workflow specification
└── ios/
    └── KnightSaver/
        ├── KnightSaver.xcodeproj
        └── KnightSaver/
            ├── App/                   # App shell and navigation
            ├── DesignSystem/          # Shared colors and visual tokens
            ├── Features/Explore/      # Explore, details, and Knight Pass components
            ├── Models/                # Demo product and reservation models
            └── Assets.xcassets/       # App and brand assets
```

## Architecture documents

- [`student.md`](student.md) describes the complete student experience and verified impact chain.
- [`business.md`](business.md) describes surplus publishing, staff workflows, pickup verification, and business impact.

These documents describe the target product. The **Current iOS prototype** section above is the source of truth for what is implemented today.

## Near-term development order

1. Define shared backend objects and status values for businesses, listings, reservations, waitlists, payments, and pickup verification.
2. Build authentication and replace local demo data with live listings.
3. Implement reservation management and the staff scanner using the reusable Knight Pass protocol.
4. Connect Apple Pay and the signed Apple Wallet pass lifecycle.
5. Build KnightMap and the Business publishing dashboard.
6. Add verified Impact, EcoKnight AI, Past Reveals, and the Campus Rescue League.

## Project status

KnightSaver is currently an early native iOS prototype. The visual foundation and core discovery flow are in place; backend integration, business operations, payments, and verified impact are the next major milestones.
