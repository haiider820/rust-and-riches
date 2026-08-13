import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../features/garage/model/car.dart';
import '../features/garage/model/progression.dart';
import 'game_backend.dart';

class FirebaseGameService implements GameBackend {
  FirebaseGameService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _functions = functions ?? FirebaseFunctions.instance;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  @override
  Future<void> ensureAnonymousUser() async {
    if (_auth.currentUser == null) await _auth.signInAnonymously();
  }

  DocumentReference<Map<String, dynamic>> get _stateRef =>
      _firestore.collection('players').doc(_auth.currentUser!.uid);

  @override
  Future<GameRemoteState?> loadState() async {
    final data = (await _stateRef.get()).data();
    if (data == null) return null;
    final rawOffer = data['barnFind'] as Map<String, dynamic>?;
    return GameRemoteState(
      cash: (data['cash'] as num?)?.toInt() ?? 850,
      cars: _decodeCars(data['cars']),
      collectionIds: {
        ...(data['collectionIds'] as List<dynamic>? ?? const []).cast<String>(),
      },
      lifetimeEarnings: (data['lifetimeEarnings'] as num?)?.toInt() ?? 0,
      reputationPoints: (data['reputationPoints'] as num?)?.toInt() ?? 0,
      prestigeCount: (data['prestigeCount'] as num?)?.toInt() ?? 0,
      cityId: data['cityId'] as String? ?? cityThemes.first.id,
      lotLevel: (data['lotLevel'] as num?)?.toInt() ?? 1,
      toolLevel: (data['toolLevel'] as num?)?.toInt() ?? 1,
      premiumCurrency: (data['premiumCurrency'] as num?)?.toInt() ?? 0,
      vipGaragePass: data['vipGaragePass'] == true,
      barnFind: rawOffer == null ? null : BarnFindOffer.fromJson(rawOffer),
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
    await _stateRef.set({
      'cash': cash,
      'cars': cars.map((car) => car.toJson()).toList(),
      'collectionIds': collectionIds.toList(),
      'lifetimeEarnings': lifetimeEarnings,
      'reputationPoints': reputationPoints,
      'prestigeCount': prestigeCount,
      'cityId': cityId,
      'lotLevel': lotLevel,
      'toolLevel': toolLevel,
      'premiumCurrency': premiumCurrency,
      'lastSavedAt': FieldValue.serverTimestamp(),
      'schemaVersion': 6,
    }, SetOptions(merge: true));
  }

  @override
  Future<void> syncVipStatus({required bool active}) async {
    await _stateRef.set({
      'vipGaragePass': active,
      'vipUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<RewardClaimResult> spendPremiumTimeSkip({
    required String carId,
  }) async {
    final data = Map<String, dynamic>.from(
      (await _functions.httpsCallable('spendPremiumTimeSkip').call({
            'carId': carId,
          })).data
          as Map,
    );
    return RewardClaimResult(
      accepted: data['accepted'] == true,
      cash: (data['cash'] as num).toInt(),
      cars: _decodeCars(data['cars']),
      premiumCurrency: (data['premiumCurrency'] as num?)?.toInt(),
    );
  }

  @override
  Future<FranchiseResult> franchise({required String targetCityId}) async {
    final data = Map<String, dynamic>.from(
      (await _functions.httpsCallable('franchisePlayer').call({
            'targetCityId': targetCityId,
          })).data
          as Map,
    );
    return FranchiseResult(
      cash: (data['cash'] as num).toInt(),
      cars: _decodeCars(data['cars']),
      collectionIds: {
        ...(data['collectionIds'] as List<dynamic>? ?? const []).cast<String>(),
      },
      lifetimeEarnings: (data['lifetimeEarnings'] as num).toInt(),
      reputationPoints: (data['reputationPoints'] as num).toInt(),
      prestigeCount: (data['prestigeCount'] as num).toInt(),
      cityId: data['cityId'] as String,
      lotLevel: (data['lotLevel'] as num).toInt(),
      toolLevel: (data['toolLevel'] as num).toInt(),
      multiplierGained: (data['multiplierGained'] as num).toDouble(),
    );
  }

  @override
  Future<ConsumableGrantResult> grantConsumable({
    required String transactionId,
    required ConsumableKind kind,
  }) async {
    final data = Map<String, dynamic>.from(
      (await _functions.httpsCallable('grantConsumable').call({
            'transactionId': transactionId,
            'kind': kind.name,
          })).data
          as Map,
    );
    final rawOffer = data['barnFindOffer'];
    return ConsumableGrantResult(
      accepted: data['accepted'] == true,
      premiumCurrency: (data['premiumCurrency'] as num?)?.toInt() ?? 0,
      barnFindOffer: rawOffer == null
          ? null
          : BarnFindOffer.fromJson(Map<String, dynamic>.from(rawOffer as Map)),
    );
  }

  @override
  Future<BarnFindOffer?> loadBarnFindOffer() async {
    final data = Map<String, dynamic>.from(
      (await _functions.httpsCallable('getBarnFindOffer').call<void>({})).data
          as Map,
    );
    final offer = data['offer'];
    return offer == null
        ? null
        : BarnFindOffer.fromJson(Map<String, dynamic>.from(offer as Map));
  }

  @override
  Future<BarnFindClaimResult> claimBarnFind({
    required String offerId,
    required bool wonMinigame,
  }) async {
    final data = Map<String, dynamic>.from(
      (await _functions.httpsCallable('claimBarnFind').call({
            'offerId': offerId,
            'wonMinigame': wonMinigame,
          })).data
          as Map,
    );
    return BarnFindClaimResult(
      accepted: data['accepted'] == true,
      cash: (data['cash'] as num).toInt(),
      cars: _decodeCars(data['cars']),
      collectionIds: {
        ...(data['collectionIds'] as List<dynamic>? ?? const []).cast<String>(),
      },
    );
  }

  @override
  Future<RewardClaimResult> claimReward({
    required String rewardId,
    required RewardKind kind,
    String? carId,
  }) async {
    final data = Map<String, dynamic>.from(
      (await _functions.httpsCallable('claimReward').call({
            'rewardId': rewardId,
            'kind': kind.name,
            'carId': carId,
          })).data
          as Map,
    );
    return RewardClaimResult(
      accepted: data['accepted'] == true,
      cash: (data['cash'] as num).toInt(),
      cars: _decodeCars(data['cars']),
    );
  }

  @override
  Future<IdleCatchUp> catchUpOnOpen() async {
    final data = Map<String, dynamic>.from(
      (await _functions.httpsCallable('catchUpOnOpen').call<void>({})).data
          as Map,
    );
    return IdleCatchUp(
      cash: (data['cash'] as num).toInt(),
      cars: _decodeCars(data['cars']),
      cashEarned: (data['cashEarned'] as num).toInt(),
      finishedCarCount: (data['finishedCarCount'] as num).toInt(),
      elapsedSeconds: (data['elapsedSeconds'] as num).toInt(),
      vipAutoCollected: data['vipAutoCollected'] == true,
    );
  }

  List<Car> _decodeCars(dynamic rawCars) =>
      (rawCars as List<dynamic>? ?? const [])
          .map((raw) => Car.fromJson(Map<String, dynamic>.from(raw as Map)))
          .toList();
}
