import 'package:flutter_test/flutter_test.dart';
import 'package:rust_riches/features/garage/model/appraiser.dart';
import 'package:rust_riches/features/garage/model/car.dart';

void main() {
  test('heuristic appraiser returns a profit range and repair-first order', () {
    const appraiser = HeuristicCarAppraiser();
    final appraisal = appraiser.evaluate(tier: CarTier.rare, isVintage: true);

    expect(appraisal.lowProfit, lessThan(appraisal.highProfit));
    expect(
      appraisal.suggestedOrder,
      equals([
        RestorationStage.repaired,
        RestorationStage.painted,
        RestorationStage.detailed,
      ]),
    );
    expect(appraisal.summary, contains('Vintage'));
  });
}
