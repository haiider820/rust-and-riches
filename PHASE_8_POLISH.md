# Phase 8: honest economy, retention & launch readiness

Follow-up to Phase 7 (lot/tool upgrades, interstitials). This phase fixes the
remaining review findings that don't need Haider's store accounts.

## Honest appraiser

- Every car now rolls a concrete sale price inside the appraiser's advertised
  profit range at buy/claim time (`rollSalePrice` in `functions/index.js`,
  `rollAppraisedSalePrice` in `lib/features/garage/model/appraiser.dart` —
  keep both in sync).
- The rolled price is stored on the car (`Car.salePrice`, serialized) and is
  the price the sale actually pays. Legacy saves fall back to the tier price.
- The car card shows "Appraised $X"; the purchase card still shows the range.

## Server-authoritative economy

- New Cloud Functions: `buyCar`, `advanceCarStage`, `sellCar` — all in
  transactions. Cash, bays, stage timing and prices are validated server-side.
- `claimBarnFind` bay cap and `catchUpOnOpen` stage timing already used the
  Phase 7 formulas; catch-up now pays the car's stored `salePrice`.
- `claimReward` accepts a new `missionBonus` kind (server-capped 50–500 cash,
  idempotent reward IDs).

## Reliability & platform

- `GameController.load()` failures now show an error screen with Retry
  instead of an infinite spinner.
- Google account linking on the profile screen (anonymous → Google upgrade).
- Barn-find timer only calls the server when no live offer exists.
- Crashlytics + Analytics wired but fully guarded — no-ops when Firebase is
  not configured.
- UMP consent via `ConsentForm.loadAndShowConsentFormIfRequired()`.
- `dart:io` `Platform` usages replaced with `defaultTargetPlatform` so the
  web build compiles.

## Retention & feel

- Haggling mini-game before each sale (+10% on a win, server-applied).
- First-run onboarding tutorial (3 steps, shown once).
- Daily missions (3 rotating) + open streak, rewards granted server-side.
- Synthesized sound effects (`assets/sounds/`, `SoundService`).
- App icon generated for all densities; README rewritten; `PRIVACY.md`;
  `docs/LAUNCH_CHECKLIST.md` tracks the account-bound remaining work.

## Demo / preview

- `DemoBackend` (+ `DemoAdService`) implements the full `GameBackend`
  interface in memory, mirroring server rules.
- `flutter run --dart-define=DEMO=true` or
  `flutter build web --dart-define=DEMO=true --release` for the interactive
  preview. When Firebase init fails, the app falls back to the demo backend
  instead of hanging.

## Validation

```bash
flutter analyze        # no issues
flutter test           # 15/15 pass
node --check functions/index.js
```
