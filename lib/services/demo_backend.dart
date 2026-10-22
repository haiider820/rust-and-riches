import 'dart:math';

import '../features/garage/model/appraiser.dart';
import '../features/garage/model/car.dart';
import '../features/garage/model/progression.dart';
import 'ad_service.dart';
import 'game_backend.dart';

/// In-memory backend used for the interactive web preview
/// (`flutter build web --dart-define=DEMO=true`) and as a graceful fallback
/// when Firebase cannot be reached. Mirrors the Cloud Functions rules in
/// `functions/index.js` so the demo behaves like the real game.
class DemoBackend implements GameBackend {
  DemoBackend({Random? random}) : _random = random ?? Random() {
    // Demo starts pre-seeded so the preview shows every feature immediately.
    _offer = _createOffer();
  }

  final Random _random;

  int cash = 850;
  List<Car> cars = [];
  Set<String> collectionIds = {};
  int lifetimeEarnings = 0;
  int reputationPoints = 0;
  int prestigeCount = 0;
  String cityId = cityThemes.first.id;
  int lotLevel = 1;
  int toolLevel = 1;
  int premiumCurrency = 0;
  bool vipGaragePass = false;
  BarnFindOffer? _offer;
  int _lastIdleCashEarned = 0;
  final Set<String> _claimedRewards = {};

  double get _reputationMultiplier =>
      (1 + reputationPoints * 0.1) * (vipGaragePass ? 1.2 : 1);

  static const _barnFindModels = [
    ('golden_v8', CarTier.classic, 950, true),
    ('velvet_cruiser', CarTier.classic, 950, true),
    ('heritage_special', CarTier.classic, 950, true),
    ('midnight_gt', CarTier.rare, 420, false),
    ('redline_coupe', CarTier.rare, 420, false),
    ('coastal_roadster', CarTier.rare, 420, false),
  ];

  static const _modelsByTier = {
    CarTier.common: ['sunny_hatch', 'boxy_wagon', 'rust_runner'],
    CarTier.rare: ['midnight_gt', 'redline_coupe', 'coastal_roadster'],
    CarTier.classic: ['golden_v8', 'velvet_cruiser', 'heritage_special'],
  };

  BarnFindOffer _createOffer() {
    final model = _barnFindModels[_random.nextInt(_barnFindModels.length)];
    return BarnFindOffer(
      id: 'demo-barn-${DateTime.now().microsecondsSinceEpoch}',
      modelId: model.$1,
      discountedPrice: (model.$3 * 0.55).floor(),
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
      attempts: 3,
      targetStart: 0.35 + _random.nextDouble() * 0.25,
      targetWidth: 0.18,
    );
  }

  @override
  Future<void> ensureAnonymousUser() async {}

