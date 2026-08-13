# Rust & Riches — Phase 2 setup

Phase 2 adds anonymous Firebase Authentication, Firestore persistence, server-authoritative idle catch-up, and the cold-start Welcome Back experience. The Phase 1 garage loop remains the only player-facing game loop; ads, Barn Finds, prestige, subscriptions, and other later systems are intentionally absent.

## Firebase project setup

Create a Firebase project, enable **Anonymous** under Authentication, create a Firestore database, and register the Android and iOS applications. Install the FlutterFire CLI, then run `flutterfire configure` from the project root. This replaces the placeholders in `lib/firebase_options.dart` and generates the platform Firebase configuration files.

From the project root, deploy the Firestore rules and the callable function with the Firebase CLI:

```bash
firebase login
firebase use YOUR_FIREBASE_PROJECT_ID
firebase deploy --only firestore:rules,functions
```

The Cloud Function uses Node.js 22 and is deployed as a 2nd-generation callable function named `catchUpOnOpen` in `us-central1`.

## State and anti-clock contract

The client writes the full state after meaningful game changes and whenever Flutter reports that the app is becoming inactive, paused, or detached. Each write uses Firestore `FieldValue.serverTimestamp()` for `lastSavedAt`; the device clock is not used as the authority for idle time.

On a cold start with an existing player document, the app calls `catchUpOnOpen`. The function reads the existing state in a Firestore transaction, compares the previous server timestamp with `Timestamp.now()`, advances any explicitly started restoration stages, automatically credits the sale price for cars that finish all stages while away, removes those completed cars from the garage, writes the canonical result, and returns a summary for the Welcome Back screen. The function caps one catch-up window at 30 days and is idempotent because it advances the saved state and replaces `lastSavedAt` in the same transaction.

The current Firestore rules keep each anonymous player's document private to that authenticated UID. For a production anti-cheat hardening pass, the next backend phase should move economy mutations such as buy, stage-start, and sell into callable functions as well; Phase 2 keeps direct state saves as requested while making closed-app progression server-authoritative.

## Local validation

The project passes:

```bash
flutter analyze
flutter test
node --check functions/index.js
```

A real device build requires the local Android SDK/Xcode toolchains and the generated Firebase platform configuration from `flutterfire configure`.
