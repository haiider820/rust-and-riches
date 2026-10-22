import 'package:flutter/material.dart';

const franchiseThreshold = 10_000;

/// Lot (garage) upgrades. Each lot level adds one garage bay:
/// level 1 -> 2 bays, level 5 -> 6 bays.
const maxLotLevel = 5;

/// Cost in cash to upgrade the lot FROM the keyed level to the next one.
/// No entry means the lot is already at max level.
const lotUpgradeCost = <int, int>{1: 1200, 2: 3000, 3: 6000, 4: 10000};

int lotMaxBays(int lotLevel) => 1 + lotLevel.clamp(1, maxLotLevel);

/// Tool upgrades. Each tool level speeds up every restoration stage by 8%
/// (multiplicative on the base durations), floored at 60% of base time.
const maxToolLevel = 5;

/// Cost in cash to upgrade tools FROM the keyed level to the next one.
/// No entry means the tools are already at max level.
const toolUpgradeCost = <int, int>{1: 600, 2: 1500, 3: 3000, 4: 5000};

double toolDurationMultiplier(int toolLevel) =>
    (1 - 0.08 * (toolLevel.clamp(1, maxToolLevel) - 1)).clamp(0.6, 1.0);

class CityTheme {
  const CityTheme({
    required this.id,
    required this.name,
    required this.background,
    required this.accent,
    required this.surface,
  });
  final String id;
  final String name;
  final Color background;
  final Color accent;
  final Color surface;
}

const cityThemes = <CityTheme>[
  CityTheme(
    id: 'sunset_valley',
    name: 'Sunset Valley',
    background: Color(0xFFF7F0E5),
    accent: Color(0xFFE76F3C),
    surface: Color(0xFFFFFBF5),
  ),
  CityTheme(
    id: 'harbor_point',
    name: 'Harbor Point',
    background: Color(0xFFE7F2F3),
    accent: Color(0xFF2A9D8F),
    surface: Color(0xFFF8FFFF),
  ),
  CityTheme(
    id: 'neon_heights',
    name: 'Neon Heights',
    background: Color(0xFFECE8F7),
    accent: Color(0xFF7B61B5),
    surface: Color(0xFFFCFAFF),
  ),
  CityTheme(
    id: 'golden_plains',
    name: 'Golden Plains',
    background: Color(0xFFF8F1D8),
    accent: Color(0xFFC99325),
    surface: Color(0xFFFFFDF3),
  ),
];

CityTheme cityThemeFor(String id) => cityThemes.firstWhere(
  (theme) => theme.id == id,
  orElse: () => cityThemes.first,
);

double reputationMultiplierFor(int reputationPoints) =>
    1 + reputationPoints * .1;
