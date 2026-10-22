import 'package:audioplayers/audioplayers.dart';
import 'dart:async';

/// Tiny sound-effects service. Sounds are short synthesized WAVs bundled in
/// `assets/sounds/`. Everything is fire-and-forget and guarded: audio must
/// never crash or block gameplay.
class SoundService {
  SoundService() {
    _player = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
    _music = AudioPlayer()..setReleaseMode(ReleaseMode.loop);
  }

  late final AudioPlayer _player;
  late final AudioPlayer _music;
  bool _muted = false;

  bool get muted => _muted;

  void setMuted(bool value) {
    _muted = value;
    if (value) {
      unawaited(_music.stop());
    }
  }

  Future<void> _play(String file) async {
    if (_muted) return;
    try {
      await _player.play(AssetSource('sounds/$file'));
    } catch (_) {
      // Audio is decorative; ignore failures.
    }
  }

  Future<void> click() => _play('click.wav');
  Future<void> cash() => _play('cash.wav');
  Future<void> success() => _play('success.wav');
  Future<void> error() => _play('error.wav');
  Future<void> wrench() => _play('wrench.wav');
}
