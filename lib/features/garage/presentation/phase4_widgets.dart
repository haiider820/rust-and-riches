import 'dart:async';

import 'package:flutter/material.dart';

import '../model/car.dart';
import '../state/game_controller.dart';
import '../widgets/car_sprite.dart';

Future<void> showBarnFindDialog(
  BuildContext context,
  GameController game,
) async {
  final offer = game.barnFind;
  if (offer == null) return;
  await showDialog<void>(
    context: context,
    builder: (_) => _BarnFindDialog(game: game, offer: offer),
  );
}

class _BarnFindDialog extends StatefulWidget {
  const _BarnFindDialog({required this.game, required this.offer});
  final GameController game;
  final BarnFindOffer offer;

  @override
  State<_BarnFindDialog> createState() => _BarnFindDialogState();
}

class _BarnFindDialogState extends State<_BarnFindDialog> {
  Timer? _timer;
  double marker = 0;
  int attemptsLeft = 3;
  bool running = true;
  String status = 'Tap STOP when the marker is inside the gold zone.';

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 24), (_) {
      if (!mounted || !running) return;
      setState(() => marker = (marker + .014) % 1);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _stop() async {
    if (!running) return;
    final hit =
        marker >= widget.offer.targetStart &&
        marker <= widget.offer.targetStart + widget.offer.targetWidth;
    attemptsLeft--;
    if (hit) {
      setState(() {
        running = false;
        status = 'Perfect timing. Your Barn Find is free.';
      });
      await widget.game.claimBarnFind(wonMinigame: true);
      if (mounted) Navigator.pop(context);
    } else if (attemptsLeft == 0) {
      setState(() {
        running = false;
        status = 'The timing run is over. You can still buy it for cash.';
      });
    } else {
      setState(
        () => status =
            'Missed. $attemptsLeft attempts left. Keep watching the marker.',
      );
    }
  }

  Future<void> _buy() async {
    await widget.game.claimBarnFind(wonMinigame: false);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.offer.model;
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.warehouse_rounded, color: Color(0xFFE76F3C)),
          const SizedBox(width: 8),
          Text('Barn Find: ${model.name}'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Color(model.color).withValues(alpha: .18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.local_shipping_rounded, color: Color(model.color)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    model.isVintage
                        ? 'Vintage survivor • Classic rarity'
                        : 'Rare roadside discovery',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 28,
            child: LayoutBuilder(
              builder: (_, constraints) => Stack(
                children: [
                  Positioned(
                    left: constraints.maxWidth * widget.offer.targetStart,
                    top: 4,
                    width: constraints.maxWidth * widget.offer.targetWidth,
                    height: 20,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2C14E),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  Positioned(
                    left: (constraints.maxWidth - 8) * marker,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFF27343A),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            status,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _buy,
          child: Text('Buy for \$${widget.offer.discountedPrice}'),
        ),
        FilledButton(
          onPressed: running ? _stop : null,
          child: Text(running ? 'STOP ($attemptsLeft)' : 'STOP'),
        ),
      ],
    );
  }
}

class GarageShowroomScreen extends StatelessWidget {
  const GarageShowroomScreen({
    required this.collectionIds,
    this.vipGaragePass = false,
    super.key,
  });
  final Set<String> collectionIds;
  final bool vipGaragePass;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Garage Showroom'),
      backgroundColor: vipGaragePass
          ? const Color(0xFF6B4E1E)
          : const Color(0xFF27343A),
      foregroundColor: Colors.white,
    ),
    body: SafeArea(
      child: ColoredBox(
        color: vipGaragePass ? const Color(0xFFFFF8E5) : Colors.white,
        child: GridView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: carModelCatalog.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: .88,
          ),
          itemBuilder: (_, index) {
            final model = carModelCatalog[index];
            final discovered = collectionIds.contains(model.id);
            final preview = Car(
              id: model.id,
              tier: model.tier,
              stage: RestorationStage.detailed,
              purchasedAt: DateTime.fromMillisecondsSinceEpoch(0),
              modelId: model.id,
            );
            return Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Expanded(
                    child: discovered
                        ? CarSprite(car: preview)
                        : Stack(
                            children: [
                              CarSprite(car: preview),
                              Positioned.fill(
                                child: ColoredBox(color: Colors.white54),
                              ),
                              const Center(
                                child: Icon(
                                  Icons.lock_rounded,
                                  size: 34,
                                  color: Color(0xFF27343A),
                                ),
                              ),
                            ],
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            discovered ? model.name : 'Undiscovered',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        if (model.isVintage)
                          const Icon(
                            Icons.auto_awesome_rounded,
                            size: 17,
                            color: Color(0xFFE76F3C),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
}
