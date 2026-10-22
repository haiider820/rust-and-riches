import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../model/car.dart';
import '../model/progression.dart';
import '../state/game_controller.dart';

Future<void> showFranchiseDialog(
  BuildContext context,
  GameController game,
) async {
  if (!game.canFranchise) return;
  var selectedCity =
      cityThemes[(game.prestigeCount + 1) % cityThemes.length].id;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) {
        final target = cityThemeFor(selectedCity);
        return AlertDialog(
          title: const Text('Franchise to a new city?'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Your garage empire is ready to expand. Choose a new palette for the next chapter.',
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: selectedCity,
                  decoration: const InputDecoration(labelText: 'New city'),
                  items: cityThemes
                      .where((theme) => theme.id != game.cityId)
                      .map(
                        (theme) => DropdownMenuItem(
                          value: theme.id,
                          child: Text(theme.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => selectedCity = value);
                  },
                ),
                const SizedBox(height: 16),
                _heading('Resets'),
                const Text(
                  'Cash, owned cars, lot upgrades, and tool upgrades return to their starting values.',
                ),
                const SizedBox(height: 10),
                _heading('Carries over'),
                Text(
                  'Your ${game.collectionIds.length} discovered cars, lifetime earnings, and franchise history stay with you.',
                ),
                const SizedBox(height: 10),
                _heading('Permanent reward'),
                Text(
                  'Reputation Points: ${game.reputationPoints} → ${game.reputationPoints + 1}\nCash multiplier: ${game.earningsMultiplier.toStringAsFixed(1)}× → ${reputationMultiplierFor(game.reputationPoints + 1).toStringAsFixed(1)}×',
                ),
                const SizedBox(height: 10),
                Text(
                  'New look: ${target.name}',
                  style: TextStyle(
                    color: target.accent,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Not yet'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await game.franchise(selectedCity);
              },
              child: const Text('Franchise'),
            ),
          ],
        );
      },
    ),
  );
}

Widget _heading(String value) => Padding(
  padding: const EdgeInsets.only(bottom: 3),
  child: Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
);

class ProfileStatsScreen extends StatelessWidget {
  const ProfileStatsScreen({required this.game, super.key});
  final GameController game;

  @override
  Widget build(BuildContext context) {
    final theme = game.city;
    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: const Color(0xFF27343A),
        foregroundColor: Colors.white,
        title: const Text('Profile & Stats'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: theme.surface,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      game.city.name,
                      style: TextStyle(
                        color: theme.accent,
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Franchise ${game.prestigeCount} • Reputation ${game.reputationPoints}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '${game.earningsMultiplier.toStringAsFixed(1)}× earnings multiplier',
                      style: TextStyle(
                        fontSize: 18,
                        color: theme.accent,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _stat('Lifetime earnings', '\$${game.lifetimeEarnings}'),
            _stat('Franchises launched', '${game.prestigeCount}'),
            _stat('Reputation Points', '${game.reputationPoints}'),
            _stat(
              'Cars discovered',
              '${game.collectionIds.length} / ${carModelCatalog.length}',
            ),
            _stat('Current lot level', '${game.lotLevel}'),
            _stat('Current tool level', '${game.toolLevel}'),
            const SizedBox(height: 12),
            _accountCard(context),
          ],
        ),
      ),
    );
  }

  /// Upgrade the anonymous account to a Google-linked account so progress
  /// survives reinstalls. Graceful when Firebase/Google sign-in is not
  /// configured yet (demo mode, placeholder firebase_options).
  Widget _accountCard(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Save your garage',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 6),
          const Text(
            'Link a Google account to keep your progress if you reinstall.',
            style: TextStyle(fontSize: 13, color: Color(0xFF5A6663)),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _linkGoogle(context),
            icon: const Icon(Icons.account_circle_rounded),
            label: const Text('Link Google account'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF27343A),
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _linkGoogle(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final signIn = GoogleSignIn.instance;
      await signIn.initialize();
      final account = await signIn.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) throw StateError('No ID token.');
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      await FirebaseAuth.instance.currentUser?.linkWithCredential(credential);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Google account linked — progress is safe.'),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Account linking needs the production Firebase + Google sign-in setup.',
          ),
        ),
      );
    }
  }

  Widget _stat(String label, String value) => Card(
    child: ListTile(
      title: Text(label),
      trailing: Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
    ),
  );
}
