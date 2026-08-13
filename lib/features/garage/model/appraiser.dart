import 'car.dart';

class Appraisal {
  const Appraisal({
    required this.lowProfit,
    required this.highProfit,
    required this.suggestedOrder,
    required this.summary,
  });
  final int lowProfit;
  final int highProfit;
  final List<RestorationStage> suggestedOrder;
  final String summary;
}

abstract interface class CarAppraiser {
  Appraisal evaluate({required CarTier tier, required bool isVintage});
}

/// Rules-based stand-in for a future on-device TFLite/ONNX model.
/// The UI depends only on [CarAppraiser], so model replacement stays isolated.
class HeuristicCarAppraiser implements CarAppraiser {
  const HeuristicCarAppraiser();

  @override
  Appraisal evaluate({required CarTier tier, required bool isVintage}) {
    final base = tier.salePrice - tier.purchasePrice;
    final rarityBonus = isVintage
        ? 90
        : tier == CarTier.classic
        ? 55
        : tier == CarTier.rare
        ? 30
        : 0;
    final low = ((base + rarityBonus) * .75).round();
    final high = ((base + rarityBonus) * 1.2).round();
    final order = <RestorationStage>[
      RestorationStage.repaired,
      RestorationStage.painted,
      RestorationStage.detailed,
    ];
    return Appraisal(
      lowProfit: low,
      highProfit: high,
      suggestedOrder: order,
      summary: isVintage
          ? 'Vintage trim rewards careful repair before the cosmetic pass.'
          : 'Repair first to protect the resale value, then finish the presentation work.',
    );
  }
}
