import 'dart:io';

import 'package:purchases_flutter/purchases_flutter.dart';

import 'game_backend.dart';

class RevenueCatConfig {
  const RevenueCatConfig({
    required this.androidApiKey,
    required this.iosApiKey,
  });
  // Replace these placeholders with public RevenueCat SDK keys before release.
  final String androidApiKey;
  final String iosApiKey;

  String get currentApiKey => Platform.isIOS ? iosApiKey : androidApiKey;
}

class RevenueCatService {
  RevenueCatService({
    this.config = const RevenueCatConfig(
      androidApiKey: 'REPLACE_WITH_REVENUECAT_ANDROID_PUBLIC_KEY',
      iosApiKey: 'REPLACE_WITH_REVENUECAT_IOS_PUBLIC_KEY',
    ),
  });
  final RevenueCatConfig config;
  bool _configured = false;
  bool isVip = false;
  Offerings? offerings;

  static const vipEntitlementId = 'vip_garage_pass';
  static const vipPackageId = 'vip_garage_pass';
  static const timeSkipPackageId = 'time_skip_bundle';
  static const barnFindBundlePackageId = 'guaranteed_barn_find_bundle';

  bool get hasConfiguration =>
      !config.androidApiKey.startsWith('REPLACE_') &&
      !config.iosApiKey.startsWith('REPLACE_');
  bool get isConfigured => _configured;

  Future<void> configure({String? appUserId}) async {
    if (_configured || !hasConfiguration) return;
    final configuration = PurchasesConfiguration(config.currentApiKey);
    if (appUserId != null) configuration.appUserID = appUserId;
    await Purchases.configure(configuration);
    _configured = true;
    offerings = await Purchases.getOfferings();
    await refreshStatus();
  }

  Future<void> refreshStatus() async {
    if (!_configured) return;
    final info = await Purchases.getCustomerInfo();
    isVip = info.entitlements.active.containsKey(vipEntitlementId);
  }

  Future<void> syncStatus(GameBackend backend) async {
    await refreshStatus();
    await backend.syncVipStatus(active: isVip);
  }

  Future<bool> purchaseVip() async {
    final package = _findPackage(vipPackageId);
    if (package == null) return false;
    final result = await Purchases.purchase(PurchaseParams.package(package));
    isVip = result.customerInfo.entitlements.active.containsKey(
      vipEntitlementId,
    );
    return isVip;
  }

  Future<ConsumableGrantResult?> purchaseConsumable({
    required String packageId,
    required ConsumableKind kind,
    required GameBackend backend,
  }) async {
    final package = _findPackage(packageId);
    if (package == null) return null;
    final result = await Purchases.purchase(PurchaseParams.package(package));
    final transactionId = result.storeTransaction.transactionIdentifier;
    if (transactionId.isEmpty) return null;
    return backend.grantConsumable(transactionId: transactionId, kind: kind);
  }

  Future<bool> restorePurchases() async {
    if (!_configured) return false;
    final info = await Purchases.restorePurchases();
    isVip = info.entitlements.active.containsKey(vipEntitlementId);
    return isVip;
  }

  Package? _findPackage(String packageId) {
    final packages = offerings?.current?.availablePackages ?? const <Package>[];
    for (final package in packages) {
      if (package.identifier == packageId ||
          package.storeProduct.identifier == packageId) {
        return package;
      }
    }
    return null;
  }
}
