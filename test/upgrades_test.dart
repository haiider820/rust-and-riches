import 'package:flutter_test/flutter_test.dart';

import 'package:rust_riches/features/garage/model/car.dart';
import 'package:rust_riches/features/garage/model/progression.dart';
import 'package:rust_riches/features/garage/state/game_controller.dart';
import 'package:rust_riches/services/game_backend.dart';

void main() {
  group('lot upgrades', () {
    test('lotMaxBays scales with level and clamps', () {
      expect(lotMaxBays(1), 2);
      expect(lotMaxBays(2), 3);
      expect(lotMaxBays(5), 6);
      expect(lotMaxBays(0), 2);
      expect(lotMaxBays(99), 6);
    });

    test('lot upgrade costs exist for levels 1-4 only', () {
      for (var level = 1; level <= 4; level++) {
        expect(lotUpgradeCost[level], isNotNull);
        expect(lotUpgradeCost[level], greaterThan(0));
      }
      expect(lotUpgradeCost[5], isNull);
    });

    test('upgradeLot deducts cash and adds a bay', () async {
      final game = GameController(_FakeBackend())
        ..cash = 5000
        ..lotLevel = 1;
      expect(game.maxGarageSlots, 2);

      await game.upgradeLot();

      expect(game.lotLevel, 2);
      expect(game.cash, 5000 - lotUpgradeCost[1]!);
      expect(game.maxGarageSlots, 3);
      expect(game.canUpgradeLot, isTrue);
    });

    test('upgradeLot refuses without cash or at max level', () async {
      final broke = GameController(_FakeBackend())
        ..cash = 10
        ..lotLevel = 1;
      await broke.upgradeLot();
      expect(broke.lotLevel, 1);
      expect(broke.cash, 10);

      final maxed = GameController(_FakeBackend())
        ..cash = 999999
        ..lotLevel = 5;
      await maxed.upgradeLot();
      expect(maxed.lotLevel, 5);
      expect(maxed.lotUpgradePrice, isNull);
    });

    test('canBuy respects upgraded bay count', () {
      final game = GameController(_FakeBackend())
        ..cash = 10000
        ..lotLevel = 2
        ..cars = List.generate(
          3,
          (i) => Car(
            id: 'car-$i',
            tier: CarTier.common,
            stage: RestorationStage.detailed,
            purchasedAt: DateTime.fromMillisecondsSinceEpoch(0),
          ),
        );
      expect(game.maxGarageSlots, 3);
      expect(game.canBuy(CarTier.common), isFalse);

      game.lotLevel = 3;
      expect(game.canBuy(CarTier.common), isTrue);
    });
  });

  group('tool upgrades', () {
    test('toolDurationMultiplier scales and clamps', () {
      expect(toolDurationMultiplier(1), 1.0);
      expect(toolDurationMultiplier(2), closeTo(0.92, 1e-9));
      expect(toolDurationMultiplier(5), closeTo(0.68, 1e-9));
      expect(toolDurationMultiplier(0), 1.0);
      expect(toolDurationMultiplier(99), closeTo(0.68, 1e-9));
    });

    test('tool upgrade costs exist for levels 1-4 only', () {
      for (var level = 1; level <= 4; level++) {
        expect(toolUpgradeCost[level], isNotNull);
        expect(toolUpgradeCost[level], greaterThan(0));
      }
      expect(toolUpgradeCost[5], isNull);
    });

    test('upgradeTools deducts cash and speeds up stages', () async {
      final game = GameController(_FakeBackend())
        ..cash = 1000
        ..toolLevel = 1;
      await game.upgradeTools();
      expect(game.toolLevel, 2);
      expect(game.cash, 1000 - toolUpgradeCost[1]!);
    });

    test('progressAt uses the tool-level scaled duration', () {
      final car = Car(
        id: 'car-1',
        tier: CarTier.common,
        stage: RestorationStage.wrecked,
        purchasedAt: DateTime.fromMillisecondsSinceEpoch(0),
        stageStartedAt: DateTime.fromMillisecondsSinceEpoch(0).toUtc(),
      );
      // Common wrecked base duration is 15s; tool level 5 scales to 10.2s.
      final at7650ms = DateTime.fromMillisecondsSinceEpoch(7650).toUtc();
      expect(car.progressAt(at7650ms), closeTo(0.51, 0.01));
      expect(car.progressAt(at7650ms, toolLevel: 5), closeTo(0.75, 0.01));
      expect(car.stageDurationFor(5).inMilliseconds, 10200);
    });
  });
}

class _FakeBackend implements GameBackend {
  @override
  Future<void> ensureAnonymousUser() async {}

  @override
  Future<GameRemoteState?> loadState() async => null;

  @override
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
  }) async {}

  @override
  Future<BarnFindOffer?> loadBarnFindOffer() async => null;

  @override
  Future<BarnFindClaimResult> claimBarnFind({
    required String offerId,
    required bool wonMinigame,
  }) async => const BarnFindClaimResult(
    accepted: false,
    cash: 0,
    cars: [],
    collectionIds: <String>{},
  );

  @override
  Future<FranchiseResult> franchise({required String targetCityId}) async =>
      const FranchiseResult(
        cash: 850,
        cars: [],
        collectionIds: <String>{},
        lifetimeEarnings: 0,
        reputationPoints: 0,
        prestigeCount: 0,
        cityId: 'sunset_valley',
        lotLevel: 1,
        toolLevel: 1,
        multiplierGained: 1.0,
      );

  @override
  Future<RewardClaimResult> claimReward({
    required String rewardId,
    required RewardKind kind,
    String? carId,
  }) async => const RewardClaimResult(accepted: false, cash: 0, cars: []);

  @override
  Future<ConsumableGrantResult> grantConsumable({
    required String transactionId,
    required ConsumableKind kind,
  }) async => const ConsumableGrantResult(accepted: false, premiumCurrency: 0);

  @override
  Future<void> syncVipStatus({required bool active}) async {}

  @override
  Future<RewardClaimResult> spendPremiumTimeSkip({
    required String carId,
  }) async => const RewardClaimResult(accepted: false, cash: 0, cars: []);

  @override
  Future<IdleCatchUp> catchUpOnOpen() async => const IdleCatchUp(
    cash: 0,
    cars: [],
    cashEarned: 0,
    finishedCarCount: 0,
    elapsedSeconds: 0,
  );
}
