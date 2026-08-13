# Phase 3 AdMob implementation notes

Google’s Flutter guidance says to use Google-provided test ad units during development and replace them with the app’s own ad unit IDs before publishing. The official Flutter rewarded test IDs are Android `ca-app-pub-3940256099942544/5224354917` and iOS `ca-app-pub-3940256099942544/1712485313`. The official interstitial test IDs are Android `ca-app-pub-3940256099942544/1033173712` and iOS `ca-app-pub-3940256099942544/4411468910`.

Rewarded ads must handle `onUserEarnedReward`; the current Flutter API also supports `ServerSideVerificationOptions(customData: ...)` on the loaded ad. The implementation will generate a one-time reward token, pass it as custom data, and call the backend after the reward callback. The backend will claim the token transactionally so duplicate callbacks cannot grant the same reward twice.

Sources:

1. https://developers.google.com/admob/flutter/test-ads
2. https://developers.google.com/admob/flutter/rewarded
3. https://developers.google.com/admob/flutter/interstitial
