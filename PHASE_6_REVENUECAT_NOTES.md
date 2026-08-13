# Phase 6 integration findings

RevenueCat's official Flutter installation documentation: https://www.revenuecat.com/docs/getting-started/installation/flutter

The Flutter SDK package is `purchases_flutter`. RevenueCat requires iOS deployment target 11.0 or higher and Swift 5.0 or higher. Android should use Activity `launchMode` standard or singleTop for purchase flows that may background the app. iOS requires the In-App Purchase capability, and Android requires the BILLING permission.

RevenueCat entitlements documentation: https://www.revenuecat.com/docs/getting-started/entitlements

Entitlements are the app-facing access layer. The app should check `CustomerInfo.entitlements.active` rather than hardcoding platform product identifiers for VIP access. Consumables such as premium currency should not be attached to an entitlement.

RevenueCat purchase documentation: https://www.revenuecat.com/docs/getting-started/making-purchases

The Flutter SDK purchases a configured Offering package via `purchase(package:)`. A successful purchase returns updated CustomerInfo. RevenueCat automatically finishes/acknowledges/consumes transactions. The app should also expose restore purchases.

RevenueCat iOS installation documentation: https://www.revenuecat.com/docs/getting-started/installation/ios

Real App Store purchases additionally require App Store Connect product configuration, a paid-apps agreement, banking/tax setup, a matching bundle identifier, and the In-App Purchase capability. The current project will therefore use explicit placeholder API keys/product IDs and a setup document until the owner supplies production RevenueCat configuration.
