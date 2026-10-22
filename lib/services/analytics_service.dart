import 'package:firebase_analytics/firebase_analytics.dart';
import 'dart:async';

/// Thin analytics wrapper. Every call is guarded: when Firebase is not
/// configured (placeholders, demo mode) it silently no-ops instead of
/// crashing the game.
class AnalyticsService {
  bool _ready = false;

  void init() {
    try {
      FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  void logEvent(String name, [Map<String, Object>? parameters]) {
    if (!_ready) return;
    try {
      unawaited(
        FirebaseAnalytics.instance.logEvent(name: name, parameters: parameters),
      );
    } catch (_) {
      // Analytics must never break gameplay.
    }
  }

  void logBuy(String tier) => logEvent('buy_car', {'tier': tier});
  void logSell(int earnings, bool haggled) =>
      logEvent('sell_car', {'earnings': earnings, 'haggled': haggled});
  void logUpgrade(String kind, int level) =>
      logEvent('upgrade', {'kind': kind, 'level': level});
  void logFranchise(String cityId) =>
      logEvent('franchise', {'city': cityId});
  void logBarnFindClaim(bool won) =>
      logEvent('barn_find_claim', {'won_minigame': won});
}
