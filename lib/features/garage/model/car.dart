import 'dart:convert';

import 'progression.dart';

enum CarTier { common, rare, classic }

enum RestorationStage { wrecked, stripped, repaired, painted, detailed }

class CarModelDefinition {
  const CarModelDefinition({
    required this.id,
    required this.name,
    required this.tier,
    required this.color,
    this.isVintage = false,
  });

  final String id;
  final String name;
  final CarTier tier;
  final int color;
  final bool isVintage;
}

const carModelCatalog = <CarModelDefinition>[
  CarModelDefinition(
    id: 'sunny_hatch',
    name: 'Sunny Hatch',
    tier: CarTier.common,
    color: 0xFF7DB8D2,
  ),
  CarModelDefinition(
    id: 'boxy_wagon',
    name: 'Boxy Wagon',
    tier: CarTier.common,
    color: 0xFFE6A85C,
  ),
  CarModelDefinition(
    id: 'rust_runner',
    name: 'Rust Runner',
    tier: CarTier.common,
    color: 0xFFC96B4B,
  ),
  CarModelDefinition(
    id: 'midnight_gt',
    name: 'Midnight GT',
    tier: CarTier.rare,
    color: 0xFF6C79C7,
  ),
  CarModelDefinition(
    id: 'redline_coupe',
    name: 'Redline Coupe',
    tier: CarTier.rare,
    color: 0xFFE05C55,
  ),
  CarModelDefinition(
    id: 'coastal_roadster',
    name: 'Coastal Roadster',
    tier: CarTier.rare,
    color: 0xFF4DAF9A,
  ),
  CarModelDefinition(
    id: 'golden_v8',
    name: 'Golden V8',
    tier: CarTier.classic,
    color: 0xFFE4B84D,
    isVintage: true,
  ),
  CarModelDefinition(
    id: 'velvet_cruiser',
    name: 'Velvet Cruiser',
    tier: CarTier.classic,
    color: 0xFF9F6BAA,
    isVintage: true,
  ),
  CarModelDefinition(
    id: 'heritage_special',
    name: 'Heritage Special',
    tier: CarTier.classic,
    color: 0xFF6E9A78,
    isVintage: true,
  ),
];

CarModelDefinition modelForId(String id) => carModelCatalog.firstWhere(
  (model) => model.id == id,
  orElse: () => carModelCatalog.first,
);

extension CarTierX on CarTier {
  String get label => switch (this) {
    CarTier.common => 'Common',
    CarTier.rare => 'Rare',
    CarTier.classic => 'Classic',
  };

  String get subtitle => switch (this) {
    CarTier.common => 'Daily driver',
    CarTier.rare => 'Weekend rocket',
    CarTier.classic => 'Collector dream',
  };

  int get purchasePrice => switch (this) {
    CarTier.common => 120,
    CarTier.rare => 420,
    CarTier.classic => 950,
  };

  int get salePrice => switch (this) {
    CarTier.common => 360,
    CarTier.rare => 1180,
    CarTier.classic => 2900,
  };

  Duration durationFor(RestorationStage stage) => switch (this) {
    CarTier.common => const {
      RestorationStage.wrecked: Duration(seconds: 15),
      RestorationStage.stripped: Duration(seconds: 20),
      RestorationStage.repaired: Duration(seconds: 25),
      RestorationStage.painted: Duration(seconds: 12),
      RestorationStage.detailed: Duration(seconds: 1),
    }[stage]!,
    CarTier.rare => const {
      RestorationStage.wrecked: Duration(seconds: 25),
      RestorationStage.stripped: Duration(seconds: 35),
      RestorationStage.repaired: Duration(seconds: 40),
      RestorationStage.painted: Duration(seconds: 20),
      RestorationStage.detailed: Duration(seconds: 1),
    }[stage]!,
    CarTier.classic => const {
      RestorationStage.wrecked: Duration(seconds: 40),
      RestorationStage.stripped: Duration(seconds: 50),
      RestorationStage.repaired: Duration(seconds: 60),
      RestorationStage.painted: Duration(seconds: 30),
      RestorationStage.detailed: Duration(seconds: 1),
    }[stage]!,
  };
}

extension RestorationStageX on RestorationStage {
  String get label => switch (this) {
    RestorationStage.wrecked => 'Wrecked',
    RestorationStage.stripped => 'Stripped',
    RestorationStage.repaired => 'Repaired',
    RestorationStage.painted => 'Painted',
    RestorationStage.detailed => 'Detailed',
  };

  String get actionLabel => switch (this) {
    RestorationStage.wrecked => 'Start stripping',
    RestorationStage.stripped => 'Start repairs',
    RestorationStage.repaired => 'Start paint',
    RestorationStage.painted => 'Start detailing',
    RestorationStage.detailed => 'Ready to sell',
  };

