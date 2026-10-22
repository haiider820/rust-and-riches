# Rust & Riches — Phase 7: upgrades & interstitials

Phase 7 wires up two systems that existed as dead state until now: **lot/tool
upgrades** and **interstitial ads**.

## Lot upgrades

- `lotLevel` (1–5) is no longer a display-only stat. Each level adds one garage
  bay: level 1 → 2 bays … level 5 → 6 bays (`lotMaxBays` in `progression.dart`).
- Upgrade costs: 1200 / 3000 / 6000 / 10000 cash (`lotUpgradeCost`).
- The buy screen and garage header read the live bay count; the "bays occupied"
  message names the current count.
- Server parity: `claimBarnFind` in `functions/index.js` caps cars at
  `lotMaxBays(data.lotLevel)` instead of the hardcoded 2.

## Tool upgrades

- `toolLevel` (1–5) speeds up every restoration stage by 8% per level
  (`toolDurationMultiplier`: 1.0 → 0.68), floored at 60% of base time.
- Upgrade costs: 600 / 1500 / 3000 / 5000 cash (`toolUpgradeCost`).
- The formula lives in `progression.dart` and is mirrored in
  `functions/index.js` (`catchUpOnOpen`), so the client progress bar and the
  server-authoritative idle catch-up advance stages on the same scaled clock.
  Keep both copies in sync when tuning.
- `Car.progressAt` and `Car.stageDurationFor` take an optional `toolLevel`
  (default 1); the garage screen passes `game.toolLevel`.

## Interstitials

- `AdService.maybeShowInterstitial` finally has a call site: after a car is
  sold, via `GameController.sell` (fire-and-forget with `unawaited`).
- VIP Garage Pass holders never see interstitials; the existing 3-minute
  cooldown still applies.
- Unit IDs are still the Google test IDs — swap for production IDs before
  release (see Phase 3 notes).

## Validation

```bash
flutter analyze
flutter test
node --check functions/index.js
```
