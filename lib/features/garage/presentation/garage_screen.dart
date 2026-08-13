import 'package:flutter/material.dart';

import '../../../services/game_backend.dart';
import '../model/car.dart';
import '../state/game_controller.dart';
import '../widgets/car_sprite.dart';
import 'phase4_widgets.dart';
import 'phase5_widgets.dart';
import 'phase6_widgets.dart';

class GarageScreen extends StatefulWidget {
  const GarageScreen({required this.controller, super.key});

  final GameController controller;

  @override
  State<GarageScreen> createState() => _GarageScreenState();
}

class _GarageScreenState extends State<GarageScreen> {
  GameController get game => widget.controller;

  @override
  void initState() {
    super.initState();
    game.addListener(_onGameChanged);
  }

  @override
  void dispose() {
    game.removeListener(_onGameChanged);
    super.dispose();
  }

  void _onGameChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    if (game.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (game.welcomeBack != null) {
      return WelcomeBackScreen(
        result: game.welcomeBack!,
        onContinue: game.dismissWelcomeBack,
        onDoubleEarnings: game.watchDoubleOfflineEarnings,
      );
    }

    return Scaffold(
      backgroundColor: game.city.background,
      appBar: AppBar(
        backgroundColor: game.vipGaragePass
            ? const Color(0xFF6B4E1E)
            : const Color(0xFF27343A),
        foregroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.build_circle_rounded, color: Color(0xFFF2C14E)),
            SizedBox(width: 8),
            Text(
              'Rust & Riches',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ProfileStatsScreen(game: game)),
            ),
            icon: const Icon(Icons.person_rounded),
            tooltip: 'Profile and stats',
          ),
          if (game.canFranchise)
            IconButton(
              onPressed: () => showFranchiseDialog(context, game),
              icon: const Icon(Icons.public_rounded, color: Color(0xFFF2C14E)),
              tooltip: 'Franchise to a new city',
            ),
          Container(
            margin: const EdgeInsets.only(right: 14, top: 10, bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF405158),
              borderRadius: BorderRadius.circular(20),
            ),
            alignment: Alignment.center,
            child: Text(
              '\$${game.cash}',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFFF2C14E),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            _header(context),
            Phase6MonetizationPanel(game: game),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GarageShowroomScreen(
                          collectionIds: game.collectionIds,
                          vipGaragePass: game.vipGaragePass,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.grid_view_rounded),
                    label: const Text('Garage Showroom'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: game.refreshBarnFind,
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Check for Barn Find',
                ),
              ],
            ),
            if (game.barnFind != null) _barnFindCard(game.barnFind!),
            if (game.lastMessage != null) _messageBanner(game.lastMessage!),
            const SizedBox(height: 16),
            _sectionTitle(
              'Your garage',
              '${game.cars.length}/${GameController.maxGarageSlots} bays',
            ),
            const SizedBox(height: 10),
            if (game.cars.isEmpty)
              _emptyGarage()
            else
              ...game.cars.map(_carCard),
            const SizedBox(height: 22),
            _sectionTitle('Find a wreck', 'Buy low, restore high'),
            const SizedBox(height: 10),
            ...CarTier.values.map(_purchaseCard),
          ],
        ),
      ),
    );
  }

  Widget _barnFindCard(BarnFindOffer offer) => Card(
    color: const Color(0xFFFFF2D4),
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: Color(offer.model.color),
        child: const Icon(Icons.warehouse_rounded, color: Colors.white),
      ),
      title: Text(
        'Barn Find: ${offer.model.name}',
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      subtitle: Text(
        offer.model.isVintage
            ? 'Vintage discovery • Free timing game or \$${offer.discountedPrice}'
            : 'Rare discovery • Free timing game or \$${offer.discountedPrice}',
      ),
      trailing: FilledButton(
        onPressed: () => showBarnFindDialog(context, game),
        child: const Text('Open'),
      ),
    ),
  );

  Widget _header(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: game.city.accent,
      borderRadius: BorderRadius.circular(22),
    ),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome to the lot.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Turn tired metal into serious money.',
          style: TextStyle(color: Colors.white70, fontSize: 15),
        ),
      ],
    ),
  );

  Widget _messageBanner(String message) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Row(
      children: [
        const Icon(Icons.bolt_rounded, color: Color(0xFFE76F3C)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );

  Widget _sectionTitle(String title, String trailing) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w900,
          color: Color(0xFF27343A),
        ),
      ),
      Text(
        trailing,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: Color(0xFF7E8B88),
        ),
      ),
    ],
  );

  Widget _emptyGarage() => Container(
    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE4DDD0)),
    ),
    child: const Column(
      children: [
        Icon(Icons.garage_outlined, size: 42, color: Color(0xFFB9A993)),
        SizedBox(height: 8),
        Text(
          'Your bays are waiting.',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        SizedBox(height: 4),
        Text(
          'Buy a wreck below to start your first restoration.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF7E8B88)),
        ),
      ],
    ),
  );

  Widget _carCard(Car car) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${car.model.name} • ${car.tier.subtitle}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
              if (car.isBarnFind)
                const Chip(
                  label: Text('BARN FIND'),
                  backgroundColor: Color(0xFFF2C14E),
                ),
              const SizedBox(width: 6),
              _stageChip(car.stage),
            ],
          ),
          CarSprite(car: car),
          if (car.isRunning) ...[
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 4,
                children: [
                  if (!game.vipGaragePass)
                    TextButton.icon(
                      onPressed: () => game.watchFinishStage(car),
                      icon: const Icon(
                        Icons.play_circle_outline_rounded,
                        size: 18,
                      ),
                      label: const Text('Watch ad: finish now'),
                    ),
                  TextButton.icon(
                    onPressed: game.premiumCurrency >= 10
                        ? () => game.spendTimeSkip(car)
                        : null,
                    icon: const Icon(Icons.fast_forward_rounded, size: 18),
                    label: const Text('Skip 10'),
                  ),
                ],
              ),
            ),
            LinearProgressIndicator(
              value: car.progressAt(DateTime.now().toUtc()),
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
              color: const Color(0xFFE76F3C),
              backgroundColor: const Color(0xFFE9E2D7),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: car.stage.next == null || car.isRunning
                      ? null
                      : () => game.advanceStage(car),
                  icon: Icon(
                    car.stage.next == null
                        ? Icons.check_rounded
                        : Icons.build_rounded,
                  ),
                  label: Text(
                    car.stage.next == null
                        ? 'Restored'
                        : car.isRunning
                        ? 'Restoring ${car.stage.label.toLowerCase()}…'
                        : '${car.stage.actionLabel}  •  \$${car.restorationCost}',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF27343A),
                  ),
                ),
              ),
              if (car.stage == RestorationStage.detailed) ...[
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Sell for \$${car.tier.salePrice}',
                  onPressed: () => game.sell(car),
                  icon: const Icon(Icons.sell_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFE76F3C),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    ),
  );

  Widget _stageChip(RestorationStage stage) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: stage == RestorationStage.detailed
          ? const Color(0xFFDDF2D7)
          : const Color(0xFFFFE7B0),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(
      stage.label,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
    ),
  );

  Widget _purchaseCard(CarTier tier) => Card(
    margin: const EdgeInsets.only(bottom: 9),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: tier == CarTier.common
            ? const Color(0xFFD8E8EE)
            : tier == CarTier.rare
            ? const Color(0xFFF8D5CB)
            : const Color(0xFFF4E6B5),
        child: Icon(
          tier == CarTier.classic
              ? Icons.star_rounded
              : Icons.directions_car_rounded,
          color: const Color(0xFF27343A),
        ),
      ),
      title: Text(
        tier.label,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${tier.subtitle}  •  Sells for \$${tier.salePrice}'),
          AppraiserPreview(appraisal: game.appraise(tier)),
        ],
      ),
      trailing: FilledButton(
        onPressed: game.canBuy(tier) ? () => game.buy(tier) : null,
        child: Text('Buy \$${tier.purchasePrice}'),
      ),
    ),
  );
}

