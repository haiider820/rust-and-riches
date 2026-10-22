import '../features/garage/model/car.dart';
import '../features/garage/model/progression.dart';

enum RewardKind { doubleOfflineEarnings, finishRestoration, missionBonus }

enum ConsumableKind { timeSkip, barnFindBundle }

abstract interface class GameBackend {
  Future<void> ensureAnonymousUser();
  Future<GameRemoteState?> loadState();
  Future<void> saveState({
    required int cash,
    required List<Car> cars,
    required Set<String> collectionIds,
    required int lifetimeEarnings,
    required int reputationPoints,
    required int prestigeCount,
    required String cityId,
    required int lotLevel,
    required int toolLevel,
    required int premiumCurrency,
  });
  Future<IdleCatchUp> catchUpOnOpen();
  Future<RewardClaimResult> claimReward({
    required String rewardId,
    required RewardKind kind,
    String? carId,
    int? rewardAmount,
  });
  Future<BarnFindOffer?> loadBarnFindOffer();
  Future<BarnFindClaimResult> claimBarnFind({
    required String offerId,
    required bool wonMinigame,
  });
  Future<FranchiseResult> franchise({required String targetCityId});
  Future<ConsumableGrantResult> grantConsumable({
    required String transactionId,
    required ConsumableKind kind,
  });
  Future<void> syncVipStatus({required bool active});
  Future<RewardClaimResult> spendPremiumTimeSkip({required String carId});

  /// Server-authoritative economy mutations. The server validates cash,
  /// bay count, stage timing and prices, then returns the canonical state.
  Future<CarTransactionResult> buyCar({required CarTier tier});
  Future<CarTransactionResult> advanceCarStage({required String carId});
  Future<SellResult> sellCar({required String carId, required bool haggled});
}

class GameRemoteState {
  const GameRemoteState({
    required this.cash,
    required this.cars,
    required this.collectionIds,
    required this.lifetimeEarnings,
    required this.reputationPoints,
    required this.prestigeCount,
    required this.cityId,
    required this.lotLevel,
    required this.toolLevel,
    required this.premiumCurrency,
    this.barnFind,
    this.vipGaragePass = false,
  });
  final int cash;
  final List<Car> cars;
  final Set<String> collectionIds;
  final int lifetimeEarnings;
  final int reputationPoints;
  final int prestigeCount;
  final String cityId;
  final int lotLevel;
  final int toolLevel;
  final int premiumCurrency;
  final BarnFindOffer? barnFind;
  final bool vipGaragePass;
  double get earningsMultiplier => reputationMultiplierFor(reputationPoints);
}

class IdleCatchUp {
  const IdleCatchUp({
    required this.cash,
    required this.cars,
    required this.cashEarned,
    required this.finishedCarCount,
    required this.elapsedSeconds,
    this.vipAutoCollected = false,
  });
  final int cash;
  final List<Car> cars;
  final int cashEarned;
  final int finishedCarCount;
  final int elapsedSeconds;
  final bool vipAutoCollected;
}

class RewardClaimResult {
  const RewardClaimResult({
    required this.accepted,
    required this.cash,
    required this.cars,
    this.premiumCurrency,
  });
  final bool accepted;
  final int cash;
  final List<Car> cars;
  final int? premiumCurrency;
}

class BarnFindClaimResult {
  const BarnFindClaimResult({
    required this.accepted,
    required this.cash,
    required this.cars,
    required this.collectionIds,
  });
  final bool accepted;
  final int cash;
  final List<Car> cars;
  final Set<String> collectionIds;
}

class FranchiseResult {
  const FranchiseResult({
    required this.cash,
    required this.cars,
    required this.collectionIds,
    required this.lifetimeEarnings,
    required this.reputationPoints,
    required this.prestigeCount,
    required this.cityId,
    required this.lotLevel,
    required this.toolLevel,
    required this.multiplierGained,
  });
  final int cash;
  final List<Car> cars;
  final Set<String> collectionIds;
  final int lifetimeEarnings;
  final int reputationPoints;
  final int prestigeCount;
  final String cityId;
  final int lotLevel;
  final int toolLevel;
  final double multiplierGained;
}

class ConsumableGrantResult {
  const ConsumableGrantResult({
    required this.accepted,
    required this.premiumCurrency,
    this.barnFindOffer,
  });
  final bool accepted;
  final int premiumCurrency;
  final BarnFindOffer? barnFindOffer;
}

/// Result of a server-authoritative car mutation (buy / advance stage).
class CarTransactionResult {
  const CarTransactionResult({
    required this.accepted,
    required this.cash,
    required this.cars,
    required this.collectionIds,
    this.message,
  });
  final bool accepted;
  final int cash;
  final List<Car> cars;
  final Set<String> collectionIds;
  final String? message;
}

/// Result of a server-authoritative sale.
class SellResult {
  const SellResult({
    required this.accepted,
    required this.cash,
    required this.cars,
    required this.earnings,
    required this.lifetimeEarnings,
    this.message,
  });
  final bool accepted;
  final int cash;
  final List<Car> cars;
  final int earnings;
  final int lifetimeEarnings;
  final String? message;
}
