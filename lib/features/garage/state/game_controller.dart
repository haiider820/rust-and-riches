import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../services/ad_service.dart';
import '../../../services/game_backend.dart';
import '../../../services/revenuecat_service.dart';
import '../model/appraiser.dart';
import '../model/car.dart';
import '../model/progression.dart';

class GameController extends ChangeNotifier {
  GameController(
    this._service, {
    this.adService,
    this.revenueCat,
    this.appraiser = const HeuristicCarAppraiser(),
  });
  final GameBackend _service;
  final AdService? adService;
  final RevenueCatService? revenueCat;
  final CarAppraiser appraiser;
  int get maxGarageSlots => lotMaxBays(lotLevel);

  int cash = 0;
  List<Car> cars = const [];
  Set<String> collectionIds = <String>{};
  BarnFindOffer? barnFind;
  int lifetimeEarnings = 0;
  int reputationPoints = 0;
  int prestigeCount = 0;
  String cityId = cityThemes.first.id;
  int lotLevel = 1;
  int toolLevel = 1;
  int premiumCurrency = 0;
  bool vipGaragePass = false;
  bool isLoading = true;
  String? lastMessage;
  IdleCatchUp? welcomeBack;
  Timer? _ticker;
  Timer? _barnFindTimer;

  CityTheme get city => cityThemeFor(cityId);
  double get earningsMultiplier =>
      reputationMultiplierFor(reputationPoints) * (vipGaragePass ? 1.2 : 1);
  bool get canFranchise => lifetimeEarnings >= franchiseThreshold;
  Appraisal appraise(CarTier tier, {bool isVintage = false}) =>
      appraiser.evaluate(tier: tier, isVintage: isVintage);

  int? get lotUpgradePrice => lotUpgradeCost[lotLevel];
  int? get toolUpgradePrice => toolUpgradeCost[toolLevel];
  bool get canUpgradeLot =>
      lotUpgradePrice != null && cash >= lotUpgradePrice!;
  bool get canUpgradeTools =>
      toolUpgradePrice != null && cash >= toolUpgradePrice!;

  Future<void> upgradeLot() async {
    final price = lotUpgradePrice;
    if (price == null) {
      _setMessage('The lot is already at max level.');
      return;
    }
    if (cash < price) {
      _setMessage('You need \$$price cash for the lot upgrade.');
      return;
    }
    cash -= price;
    lotLevel++;
    _setMessage(
      'Lot upgraded to level $lotLevel — $maxGarageSlots garage bays now.',
    );
    await _persist();
  }

  Future<void> upgradeTools() async {
    final price = toolUpgradePrice;
    if (price == null) {
      _setMessage('Your tools are already top of the line.');
      return;
    }
    if (cash < price) {
      _setMessage('You need \$$price cash for the tool upgrade.');
      return;
    }
    cash -= price;
    toolLevel++;
    final faster = ((1 - toolDurationMultiplier(toolLevel)) * 100).round();
    _setMessage('Tools upgraded to level $toolLevel — $faster% faster work.');
    await _persist();
  }