class WelcomeBackScreen extends StatelessWidget {
  const WelcomeBackScreen({
    required this.result,
    required this.onContinue,
    required this.onDoubleEarnings,
    super.key,
  });

  final IdleCatchUp result;
  final VoidCallback onContinue;
  final VoidCallback onDoubleEarnings;

  @override
  Widget build(BuildContext context) {
    final hours = result.elapsedSeconds ~/ 3600;
    final minutes = (result.elapsedSeconds % 3600) ~/ 60;
    final away = hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';

    return Scaffold(
      backgroundColor: const Color(0xFF27343A),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.wb_sunny_rounded,
                  size: 64,
                  color: Color(0xFFF2C14E),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Welcome back, boss.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'The garage kept working while you were away for $away.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 28),
                _summaryTile(
                  Icons.auto_awesome_rounded,
                  '${result.finishedCarCount}',
                  'cars finished restoring',
                ),
                const SizedBox(height: 10),
                _summaryTile(
                  Icons.attach_money_rounded,
                  '\$${result.cashEarned}',
                  'cash earned from completed cars',
                ),
                if (result.cashEarned > 0) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onDoubleEarnings,
                      icon: const Icon(Icons.ondemand_video_rounded),
                      label: const Text('Watch ad to double offline cash'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFF2C14E),
                        side: const BorderSide(color: Color(0xFFF2C14E)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onContinue,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE76F3C),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Back to the garage',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _summaryTile(IconData icon, String value, String label) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFF405158),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        Icon(icon, color: const Color(0xFFF2C14E), size: 28),
        const SizedBox(width: 14),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}
