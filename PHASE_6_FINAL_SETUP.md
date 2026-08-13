# Rust & Riches — Phase 6 Final Setup

## Included scope

Phase 6 adds RevenueCat monetization, premium-currency consumables, VIP Garage Pass behavior, a rules-based Appraiser, iOS-safe layout handling, and regression coverage across the earlier garage, idle, Barn Find, collection, and franchise systems.

The following systems remain intentionally absent: additional subscriptions, the AI Appraiser model runtime, new Barn Find mechanics, and any post-Phase-6 gameplay systems.

## RevenueCat configuration

The Flutter wrapper is `lib/services/revenuecat_service.dart`. It uses these placeholder identifiers:

| Purpose | Placeholder |
|---|---|
| Entitlement | `vip_garage_pass` |
| VIP package | `vip_garage_pass` |
| Time-skip consumable | `time_skip_bundle` |
| Guaranteed Barn Find bundle | `guaranteed_barn_find_bundle` |

Replace the Android and iOS public SDK keys in `RevenueCatConfig` before release. The app intentionally skips SDK configuration while either key starts with `REPLACE_`, which keeps local development and widget tests deterministic.

Create the products and offering packages in RevenueCat with the exact identifiers above. Configure the VIP product as an auto-renewing subscription and the time-skip/Barn Find products as consumables in the relevant Google Play and App Store Connect products. Link the entitlement to the VIP package.

The anonymous Firebase UID is passed as the RevenueCat `appUserID`, allowing the subscription identity to remain aligned with the Firestore player document. The controller synchronizes the active entitlement to Firestore through `syncVipStatus`.

## VIP Garage Pass behavior

VIP applies a server-authoritative 1.2 multiplier to idle restoration earnings and an active-sale multiplier in the controller. VIP players bypass the Welcome Back screen; the server catch-up result is silently applied. The local interstitial cooldown is bypassed. The garage and showroom use the gold VIP palette when the entitlement is active.

The purchase dialog states that the subscription renews automatically unless canceled in the App Store or Google Play account settings. It also identifies the benefits and provides Restore. Keep this disclosure visible before purchase and replace it with the store-approved localized copy during release review if required.

## Consumables and fraud boundaries

RevenueCat purchases return a store transaction identifier. The client sends that identifier to the callable `grantConsumable` function. Firestore stores the identifier in `iapTransactions` and rejects duplicate grants transactionally.

`time_skip_bundle` grants premium currency used for a server-authoritative 10-unit one-stage time skip. `guaranteed_barn_find_bundle` grants premium currency and creates a bundled, free-to-claim Barn Find offer when no active offer exists. The server owns the offer creation, expiration, balance mutation, and idempotency behavior.

For production, configure RevenueCat receipt/webhook verification or a trusted RevenueCat server integration before allowing a client-provided transaction identifier to grant value. The current callable is an integration boundary and uses idempotent transaction records for the prototype.

## Appraiser boundary

`CarAppraiser` is the UI-facing interface. `HeuristicCarAppraiser` currently predicts a low/high profit range from tier sale price, purchase price, and vintage rarity, and recommends repair, paint, then detail. A future TFLite or ONNX implementation can replace the heuristic without changing the garage purchase UI or widget contract.

## iOS parity checklist

The project targets iOS 15 and declares both iPhone and iPad device families. Existing garage, Welcome Back, showroom, and profile screens use `SafeArea`; the showroom and profile screens were explicitly wrapped during Phase 6 for notched devices and home-indicator clearance.

Before App Store submission:

1. Replace the RevenueCat iOS public SDK key and configure the matching App Store Connect products.
2. Enable the In-App Purchase capability for the Runner target in Xcode and verify the StoreKit products in the selected App Store Connect environment.
3. Replace the iOS AdMob test app ID and rewarded/interstitial unit IDs before release, while keeping test IDs during development.
4. Confirm the iOS privacy disclosures, App Tracking Transparency decision, and Google Mobile Ads consent flow required for the target markets.
5. Keep rewarded ads explicitly optional and label the action as watching an ad for a stated in-game reward. Never start a rewarded ad during an active restoration or sale.
6. Test subscription disclosure, restore purchases, purchase cancellation, interrupted purchases, and offline launch on a physical notched iPhone and an iPad.

## Validation

The source was formatted and passed `flutter analyze`, `flutter test`, and `node --check functions/index.js` in the sandbox. A signed Android/iOS store build still requires the corresponding platform SDKs, Firebase project configuration, RevenueCat keys, store products, and AdMob release identifiers.

### References

- [RevenueCat Flutter installation](https://www.revenuecat.com/docs/getting-started/installation/flutter)
- [Google Mobile Ads Flutter test ads](https://developers.google.com/admob/flutter/test-ads)
- [Google Mobile Ads Flutter rewarded ads](https://developers.google.com/admob/flutter/rewarded)
- [Apple In-App Purchase](https://developer.apple.com/in-app-purchase/)
- [Apple App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
