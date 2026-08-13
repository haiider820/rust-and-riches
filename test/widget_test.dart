import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rust_riches/features/garage/model/car.dart';
import 'package:rust_riches/features/garage/presentation/garage_screen.dart';
import 'package:rust_riches/features/garage/state/game_controller.dart';
import 'package:rust_riches/services/game_backend.dart';

void main() {
  testWidgets('garage shell renders', (WidgetTester tester) async {
    final controller = GameController(_FakeBackend())
      ..isLoading = false
      ..cash = 850;

    await tester.pumpWidget(
      MaterialApp(home: GarageScreen(controller: controller)),
    );

    expect(find.text('Rust & Riches'), findsOneWidget);
    expect(find.text('Garage extras'), findsOneWidget);
  });
}

class _FakeBackend implements GameBackend {
  @override
  Future<void> ensureAnonymousUser() async {}

  @override
  Future<GameRemoteState?> loadState() async => const GameRemoteState(
    cash: 850,
    cars: [],
    collectionIds: <String>{},
    lifetimeEarnings: 0,
    reputationPoints: 0,
    prestigeCount: 0,
    cityId: 'sunset_valley',
    lotLevel: 1,
    toolLevel: 1,
    premiumCurrency: 0,
  );

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
    cash: 850,
    cars: [],
    collectionIds: <String>{},
  );

  @override
  Future<FranchiseResult> franchise({required String targetCityId}) async =>
      const FranchiseResult(
        cash: 850,
        cars: [],
        collectionIds: <String>{},
        lifetimeEarnings: 10000,
        reputationPoints: 1,
        prestigeCount: 1,
        cityId: 'harbor_point',
        lotLevel: 1,
        toolLevel: 1,
        multiplierGained: 1.1,
      );

  @override
  Future<RewardClaimResult> claimReward({
    required String rewardId,
    required RewardKind kind,
    String? carId,
  }) async => const RewardClaimResult(accepted: false, cash: 850, cars: []);

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
  }) async => const RewardClaimResult(
    accepted: false,
    cash: 850,
    cars: [],
    premiumCurrency: 0,
  );

  @override
  Future<IdleCatchUp> catchUpOnOpen() async => const IdleCatchUp(
    cash: 850,
    cars: [],
    cashEarned: 0,
    finishedCarCount: 0,
    elapsedSeconds: 0,
  );
}
