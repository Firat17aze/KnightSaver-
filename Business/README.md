# Business tab (Hamza)

SwiftUI code for the **Business** section, the 4th of the 5 bottom-navigation buttons. It follows `business.md`.

## Add it to the Xcode project (Firat, on the Mac)

1. `git pull` on the `business` branch.
2. In Xcode, drag the `Business` folder into the project navigator. Tick **Copy items if needed** off, **Create groups** on, and the app target on.
3. In the shared `TabView`, put this as the 4th tab:

```swift
BusinessDashboardView()
    .tabItem { Label("Business", systemImage: "storefront") }
```

Needs iOS 16 or newer. No packages, no API keys, and no Info.plist changes.

## Files

| File | What it does |
|---|---|
| `BusinessDashboardView.swift` | The one scrollable page: Current listings, Reserved spots, Today's rescues, Impact report, plus the **+ List surplus** button above the tab bar |
| `ListSurplusFlow.swift` | "+ List surplus": choose **Speak with AI** or **Enter manually**, then review and publish |
| `EditListingFlow.swift` | "Edit listing": **Edit with voice** (AI proposes changes, staff approve) or **Edit manually** |
| `ListingFormView.swift` | The review form. Allergens and food safety must be confirmed by staff |
| `VerifyPickupSheet.swift` | Staff check the code on the student's QR pass, then payment is captured |
| `ListingAssistant.swift` | The "AI": turns what staff say into a draft or proposed edits |
| `BusinessStore.swift` | All business data and actions, with demo data |
| `BusinessModels.swift` | `Listing`, `Reservation`, `WaitlistEntry`, `Rescue`, `ImpactSummary`, `ListingDraft` |
| `BusinessComponents.swift` | Colors (UCF gold) and small shared views |

## Demo notes

- The page is labeled **Demo business view** and runs on sample data for a campus café.
- **Voice:** staff tap the text box and use the microphone on the iPhone keyboard (built-in dictation). The text is turned into a draft by simple rules on the phone, so it works offline. It can be swapped for a real AI model later. It never fills in allergens or approves food safety.
- **QR verify:** staff type or compare the code under the student's QR (e.g. `KS-4821`). In the demo there is a "Fill in code (demo)" button. A camera scanner can be added later.
- **Student cancel:** the "…" menu on a reservation has **Simulate student cancel (demo)**. It releases the payment and gives the spot to the next student on the waitlist.

Try in the demo: cancel one of the **Everything bagels** reservations. Maya, who is on the waitlist, gets the spot automatically.

## Connecting to the student side

The models here (`Listing`, `Reservation`, …) are meant to be the shared data for both sides. If the student side already has its own types with the same names, we merge them into one set before building. Otherwise Xcode will report duplicate types.
