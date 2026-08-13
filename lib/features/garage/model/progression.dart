import 'package:flutter/material.dart';

const franchiseThreshold = 10_000;

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
