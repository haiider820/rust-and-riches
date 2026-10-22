# Rust & Riches 🔧💰

An idle garage-management tycoon game built with Flutter. Buy rusted-out
wrecks, restore them through five stages, and flip them for profit. Expand
your lot, upgrade your tools, hunt barn finds, and franchise into new cities.

![Rust & Riches icon](assets/icon.png)

## How it plays

- **Buy wrecks** in three tiers: Common ($120), Rare ($420), Classic ($950).
- **Restore** through 5 stages: Wrecked → Stripped → Repaired → Painted →
  Detailed. Each job takes real time — even while the app is closed.
- **Sell for 2.5–3×** — every car is appraised on purchase, and the price you
  see is the price you get. Win the **haggling mini-game** at sale time for
  +10%.
- **Upgrade**: lot levels add garage bays (2 → 6), tool levels speed up every
  job by 8% per level.
- **Barn Finds**: timed offers on rare and vintage models — win the reflex
  mini-game to claim them free.
- **Franchise** at $10,000 lifetime earnings: move to a new city with a fresh
  theme, keep your reputation multiplier.
- **Daily missions + streaks**, interstitial & rewarded ads, VIP Garage Pass
  (RevenueCat), consumable time-skips.

## Architecture

- `lib/features/garage/` — game feature (model, state, presentation, widgets).
- `lib/services/` — `GameBackend` abstraction with two implementations:
  `FirebaseGameService` (production) and `DemoBackend` (in-memory, used for
  the web preview and as an offline fallback).
- `functions/index.js` — Cloud Functions: server-authoritative economy
  (`buyCar`, `advanceCarStage`, `sellCar`), idle catch-up, barn finds,
  rewards, consumables. All writes run in transactions with idempotency keys.

## Getting started

Requires Flutter 3.47+ (Dart ^3.13.0).

```bash
flutter pub get
# Interactive demo (no Firebase needed):
flutter run --dart-define=DEMO=true
# Web preview:
flutter build web --dart-define=DEMO=true --release
```

### Production setup (before launch)

1. `flutterfire configure` — replace the `REPLACE_` placeholders in
   `lib/firebase_options.dart`.
2. Real AdMob app/unit IDs in `android/app/src/main/AndroidManifest.xml`,
   `ios/Runner/Info.plist`, and `lib/services/ad_service.dart`.
3. RevenueCat API keys + products (`vip_garage_pass`, `time_skip_10`,
   `barn_find_bundle`) and a purchase webhook verifier.
4. `firebase deploy --only functions` from `functions/`.
5. Google Sign-In OAuth client for account linking; Apple sign-in for iOS.

See `PRIVACY.md`, `PHASE_7_UPGRADES.md`, and the `docs/` folder for the full
launch checklist.

## Tests

```bash
flutter analyze
flutter test
node --check functions/index.js
```
