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

  group('server-authoritative economy', () {
    test('buy applies the server result and shows the appraisal', () async {
      final backend = _FakeBackend()..cash = 5000;
      final game = GameController(backend)
        ..cash = 5000
        ..lotLevel = 1;
      await game.buy(CarTier.common);

      expect(game.cars, hasLength(1));
      expect(game.cash, 5000 - CarTier.common.purchasePrice);
      expect(backend.cash, game.cash);
      expect(game.cars.first.salePrice, isNotNull);
      expect(game.lastMessage, contains('appraised'));
    });

    test('advanceStage applies the server result', () async {
      final backend = _FakeBackend()..cash = 5000;
      final game = GameController(backend)
        ..cash = 5000
        ..lotLevel = 1;
      await game.buy(CarTier.common);
      final car = game.cars.first;
      await game.advanceStage(car);

      expect(game.cars.first.stage, RestorationStage.stripped);
      expect(game.cash, 5000 - CarTier.common.purchasePrice - 25);
    });

    test('sell grants haggled bonus when won', () async {
      final backend = _FakeBackend()..cash = 5000;
      final game = GameController(backend)
        ..cash = 5000
        ..lotLevel = 1;
      await game.buy(CarTier.common);
      final car = game.cars.first.copyWith(
        stage: RestorationStage.detailed,
        stageStartedAt: null,
      );
      backend.cars = [car];
      game.cars = [car];

      await game.sell(car, haggled: true);
      final expected = (car.effectiveSalePrice * 1.1).floor();
      expect(game.cash, 5000 - CarTier.common.purchasePrice + expected);
      expect(game.cars, isEmpty);
      expect(game.lastMessage, contains('haggling'));
    });

    test('salePrice survives serialization', () {
      final car = Car(
        id: 'car-9',
        tier: CarTier.rare,
        stage: RestorationStage.detailed,
        purchasedAt: DateTime.fromMillisecondsSinceEpoch(0),
        salePrice: 1234,
      );
      final roundTripped = Car.fromJson(car.toJson());
      expect(roundTripped.salePrice, 1234);
      expect(roundTripped.effectiveSalePrice, 1234);
      // Legacy saves without a rolled price fall back to the tier price.
      final legacy = Car.fromJson({
        'id': 'old',
        'tier': 'common',
        'stage': 'detailed',
        'purchasedAt': '2026-01-01T00:00:00.000Z',
      });
      expect(legacy.effectiveSalePrice, CarTier.common.salePrice);
    });
  });
}

class _FakeBackend implements GameBackend {
  int cash = 850;
  List<Car> cars = [];
  Set<String> collectionIds = {};
  int lifetimeEarnings = 0;

  /// Mirrors the server's buyCar rules so controller wiring is testable.
  @override
  Future<CarTransactionResult> buyCar({required CarTier tier}) async {
    if (cash < tier.purchasePrice) {
      return CarTransactionResult(
        accepted: false,
        cash: cash,
        cars: List.of(cars),
        collectionIds: Set.of(collectionIds),
        message: 'Not enough cash for that wreck.',
      );
    }
    cash -= tier.purchasePrice;
    final car = Car(
      id: 'fake-${cars.length}-${DateTime.now().microsecondsSinceEpoch}',
      tier: tier,
      stage: RestorationStage.wrecked,
      purchasedAt: DateTime.now().toUtc(),
      modelId: 'sunny_hatch',
      salePrice: tier.salePrice + 10,
    );
    cars = [...cars, car];
    return CarTransactionResult(
      accepted: true,
      cash: cash,
      cars: List.of(cars),
      collectionIds: Set.of(collectionIds),
    );
  }

  @override
  Future<CarTransactionResult> advanceCarStage({required String carId}) async {
    final index = cars.indexWhere((car) => car.id == carId);
    if (index < 0) {
      return CarTransactionResult(
        accepted: false,
        cash: cash,
        cars: List.of(cars),
        collectionIds: Set.of(collectionIds),
      );
    }
    final car = cars[index];
    final next = car.stage.next;
    if (next == null || cash < car.restorationCost) {
      return CarTransactionResult(
        accepted: false,
        cash: cash,
        cars: List.of(cars),
        collectionIds: Set.of(collectionIds),
        message: 'Could not start that job.',
      );
    }
    cash -= car.restorationCost;
    final updated = car.copyWith(
      stage: next,
      stageStartedAt: next == RestorationStage.detailed
          ? null
          : DateTime.now().toUtc(),
    );
    cars = cars.map((item) => item.id == carId ? updated : item).toList();
    if (next == RestorationStage.detailed) {
      collectionIds = {...collectionIds, car.model.id};
    }
    return CarTransactionResult(
      accepted: true,
      cash: cash,
      cars: List.of(cars),
      collectionIds: Set.of(collectionIds),
    );
  }

  @override
  Future<SellResult> sellCar({
    required String carId,
    required bool haggled,
  }) async {
    final car = cars.firstWhere((item) => item.id == carId);
    final earnings = (car.effectiveSalePrice * (haggled ? 1.1 : 1)).floor();
    cash += earnings;
    lifetimeEarnings += earnings;
    cars = cars.where((item) => item.id != carId).toList();
    return SellResult(
      accepted: true,
      cash: cash,
      cars: List.of(cars),
      earnings: earnings,
      lifetimeEarnings: lifetimeEarnings,
    );
  }
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
    int? rewardAmount,
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