  @override
  Future<GameRemoteState?> loadState() async {
    // The demo always returns a state (pre-seeded with a barn-find offer)
    // so the preview shows every feature on first launch.
    return GameRemoteState(
      cash: cash,
      cars: List.of(cars),
      collectionIds: Set.of(collectionIds),
      lifetimeEarnings: lifetimeEarnings,
      reputationPoints: reputationPoints,
      prestigeCount: prestigeCount,
      cityId: cityId,
      lotLevel: lotLevel,
      toolLevel: toolLevel,
      premiumCurrency: premiumCurrency,
      barnFind: _offer,
      vipGaragePass: vipGaragePass,
    );
  }

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
  }) async {
    this.cash = cash;
    this.cars = List.of(cars);
    this.collectionIds = Set.of(collectionIds);
    this.lifetimeEarnings = lifetimeEarnings;
    this.reputationPoints = reputationPoints;
    this.prestigeCount = prestigeCount;
    this.cityId = cityId;
    this.lotLevel = lotLevel;
    this.toolLevel = toolLevel;
    this.premiumCurrency = premiumCurrency;
  }

  @override
  Future<IdleCatchUp> catchUpOnOpen() async => IdleCatchUp(
    cash: cash,
    cars: List.of(cars),
    cashEarned: 0,
    finishedCarCount: 0,
    elapsedSeconds: 0,
  );

  @override
  Future<BarnFindOffer?> loadBarnFindOffer() async {
    final offer = _offer;
    if (offer != null && offer.expiresAt.isAfter(DateTime.now().toUtc())) {
      return offer;
    }
    // Demo: always have an offer handy so the preview shows the feature.
    _offer = _createOffer();
    return _offer;
  }

  @override
  Future<BarnFindClaimResult> claimBarnFind({
    required String offerId,
    required bool wonMinigame,
  }) async {
    final offer = _offer;
    if (offer == null || offer.id != offerId) {
      return const BarnFindClaimResult(
        accepted: false,
        cash: 0,
        cars: [],
        collectionIds: <String>{},
      );
    }
    final model = _barnFindModels.firstWhere(
      (item) => item.$1 == offer.modelId,
    );
    if (cars.length >= lotMaxBays(lotLevel) ||
        (!wonMinigame && cash < offer.discountedPrice)) {
      return BarnFindClaimResult(
        accepted: false,
        cash: cash,
        cars: List.of(cars),
        collectionIds: Set.of(collectionIds),
      );
    }
    if (!wonMinigame) cash -= offer.discountedPrice;
    final car = Car(
      id: 'demo-barn-${DateTime.now().microsecondsSinceEpoch}',
      tier: model.$2,
      stage: RestorationStage.wrecked,
      purchasedAt: DateTime.now().toUtc(),
      modelId: model.$1,
      isBarnFind: true,
      salePrice: rollAppraisedSalePrice(
        model.$2,
        model.$3,
        model.$4,
        random: _random,
      ),
    );
    cars = [...cars, car];
    _offer = null;
    return BarnFindClaimResult(
      accepted: true,
      cash: cash,
      cars: List.of(cars),
      collectionIds: Set.of(collectionIds),
    );
  }

  @override
  Future<FranchiseResult> franchise({required String targetCityId}) async {
    if (lifetimeEarnings < franchiseThreshold) {
      throw StateError('Franchise threshold not reached.');
    }
    final gained = 1 + reputationPoints * 0.05;
    cash = 850;
    cars = [];
    collectionIds = {};
    lifetimeEarnings = 0;
    reputationPoints += 2;
    prestigeCount += 1;
    cityId = targetCityId;
    lotLevel = 1;
    toolLevel = 1;
    _offer = null;
    return FranchiseResult(
      cash: cash,
      cars: const [],
      collectionIds: const <String>{},
      lifetimeEarnings: 0,
      reputationPoints: reputationPoints,
      prestigeCount: prestigeCount,
      cityId: cityId,
      lotLevel: 1,
      toolLevel: 1,
      multiplierGained: gained,
    );
  }

  @override
  Future<RewardClaimResult> claimReward({
    required String rewardId,
    required RewardKind kind,
    String? carId,
    int? rewardAmount,
  }) async {
    if (_claimedRewards.contains(rewardId)) {
      return RewardClaimResult(
        accepted: false,
        cash: cash,
        cars: List.of(cars),
      );
    }
    _claimedRewards.add(rewardId);
    switch (kind) {
      case RewardKind.doubleOfflineEarnings:
        cash += _lastIdleCashEarned;
        _lastIdleCashEarned = 0;
      case RewardKind.finishRestoration:
        final index = cars.indexWhere((car) => car.id == carId);
        if (index >= 0) {
          final car = cars[index];
          final next = car.stage.next;
          if (next != null) {
            cars = cars
                .map(
                  (item) => item.id == carId
                      ? item.copyWith(stage: next, stageStartedAt: null)
                      : item,
                )
                .toList();
          }
        }
      case RewardKind.missionBonus:
        cash += (rewardAmount ?? 0).clamp(50, 500);
    }
    return RewardClaimResult(
      accepted: true,
      cash: cash,
      cars: List.of(cars),
    );
  }

  @override
  Future<ConsumableGrantResult> grantConsumable({
    required String transactionId,
    required ConsumableKind kind,
  }) async {
    if (_claimedRewards.contains(transactionId)) {
      return ConsumableGrantResult(
        accepted: false,
        premiumCurrency: premiumCurrency,
        barnFindOffer: _offer,
      );
    }
    _claimedRewards.add(transactionId);
    premiumCurrency += kind == ConsumableKind.timeSkip ? 50 : 75;
    if (kind == ConsumableKind.barnFindBundle) _offer ??= _createOffer();
    return ConsumableGrantResult(
      accepted: true,
      premiumCurrency: premiumCurrency,
      barnFindOffer: _offer,
    );
  }

  @override
  Future<void> syncVipStatus({required bool active}) async {
    vipGaragePass = active;
  }

  @override
  Future<RewardClaimResult> spendPremiumTimeSkip({
    required String carId,
  }) async {
    if (premiumCurrency < 10) {
      return RewardClaimResult(
        accepted: false,
        cash: cash,
        cars: List.of(cars),
      );
    }
    final index = cars.indexWhere((car) => car.id == carId);
    if (index < 0) {
      return RewardClaimResult(
        accepted: false,
        cash: cash,
        cars: List.of(cars),
      );
    }
    final next = cars[index].stage.next;
    if (next == null) {
      return RewardClaimResult(
        accepted: false,
        cash: cash,
        cars: List.of(cars),
      );
    }
    premiumCurrency -= 10;
    cars = cars
        .map(
          (item) => item.id == carId
              ? item.copyWith(stage: next, stageStartedAt: null)
              : item,
        )
        .toList();
    return RewardClaimResult(
      accepted: true,
      cash: cash,
      cars: List.of(cars),
      premiumCurrency: premiumCurrency,
    );
  }

  CarTransactionResult _tx(bool accepted, [String? message]) =>
      CarTransactionResult(
        accepted: accepted,
        cash: cash,
        cars: List.of(cars),
        collectionIds: Set.of(collectionIds),
        message: message,
      );

  @override
  Future<CarTransactionResult> buyCar({required CarTier tier}) async {
    if (cars.length >= lotMaxBays(lotLevel)) {
      return _tx(false, 'All garage bays are occupied.');
    }
    if (cash < tier.purchasePrice) {
      return _tx(false, 'Not enough cash for that wreck.');
    }
    cash -= tier.purchasePrice;
    final models = _modelsByTier[tier]!;
    final modelId = models[_random.nextInt(models.length)];
    cars = [
      ...cars,
      Car(
        id: 'demo-car-${DateTime.now().microsecondsSinceEpoch}',
        tier: tier,
        stage: RestorationStage.wrecked,
        purchasedAt: DateTime.now().toUtc(),
        modelId: modelId,
        salePrice: rollAppraisedSalePrice(
          tier,
          tier.purchasePrice,
          false,
          random: _random,
        ),
      ),
    ];
    return _tx(true);
  }

  @override
  Future<CarTransactionResult> advanceCarStage({required String carId}) async {
    final index = cars.indexWhere((car) => car.id == carId);
    if (index < 0) return _tx(false, 'That car is not in your garage.');
    final car = cars[index];
    final next = car.stage.next;
    if (next == null) {
      return _tx(false, 'That car is already fully restored.');
    }
    const costs = {
      RestorationStage.wrecked: 25,
      RestorationStage.stripped: 55,
      RestorationStage.repaired: 70,
      RestorationStage.painted: 40,
      RestorationStage.detailed: 0,
    };
    final cost = costs[car.stage] ?? 0;
    if (cash < cost) return _tx(false, 'Not enough cash for this job.');
    cash -= cost;
    cars = cars
        .map(
          (item) => item.id == carId
              ? item.copyWith(
                  stage: next,
                  stageStartedAt: next == RestorationStage.detailed
                      ? null
                      : DateTime.now().toUtc(),
                )
              : item,
        )
        .toList();
    if (next == RestorationStage.detailed && car.modelId != null) {
      collectionIds = {...collectionIds, car.modelId!};
    }
    return _tx(true);
  }

  @override
  Future<SellResult> sellCar({
    required String carId,
    required bool haggled,
  }) async {
    final index = cars.indexWhere((car) => car.id == carId);
    if (index < 0 || cars[index].stage != RestorationStage.detailed) {
      return SellResult(
        accepted: false,
        cash: cash,
        cars: List.of(cars),
        earnings: 0,
        lifetimeEarnings: lifetimeEarnings,
        message: 'That car is not ready to sell.',
      );
    }
    final car = cars[index];
    final earnings =
        (car.effectiveSalePrice * _reputationMultiplier * (haggled ? 1.1 : 1))
            .floor();
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
}

/// Demo ad service: "watching" an ad takes a moment, then the reward is
/// granted through the demo backend. Interstitials are skipped in the demo.
class DemoAdService extends AdService {
  DemoAdService(this.backend) : super(backend);

  final DemoBackend backend;

  @override
  Future<RewardClaimResult?> showRewarded({
    required RewardKind kind,
    String? carId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    return backend.claimReward(
      rewardId: 'demo-${DateTime.now().microsecondsSinceEpoch}',
      kind: kind,
      carId: carId,
    );
  }

  @override
  Future<bool> maybeShowInterstitial({
    required bool isRestoring,
    required bool isSelling,
  }) async => false;
}