  Future<void> load() async {
    await _service.ensureAnonymousUser();
    final existing = await _service.loadState();
    cash = existing?.cash ?? 850;
    cars = existing?.cars ?? const [];
    collectionIds = existing?.collectionIds ?? <String>{};
    barnFind = existing?.barnFind;
    lifetimeEarnings = existing?.lifetimeEarnings ?? 0;
    reputationPoints = existing?.reputationPoints ?? 0;
    prestigeCount = existing?.prestigeCount ?? 0;
    cityId = existing?.cityId ?? cityThemes.first.id;
    lotLevel = existing?.lotLevel ?? 1;
    toolLevel = existing?.toolLevel ?? 1;
    premiumCurrency = existing?.premiumCurrency ?? 0;
    vipGaragePass = revenueCat?.isConfigured == true
        ? revenueCat!.isVip
        : existing?.vipGaragePass ?? false;
    if (existing != null) {
      final catchUp = await _service.catchUpOnOpen();
      cash = catchUp.cash;
      cars = catchUp.cars;
      // VIP players receive the server-calculated idle result silently.
      welcomeBack = vipGaragePass ? null : catchUp;
      barnFind ??= await _service.loadBarnFindOffer();
    } else {
      await _persist();
    }
    if (revenueCat != null) {
      await _service.syncVipStatus(active: vipGaragePass);
    }
    isLoading = false;
    _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (cars.any((car) => car.isRunning)) notifyListeners();
    });
    _barnFindTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (barnFind == null) refreshBarnFind();
    });
    notifyListeners();
  }

  bool canBuy(CarTier tier) =>
      cars.length < maxGarageSlots && cash >= tier.purchasePrice;

  Future<void> buy(CarTier tier) async {
    if (cars.length >= maxGarageSlots) {
      _setMessage(
        'All $maxGarageSlots garage bays are occupied. Finish a car first.',
      );
      return;
    }
    if (cash < tier.purchasePrice) {
      _setMessage('Not enough cash for that wreck.');
      return;
    }
    final model = carModelCatalog.firstWhere(
      (item) => item.tier == tier && !item.isVintage,
    );
    final car = Car(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      tier: tier,
      stage: RestorationStage.wrecked,
      purchasedAt: DateTime.now().toUtc(),
      modelId: model.id,
    );
    cash -= tier.purchasePrice;
    cars = [...cars, car];
    _setMessage('${model.name} wreck delivered to the garage.');
    await _persist();
  }

  Future<void> advanceStage(Car car) async {
    final next = car.stage.next;
    if (next == null) return;
    if (car.stageStartedAt != null &&
        car.progressAt(DateTime.now().toUtc()) < 1) {
      _setMessage('This job is still in progress.');
      return;
    }
    if (cash < car.restorationCost) {
      _setMessage('You need ${car.restorationCost} more cash for this job.');
      return;
    }
    cash -= car.restorationCost;
    final updated = car.copyWith(
      stage: next,
      stageStartedAt: next == RestorationStage.detailed
          ? null
          : DateTime.now().toUtc(),
    );
    cars = cars.map((item) => item.id == car.id ? updated : item).toList();
    if (next == RestorationStage.detailed) {
      collectionIds = {...collectionIds, car.model.id};
    }
    _setMessage('${car.model.name} started ${next.label.toLowerCase()}.');
    await _persist();
  }

  Future<void> sell(Car car) async {
    if (car.stage != RestorationStage.detailed) return;
    final earnings = (car.tier.salePrice * earningsMultiplier).floor();
    cash += earnings;
    lifetimeEarnings += earnings;
    cars = cars.where((item) => item.id != car.id).toList();
    _setMessage('${car.model.name} sold for \$$earnings.');
    await _persist();
    // Natural break point for an interstitial. VIP players never see ads,
    // and the ad service itself enforces its cooldown.
    if (!vipGaragePass) {
      unawaited(
        adService?.maybeShowInterstitial(
          isRestoring: cars.any((item) => item.isRunning),
          isSelling: false,
        ),
      );
    }
  }

  Future<void> refreshBarnFind() async {
    barnFind = await _service.loadBarnFindOffer();
    notifyListeners();
  }

  Future<bool> claimBarnFind({required bool wonMinigame}) async {
    final offer = barnFind;
    if (offer == null) return false;
    try {
      final result = await _service.claimBarnFind(
        offerId: offer.id,
        wonMinigame: wonMinigame,
      );
      if (!result.accepted) return false;
      cash = result.cash;
      cars = result.cars;
      collectionIds = result.collectionIds;
      barnFind = null;
      _setMessage('${offer.model.name} Barn Find added to the garage.');
      return true;
    } catch (_) {
      _setMessage('That Barn Find is no longer available.');
      barnFind = null;
      notifyListeners();
      return false;
    }
  }

  Future<FranchiseResult?> franchise(String targetCityId) async {
    if (!canFranchise) return null;
    try {
      final result = await _service.franchise(targetCityId: targetCityId);
      cash = result.cash;
      cars = result.cars;
      collectionIds = result.collectionIds;
      lifetimeEarnings = result.lifetimeEarnings;
      reputationPoints = result.reputationPoints;
      prestigeCount = result.prestigeCount;
      cityId = result.cityId;
      lotLevel = result.lotLevel;
      toolLevel = result.toolLevel;
      barnFind = null;
      _setMessage('Franchise launched in ${cityThemeFor(cityId).name}.');
      return result;
    } catch (_) {
      _setMessage('Franchising is not available yet.');
      return null;
    }
  }

  Future<bool> purchaseVipPass() async {
    final service = revenueCat;
    if (service == null) return false;
    try {
      final active = await service.purchaseVip();
      if (active) {
        vipGaragePass = true;
        welcomeBack = null;
        await _service.syncVipStatus(active: true);
        _setMessage('VIP Garage Pass activated.');
      }
      return active;
    } catch (_) {
      _setMessage('VIP purchase was not completed.');
      return false;
    }
  }

  Future<bool> restoreVipPass() async {
    final service = revenueCat;
    if (service == null) return false;
    final active = await service.restorePurchases();
    vipGaragePass = active;
    await _service.syncVipStatus(active: active);
    notifyListeners();
    return active;
  }

  Future<bool> purchaseTimeSkipBundle() async {
    final service = revenueCat;
    if (service == null) return false;
    try {
      final result = await service.purchaseConsumable(
        packageId: RevenueCatService.timeSkipPackageId,
        kind: ConsumableKind.timeSkip,
        backend: _service,
      );
      if (result == null) return false;
      premiumCurrency = result.premiumCurrency;
      _setMessage('Time-skip currency added to your wallet.');
      return result.accepted;
    } catch (_) {
      _setMessage('The time-skip purchase was not completed.');
      return false;
    }
  }

  Future<bool> purchaseBarnFindBundle() async {
    final service = revenueCat;
    if (service == null) return false;
    try {
      final result = await service.purchaseConsumable(
        packageId: RevenueCatService.barnFindBundlePackageId,
        kind: ConsumableKind.barnFindBundle,
        backend: _service,
      );
      if (result == null) return false;
      premiumCurrency = result.premiumCurrency;
      barnFind ??= result.barnFindOffer;
      _setMessage('A guaranteed Barn Find offer is ready.');
      return result.accepted;
    } catch (_) {
      _setMessage('The Barn Find bundle purchase was not completed.');
      return false;
    }
  }

  Future<bool> spendTimeSkip(Car car) async {
    if (premiumCurrency < 10) {
      _setMessage('You need 10 premium currency for a time-skip.');
      return false;
    }
    try {
      final result = await _service.spendPremiumTimeSkip(carId: car.id);
      if (!result.accepted) return false;
      cars = result.cars;
      premiumCurrency = result.premiumCurrency ?? premiumCurrency - 10;
      _setMessage('${car.model.name} stage skipped instantly.');
      notifyListeners();
      return true;
    } catch (_) {
      _setMessage('That time-skip could not be confirmed.');
      return false;
    }
  }

  Future<void> saveForBackground() => _persist();

  Future<void> watchDoubleOfflineEarnings() async {
    final result = welcomeBack;
    final ads = adService;
    if (vipGaragePass ||
        result == null ||
        ads == null ||
        result.cashEarned <= 0) {
      return;
    }
    final claim = await ads.showRewarded(
      kind: RewardKind.doubleOfflineEarnings,
    );
    if (claim == null || !claim.accepted) {
      _setMessage('The reward could not be confirmed. Please try again.');
      return;
    }
    cash = claim.cash;
    cars = claim.cars;
    welcomeBack = IdleCatchUp(
      cash: cash,
      cars: cars,
      cashEarned: result.cashEarned * 2,
      finishedCarCount: result.finishedCarCount,
      elapsedSeconds: result.elapsedSeconds,
    );
    notifyListeners();
  }

  Future<void> watchFinishStage(Car car) async {
    final ads = adService;
    if (vipGaragePass || ads == null || !car.isRunning) return;
    final claim = await ads.showRewarded(
      kind: RewardKind.finishRestoration,
      carId: car.id,
    );
    if (claim == null || !claim.accepted) {
      _setMessage('The reward could not be confirmed. Please try again.');
      return;
    }
    cash = claim.cash;
    cars = claim.cars;
    _setMessage('${car.model.name} restoration stage finished instantly.');
    notifyListeners();
  }

  void dismissWelcomeBack() {
    welcomeBack = null;
    notifyListeners();
  }

  void _setMessage(String message) {
    lastMessage = message;
    notifyListeners();
  }

  Future<void> _persist() => _service.saveState(
    cash: cash,
    cars: cars,
    collectionIds: collectionIds,
    lifetimeEarnings: lifetimeEarnings,
    reputationPoints: reputationPoints,
    prestigeCount: prestigeCount,
    cityId: cityId,
    lotLevel: lotLevel,
    toolLevel: toolLevel,
    premiumCurrency: premiumCurrency,
  );

  @override
  void dispose() {
    _ticker?.cancel();
    _barnFindTimer?.cancel();
    adService?.dispose();
    super.dispose();
  }
}