  RestorationStage? get next => switch (this) {
    RestorationStage.wrecked => RestorationStage.stripped,
    RestorationStage.stripped => RestorationStage.repaired,
    RestorationStage.repaired => RestorationStage.painted,
    RestorationStage.painted => RestorationStage.detailed,
    RestorationStage.detailed => null,
  };
}

class BarnFindOffer {
  const BarnFindOffer({
    required this.id,
    required this.modelId,
    required this.discountedPrice,
    required this.expiresAt,
    required this.attempts,
    required this.targetStart,
    required this.targetWidth,
  });

  final String id;
  final String modelId;
  final int discountedPrice;
  final DateTime expiresAt;
  final int attempts;
  final double targetStart;
  final double targetWidth;

  CarModelDefinition get model => modelForId(modelId);

  Map<String, dynamic> toJson() => {
    'id': id,
    'modelId': modelId,
    'discountedPrice': discountedPrice,
    'expiresAt': expiresAt.toIso8601String(),
    'attempts': attempts,
    'targetStart': targetStart,
    'targetWidth': targetWidth,
  };

  factory BarnFindOffer.fromJson(Map<String, dynamic> json) => BarnFindOffer(
    id: json['id'] as String,
    modelId: json['modelId'] as String,
    discountedPrice: (json['discountedPrice'] as num).toInt(),
    expiresAt: DateTime.parse(json['expiresAt'] as String),
    attempts: (json['attempts'] as num?)?.toInt() ?? 3,
    targetStart: (json['targetStart'] as num?)?.toDouble() ?? .4,
    targetWidth: (json['targetWidth'] as num?)?.toDouble() ?? .2,
  );
}

class Car {
  const Car({
    required this.id,
    required this.tier,
    required this.stage,
    required this.purchasedAt,
    this.stageStartedAt,
    this.modelId,
    this.isBarnFind = false,
  });

  final String id;
  final CarTier tier;
  final RestorationStage stage;
  final DateTime purchasedAt;
  final DateTime? stageStartedAt;
  final String? modelId;
  final bool isBarnFind;

  CarModelDefinition get model => modelForId(modelId ?? '${tier.name}_default');
  int get restorationCost => switch (stage) {
    RestorationStage.wrecked => 25,
    RestorationStage.stripped => 55,
    RestorationStage.repaired => 70,
    RestorationStage.painted => 40,
    RestorationStage.detailed => 0,
  };
  Duration get stageDuration => tier.durationFor(stage);

  /// Stage duration after the player's tool-level speed bonus.
  Duration stageDurationFor(int toolLevel) => Duration(
    milliseconds:
        (stageDuration.inMilliseconds * toolDurationMultiplier(toolLevel))
            .round(),
  );

  double progressAt(DateTime now, {int toolLevel = 1}) {
    final started = stageStartedAt;
    if (started == null) return 0;
    final scaled = stageDurationFor(toolLevel);
    return ((now.difference(started).inMilliseconds /
                scaled.inMilliseconds)
            .clamp(0, 1))
        .toDouble();
  }

  bool get isRunning => stageStartedAt != null && stage.next != null;

  Car copyWith({RestorationStage? stage, DateTime? stageStartedAt}) => Car(
    id: id,
    tier: tier,
    stage: stage ?? this.stage,
    purchasedAt: purchasedAt,
    stageStartedAt: stageStartedAt,
    modelId: modelId,
    isBarnFind: isBarnFind,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'tier': tier.name,
    'stage': stage.name,
    'purchasedAt': purchasedAt.toIso8601String(),
    'stageStartedAt': stageStartedAt?.toIso8601String(),
    'modelId': modelId,
    'isBarnFind': isBarnFind,
  };

  factory Car.fromJson(Map<String, dynamic> json) => Car(
    id: json['id'] as String,
    tier: CarTier.values.byName(json['tier'] as String),
    stage: RestorationStage.values.byName(json['stage'] as String),
    purchasedAt: DateTime.parse(json['purchasedAt'] as String),
    stageStartedAt: json['stageStartedAt'] == null
        ? null
        : DateTime.parse(json['stageStartedAt'] as String),
    modelId: json['modelId'] as String?,
    isBarnFind: json['isBarnFind'] as bool? ?? false,
  );

  static String encodeList(List<Car> cars) =>
      jsonEncode(cars.map((car) => car.toJson()).toList());

  static List<Car> decodeList(String raw) => (jsonDecode(raw) as List<dynamic>)
      .map((item) => Car.fromJson(item as Map<String, dynamic>))
      .toList();
}
