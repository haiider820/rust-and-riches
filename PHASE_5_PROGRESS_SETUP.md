# Rust & Riches — Phase 5 Franchise Progression

Phase 5 adds the long-term progression loop on top of the Phase 4 Barn Finds and Garage Showroom. Subscriptions and the AI Appraiser remain out of scope.

## Franchise rule

The first franchise milestone is **$10,000 in lifetime earnings**. Lifetime earnings are retained across franchises and provide the milestone value shown in Profile & Stats. When the threshold is met, the garage AppBar exposes the franchise action.

| Resets on franchise | Carries over | Permanent reward |
|---|---|---|
| Cash, owned cars, Barn Find offer, lot level, and tool level | Discovered collection IDs, lifetime earnings, franchise count, and city history | One Reputation Point and a 0.1× increase to the earnings multiplier |

The first franchise starts the player with a 1.1× multiplier. Each later franchise increases the multiplier by another 0.1×. The server applies the multiplier to completed-car idle earnings in `catchUpOnOpen`; the client applies the same multiplier to active showroom sales for immediate feedback.

## Server contract

`franchisePlayer` is a callable Cloud Function. It reads the player document inside a Firestore transaction, checks the lifetime-earnings threshold, increments Reputation Points and prestige count, preserves `collectionIds` and `lifetimeEarnings`, resets run state to the starting values, chooses the requested reusable city palette, and writes a fresh server timestamp. The response replaces the local controller state only after the transaction succeeds.

The current client state schema is version 5 and includes `lifetimeEarnings`, `reputationPoints`, `prestigeCount`, `cityId`, `lotLevel`, and `toolLevel`. Existing documents default missing fields to Sunset Valley, zero reputation, zero prestige, and level-one upgrades.

## City reskins

Cities use the same mechanics and model catalog. The UI selects from reusable palettes for Sunset Valley, Harbor Point, Neon Heights, and Golden Plains. A city changes the garage background, header accent, and profile card surface; it does not introduce city-specific mechanics.

## Deployment

From the project root, deploy the updated Cloud Function after configuring Firebase:

```sh
firebase deploy --only functions:franchisePlayer,functions:catchUpOnOpen
```

The existing Firestore rules remain compatible with the Phase 2/3/4 client save boundary. For production hardening, move direct client state saves behind a validated callable endpoint before shipping a competitive economy; the Phase 5 franchise reset itself is transactionally server-authoritative.

## Validation

The project passes `flutter analyze`, `flutter test`, and `node --check functions/index.js`. Real-device verification still requires valid Firebase configuration, deployed callable functions, and the Android/iOS platform toolchains.
