# Launch Checklist — Rust & Riches

## Code status (done in repo)

- [x] Interstitials wired (after each sale, VIP-gated, 3-min cooldown)
- [x] Lot upgrades (Lv1–5 → 2–6 bays) and tool upgrades (8%/level faster)
- [x] Honest appraiser: sale price rolled per car, stored on the car, used by
      client + server (`rollSalePrice` in `functions/index.js`,
      `rollAppraisedSalePrice` in `appraiser.dart` — keep in sync)
- [x] Server-authoritative economy: `buyCar`, `advanceCarStage`, `sellCar`
      Cloud Functions (transactions, idempotency keys)
- [x] Load-failure error screen with retry (no more infinite spinner)
- [x] Google account linking (anonymous → Google upgrade, profile screen)
- [x] Barn-find refresh optimized (server hit only when no live offer)
- [x] Haggling mini-game (+10% on win), onboarding tutorial, daily missions +
      streaks, sound effects, Crashlytics + Analytics (guarded), UMP consent
- [x] App icon (all densities), README, PRIVACY.md
- [x] Demo backend (`--dart-define=DEMO=true`) for the web preview

## Needs Haider's accounts (cannot be done from here)

1. **Firebase**: `flutterfire configure` → replaces `REPLACE_` placeholders
   in `lib/firebase_options.dart`. Then `firebase deploy --only functions`.
2. **AdMob**: real app ID + unit IDs → `AndroidManifest.xml`,
   `ios/Runner/Info.plist`, `lib/services/ad_service.dart`.
3. **RevenueCat**: API keys, products (`vip_garage_pass`, `time_skip_10`,
   `barn_find_bundle`), webhook verifier for consumables.
4. **Google Sign-In**: OAuth client ID (Android SHA-1 + iOS reversed client ID).
5. **Play Console**: privacy policy URL (host `PRIVACY.md`), content rating,
   data-safety form (location: none; account ID; crash data; ad identifiers).

## Before release

- Swap AdMob test IDs for production IDs.
- Test the full purchase flow in closed testing.
- `flutter build appbundle --release` and upload.
