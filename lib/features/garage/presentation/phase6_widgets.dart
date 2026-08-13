import 'package:flutter/material.dart';

import '../model/appraiser.dart';
import '../model/car.dart';
import '../state/game_controller.dart';

class Phase6MonetizationPanel extends StatelessWidget {
  const Phase6MonetizationPanel({required this.game, super.key});
  final GameController game;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: game.vipGaragePass ? const Color(0xFFFFF1C7) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  game.vipGaragePass
                      ? Icons.workspace_premium_rounded
                      : Icons.local_offer_outlined,
                  color: const Color(0xFFC99325),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    game.vipGaragePass
                        ? 'VIP Garage Pass active'
                        : 'Garage extras',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                Text(
                  '◆ ${game.premiumCurrency}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF7B61B5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              game.vipGaragePass
                  ? '+20% income - no ad cooldowns - auto-collected offline earnings'
                  : 'Optional purchases. The core garage loop remains playable without them.',
              style: const TextStyle(color: Color(0xFF687875)),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (!game.vipGaragePass)
                  OutlinedButton.icon(
                    onPressed: () => showVipPurchaseDialog(context, game),
                    icon: const Icon(Icons.workspace_premium_rounded, size: 18),
                    label: const Text('VIP Pass'),
                  ),
                OutlinedButton.icon(
                  onPressed: () => game.purchaseTimeSkipBundle(),
                  icon: const Icon(Icons.fast_forward_rounded, size: 18),
                  label: const Text('Time skips'),
                ),
                OutlinedButton.icon(
                  onPressed: () => game.purchaseBarnFindBundle(),
                  icon: const Icon(Icons.warehouse_rounded, size: 18),
                  label: const Text('Barn Find bundle'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AppraiserPreview extends StatelessWidget {
  const AppraiserPreview({required this.appraisal, super.key});
  final Appraisal appraisal;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF2EDF9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.analytics_rounded,
            color: Color(0xFF7B61B5),
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Appraiser: profit range ${appraisal.lowProfit}-${appraisal.highProfit}. Suggested order: ${formatStageOrder(appraisal)}. ${appraisal.summary}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF4B4262)),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showVipPurchaseDialog(
  BuildContext context,
  GameController game,
) async {
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('VIP Garage Pass'),
      content: const Text(
        'VIP adds +20% permanent income, removes rewarded-ad cooldowns, silently collects offline earnings, and unlocks an exclusive gold garage theme. Subscription renews automatically unless cancelled in your App Store or Google Play account settings.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Not now'),
        ),
        TextButton(
          onPressed: () async {
            await game.restoreVipPass();
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Restore'),
        ),
        FilledButton(
          onPressed: () async {
            await game.purchaseVipPass();
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Continue'),
        ),
      ],
    ),
  );
}

String formatStageOrder(Appraisal appraisal) =>
    appraisal.suggestedOrder.map((stage) => stage.label).join(' -> ');

String tierShortLabel(CarTier tier) => tier.label;
