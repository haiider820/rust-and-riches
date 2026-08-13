import 'package:shared_preferences/shared_preferences.dart';

import '../features/garage/model/car.dart';

/// Persistence boundary for the game state.
///
/// Phase 1 uses device-local preferences. Phase 2 can add a remote-backed
/// implementation without changing the game controller or widgets.
class LocalSaveService {
  static const _cashKey = 'rust_riches.cash';
  static const _carsKey = 'rust_riches.cars';

  Future<GameSaveData> load() async {
    final preferences = await SharedPreferences.getInstance();
    final rawCars = preferences.getString(_carsKey);
    return GameSaveData(
      cash: preferences.getInt(_cashKey) ?? 850,
      cars: rawCars == null ? const [] : Car.decodeList(rawCars),
    );
  }

  Future<void> save(GameSaveData data) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_cashKey, data.cash);
    await preferences.setString(_carsKey, Car.encodeList(data.cars));
  }
}

class GameSaveData {
  const GameSaveData({required this.cash, required this.cars});

  final int cash;
  final List<Car> cars;
}
