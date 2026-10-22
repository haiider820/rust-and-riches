import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Daily missions + open streak. Progress is local (SharedPreferences);
/// rewards are granted server-side through the idempotent `claimReward`
/// function with [RewardKind.missionBonus], so the anti-cheat story holds.
enum MissionKind { sellCars, completeStages, claimBarnFind, earnFromSales, upgradeAny }

class MissionDef {
  const MissionDef(this.kind, this.title, this.target, this.reward);
  final MissionKind kind;
  final String title;
  final int target;
  final int reward;
}

const _missionPool = [
  MissionDef(MissionKind.sellCars, 'Sell 2 cars', 2, 250),
  MissionDef(MissionKind.completeStages, 'Finish 5 restoration stages', 5, 150),
  MissionDef(MissionKind.claimBarnFind, 'Claim a barn find', 1, 300),
  MissionDef(MissionKind.earnFromSales, 'Earn \$1,500 from sales', 1500, 200),
  MissionDef(MissionKind.upgradeAny, 'Upgrade your lot or tools', 1, 150),
];

class MissionProgress {
  MissionProgress(this.def, this.progress, this.claimed);
  final MissionDef def;
  int progress;
  bool claimed;

  bool get complete => progress >= def.target;
}

class MissionsService extends ChangeNotifier {
  MissionsService(this._prefs);

  final SharedPreferences _prefs;
  late String _dayKey;
  late List<MissionProgress> missions;
  int streak = 0;

  static String dayKeyFor(DateTime day) =>
      'missions-${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

  Future<void> init() async {
    final now = DateTime.now();
    _dayKey = dayKeyFor(now);
    // Streak: consecutive calendar days the app was opened.
    final lastOpen = _prefs.getString('last_open_day');
    final yesterday = dayKeyFor(now.subtract(const Duration(days: 1)));
    if (lastOpen == _dayKey) {
      streak = _prefs.getInt('streak') ?? 1;
    } else if (lastOpen == yesterday) {
      streak = (_prefs.getInt('streak') ?? 0) + 1;
    } else {
      streak = 1;
    }
    await _prefs.setString('last_open_day', _dayKey);
    await _prefs.setInt('streak', streak);
    _loadToday();
  }

  List<MissionDef> _todayDefs() {
    final now = DateTime.now();
    final start = DateTime(now.year, 1, 1);
    final dayOfYear = now.difference(start).inDays;
    return [
      _missionPool[(dayOfYear * 2) % _missionPool.length],
      _missionPool[(dayOfYear * 2 + 1) % _missionPool.length],
      _missionPool[(dayOfYear * 2 + 3) % _missionPool.length],
    ];
  }

  void _loadToday() {
    final defs = _todayDefs();
    final raw = _prefs.getString(_dayKey);
    final saved = raw == null
        ? <String, dynamic>{}
        : jsonDecode(raw) as Map<String, dynamic>;
    missions = defs.map((def) {
      final entry = saved[def.kind.name] as Map<String, dynamic>?;
      return MissionProgress(
        def,
        (entry?['progress'] as num?)?.toInt() ?? 0,
        entry?['claimed'] as bool? ?? false,
      );
    }).toList();
  }

  Future<void> _save() async {
    final map = {
      for (final mission in missions)
        mission.def.kind.name: {
          'progress': mission.progress,
          'claimed': mission.claimed,
        },
    };
    await _prefs.setString(_dayKey, jsonEncode(map));
  }

  /// Record gameplay progress toward today's missions.
  void record(MissionKind kind, [int amount = 1]) {
    var changed = false;
    for (final mission in missions) {
      if (mission.def.kind == kind && mission.progress < mission.def.target) {
        mission.progress = (mission.progress + amount).clamp(
          0,
          mission.def.target,
        );
        changed = true;
      }
    }
    if (changed) {
      unawaited(_save());
      notifyListeners();
    }
  }

  String rewardIdFor(MissionDef def) => 'mission-$_dayKey-${def.kind.name}';

  void markClaimed(MissionDef def) {
    for (final mission in missions) {
      if (mission.def.kind == def.kind) mission.claimed = true;
    }
    unawaited(_save());
    notifyListeners();
  }
}
