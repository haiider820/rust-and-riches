# Rust & Riches — Phase 3 AdMob setup

Phase 3 adds only the first monetization layer. The project now includes Google Mobile Ads rewarded and interstitial support, while Barn Finds, prestige, subscriptions, and other later systems remain excluded.

| Placement | Behavior | Guard |
|---|---|---|
| Welcome Back rewarded | Doubles the offline cash calculated by the server for the current welcome-back result | Only shown when the server returned positive offline earnings; the server clears the pending amount after one accepted claim |
| Active restoration rewarded | Completes the currently running restoration stage immediately | Only shown while a car has an active stage timer; the server checks that the car and stage are still active |
| Interstitial transition hook | `AdService.maybeShowInterstitial` is ready for a future major transition such as garage → showroom | Suppressed during restoration or sale and capped locally at one show attempt every three minutes |

## Test IDs and release replacement

The Android and iOS platform configuration contains Google’s test **application IDs**, and `lib/services/ad_service.dart` contains Google’s test rewarded and interstitial **ad unit IDs**. Every location is marked with a release warning. Replace both platform app IDs and all four ad unit constants with the production values before publishing.

The test IDs currently used are:

| Platform | Rewarded | Interstitial | App ID |
|---|---|---|---|
| Android | `ca-app-pub-3940256099942544/5224354917` | `ca-app-pub-3940256099942544/1033173712` | `ca-app-pub-3940256099942544~3347511713` |
| iOS | `ca-app-pub-3940256099942544/1712485313` | `ca-app-pub-3940256099942544/4411468910` | `ca-app-pub-3940256099942544~1458002511` |

## Reward claim flow

A rewarded ad creates a unique reward ID and places it in the ad’s server-side verification custom data. When the Mobile Ads SDK reports `onUserEarnedReward`, the client calls the Firebase callable `claimReward` with the reward ID, reward kind, and optional car ID. The function uses a Firestore transaction over `players/{uid}/claimedRewards/{rewardId}`. A second claim with the same reward ID returns `accepted: false` and does not mutate the economy.

The offline doubling reward is backed by `lastIdleCashEarned`, which is written by the server catch-up transaction and cleared only after an accepted doubling claim. The instant-finish reward validates the car’s current active stage and advances exactly one stage; it does not skip the entire restoration chain.

This server-side transaction prevents duplicate claims from one tracked reward ID. Before release, production should additionally configure and verify AdMob server-side verification callbacks for stronger proof that a reward ID came from a completed ad view, rather than relying only on the client SDK callback.

## Validation

The project passes `flutter analyze`, `flutter test`, and `node --check functions/index.js`. A real device build still requires the Android SDK/Xcode toolchains, valid Firebase platform configuration, and deployed Cloud Functions.

## References

[1]: https://developers.google.com/admob/flutter/test-ads "Enable test ads | Flutter | Google for Developers"
[2]: https://developers.google.com/admob/flutter/rewarded "Rewarded ads | Flutter | Google for Developers"
[3]: https://developers.google.com/admob/flutter/interstitial "Interstitial ads | Flutter | Google for Developers"
