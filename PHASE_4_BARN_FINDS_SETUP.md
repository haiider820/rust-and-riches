# Rust & Riches — Phase 4 Barn Finds and Garage Showroom

Phase 4 adds a retention and collection layer on top of the Phase 3 garage and save system. It contains no prestige, subscriptions, IAP, or premium currency.

## Barn Finds

Barn Finds are created by the `getBarnFindOffer` callable Cloud Function. The server chooses a rare or vintage model, a discounted cash price, a short expiration window, and a timing target. The player can claim the offer through either route:

| Route | Result | Economy |
|---|---|---|
| Tap-timing minigame | Stop the moving marker inside the target zone within up to three attempts | The car is free if the server receives a successful claim |
| Cash purchase | Use the displayed discounted price | The server deducts cash transactionally |

The server prevents overlapping offers, limits generation to a controlled random interval, expires offers, checks garage capacity, and creates a distinct car with `isBarnFind: true` and a model ID. The client checks for an offer on launch, exposes a manual refresh, and polls once per minute while the garage is open. The server remains the authority for offer creation, expiration, price deduction, and claim acceptance.

Barn Find cars use distinct model colors, a `BARN FIND` badge, and a rare or vintage label. Regular junk-lot purchases also receive stable model IDs so the showroom can track the exact model rather than only the tier.

## Garage Showroom

The Garage Showroom presents every model in the catalog as a grid. An undiscovered model is displayed as a muted locked silhouette. A model becomes discovered when the player completes its restoration chain at least once; selling the car afterward does not remove the discovery. The discovered model IDs are persisted in `players/{uid}.collectionIds` on every meaningful save and returned by the backend state loader.

## Firestore and deployment

Deploy the updated functions and rules from the project root after configuring Firebase:

```sh
firebase deploy --only functions:getBarnFindOffer,functions:claimBarnFind,firestore:rules
```

The player document now uses schema version `4` and may contain `barnFind`, `lastBarnFindAt`, `collectionIds`, `cash`, `cars`, and the existing Phase 2/3 timestamps and reward data. Existing Phase 2/3 documents remain compatible because the new fields are merged and missing collection data defaults to an empty set.

## Validation

The project passes `flutter analyze`, `flutter test`, and `node --check functions/index.js`. Building and deploying to real Android/iOS targets still requires the local platform toolchains, valid Firebase configuration, and deployed callable functions.
