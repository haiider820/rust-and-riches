const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');
const { initializeApp } = require('firebase-admin/app');

initializeApp();
const db = getFirestore();

const STAGE_ORDER = ['wrecked', 'stripped', 'repaired', 'painted', 'detailed'];
const DURATION_SECONDS = {
  common: { wrecked: 15, stripped: 20, repaired: 25, painted: 12 },
  rare: { wrecked: 25, stripped: 35, repaired: 40, painted: 20 },
  classic: { wrecked: 40, stripped: 50, repaired: 60, painted: 30 },
};
const SALE_PRICE = { common: 360, rare: 1180, classic: 2900 };
const MAX_IDLE_SECONDS = 60 * 60 * 24 * 30;

// Phase 7 upgrade formulas. These mirror lib/features/garage/model/progression.dart
// (lotMaxBays / toolDurationMultiplier) — keep both sides in sync.
const MAX_LOT_LEVEL = 5;
const MAX_TOOL_LEVEL = 5;
const lotMaxBays = (level) =>
  1 + Math.min(MAX_LOT_LEVEL, Math.max(1, Number(level) || 1));
const toolDurationMultiplier = (level) =>
  Math.max(
    0.6,
    1 - 0.08 * (Math.min(MAX_TOOL_LEVEL, Math.max(1, Number(level) || 1)) - 1),
  );

exports.catchUpOnOpen = onCall({ region: 'us-central1' }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Anonymous authentication is required.');
  }

  const playerRef = db.collection('players').doc(request.auth.uid);
  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(playerRef);
    if (!snapshot.exists) {
      throw new HttpsError('failed-precondition', 'Player state has not been created.');
    }

    const data = snapshot.data() || {};
    const savedAt = data.lastSavedAt;
    const now = Timestamp.now();
    const elapsedSeconds = savedAt instanceof Timestamp
      ? Math.max(0, Math.min(MAX_IDLE_SECONDS, now.seconds - savedAt.seconds))
      : 0;

    let cash = Number(data.cash || 0);
    let cashEarned = 0;
    const reputationMultiplier = (1 + Number(data.reputationPoints || 0) * 0.1) * (data.vipGaragePass === true ? 1.2 : 1);
    let finishedCarCount = 0;
    const cars = Array.isArray(data.cars) ? data.cars : [];
    const nextCars = [];

    for (const sourceCar of cars) {
      const car = { ...sourceCar };
      let remaining = elapsedSeconds;
      let stage = car.stage;
      let stageStartedAt = car.stageStartedAt ? new Date(car.stageStartedAt) : null;

      // A car only consumes idle time once a stage has been explicitly started.
      // Stage durations scale with the player's tool level, mirroring the client.
      const toolMultiplier = toolDurationMultiplier(data.toolLevel);
      while (stageStartedAt && stage !== 'detailed' && remaining > 0) {
        const baseDuration = DURATION_SECONDS[car.tier]?.[stage];
        if (!baseDuration) break;
        const duration = Math.max(1, Math.round(baseDuration * toolMultiplier));
        const stageEndsAt = Math.floor(stageStartedAt.getTime() / 1000) + duration;
        const available = Math.floor((now.toMillis() / 1000) - (stageStartedAt.getTime() / 1000));
        if (available < duration) break;

        remaining -= duration;
        const stageIndex = STAGE_ORDER.indexOf(stage);
        stage = STAGE_ORDER[stageIndex + 1];
        if (stage === 'detailed') {
          const baseSale = SALE_PRICE[car.tier] || 0;
          const multipliedSale = Math.floor(baseSale * reputationMultiplier);
          cash += multipliedSale;
          cashEarned += multipliedSale;
          finishedCarCount += 1;
          stageStartedAt = null;
          break;
        }
        stageStartedAt = new Date(stageEndsAt * 1000);
      }

      if (stage !== 'detailed') {
        nextCars.push({ ...car, stage, stageStartedAt: stageStartedAt?.toISOString() || null });
      }
    }

    const pendingIdleCash = Number(data.lastIdleCashEarned || 0) + cashEarned;
    const updated = {
      cash,
      cars: nextCars,
      lastSavedAt: now,
      lastIdleCashEarned: pendingIdleCash,
      lifetimeEarnings: Number(data.lifetimeEarnings || 0) + cashEarned,
      schemaVersion: 5,
    };
    transaction.set(playerRef, updated, { merge: true });

    return {
      cash,
      cars: nextCars,
      cashEarned,
      finishedCarCount,
      elapsedSeconds,
      vipAutoCollected: data.vipGaragePass === true,
    };
  });
});


const FRANCHISE_THRESHOLD = 10000;

exports.franchisePlayer = onCall({ region: 'us-central1' }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Anonymous authentication is required.');
  const { targetCityId } = request.data || {};
  if (typeof targetCityId !== 'string' || targetCityId.length > 64) throw new HttpsError('invalid-argument', 'A valid target city is required.');
  const playerRef = db.collection('players').doc(request.auth.uid);
  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(playerRef);
    if (!snapshot.exists) throw new HttpsError('failed-precondition', 'Player state does not exist.');
    const data = snapshot.data() || {};
    const lifetimeEarnings = Number(data.lifetimeEarnings || 0);
    if (lifetimeEarnings < FRANCHISE_THRESHOLD) throw new HttpsError('failed-precondition', `Reach ${FRANCHISE_THRESHOLD} lifetime earnings first.`);
    const reputationPoints = Number(data.reputationPoints || 0) + 1;
    const prestigeCount = Number(data.prestigeCount || 0) + 1;
    const next = { cash: 850, cars: [], lotLevel: 1, toolLevel: 1, cityId: targetCityId, reputationPoints, prestigeCount, lifetimeEarnings, barnFind: null, lastIdleCashEarned: 0, lastSavedAt: Timestamp.now(), schemaVersion: 5 };
    transaction.set(playerRef, next, { merge: true });
    return { ...next, collectionIds: data.collectionIds || [], multiplierGained: 1 + reputationPoints * 0.1 };
  });
});

exports.claimReward = onCall({ region: 'us-central1' }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Anonymous authentication is required.');
  }
  const { rewardId, kind, carId } = request.data || {};
  if (typeof rewardId !== 'string' || !/^[a-zA-Z0-9-]{12,120}$/.test(rewardId)) {
    throw new HttpsError('invalid-argument', 'A valid reward ID is required.');
  }
  if (!['doubleOfflineEarnings', 'finishRestoration'].includes(kind)) {
    throw new HttpsError('invalid-argument', 'Unsupported reward kind.');
  }

  const playerRef = db.collection('players').doc(request.auth.uid);
  const rewardRef = playerRef.collection('claimedRewards').doc(rewardId);
  return db.runTransaction(async (transaction) => {
    const [playerSnapshot, rewardSnapshot] = await Promise.all([
      transaction.get(playerRef),
      transaction.get(rewardRef),
    ]);
    if (rewardSnapshot.exists) {
      const existing = playerSnapshot.data() || {};
      return { accepted: false, cash: Number(existing.cash || 0), cars: existing.cars || [] };
    }
    if (!playerSnapshot.exists) {
      throw new HttpsError('failed-precondition', 'Player state does not exist.');
    }

    const data = playerSnapshot.data() || {};
    let cash = Number(data.cash || 0);
    let cars = Array.isArray(data.cars) ? data.cars.map((car) => ({ ...car })) : [];
    if (kind === 'doubleOfflineEarnings') {
      const pending = Number(data.lastIdleCashEarned || 0);
      cash += pending;
      transaction.set(playerRef, { cash, lastIdleCashEarned: 0, lastRewardAt: Timestamp.now() }, { merge: true });
    } else {
      if (typeof carId !== 'string') {
        throw new HttpsError('invalid-argument', 'A car is required for this reward.');
      }
      const carIndex = cars.findIndex((car) => car.id === carId);
      if (carIndex < 0 || cars[carIndex].stage === 'detailed') {
        throw new HttpsError('failed-precondition', 'That restoration is no longer active.');
      }
      const currentStage = cars[carIndex].stage;
      const currentIndex = STAGE_ORDER.indexOf(currentStage);
      if (currentIndex < 0 || currentIndex >= STAGE_ORDER.length - 1) {
        throw new HttpsError('failed-precondition', 'That restoration stage is invalid.');
      }
      cars[carIndex].stageStartedAt = null;
      cars[carIndex].stage = STAGE_ORDER[currentIndex + 1];
      transaction.set(playerRef, { cash, cars, lastRewardAt: Timestamp.now() }, { merge: true });
    }
    transaction.set(rewardRef, { kind, carId: carId || null, claimedAt: Timestamp.now() });
    return { accepted: true, cash, cars };
  });
});


const BARN_FIND_MODELS = [
  { id: 'golden_v8', tier: 'classic', basePrice: 950 },
  { id: 'velvet_cruiser', tier: 'classic', basePrice: 950 },
  { id: 'heritage_special', tier: 'classic', basePrice: 950 },
  { id: 'midnight_gt', tier: 'rare', basePrice: 420 },
  { id: 'redline_coupe', tier: 'rare', basePrice: 420 },
  { id: 'coastal_roadster', tier: 'rare', basePrice: 420 },
];
const BARN_FIND_GAP_SECONDS = 15 * 60;
const BARN_FIND_LIFETIME_SECONDS = 5 * 60;

function createBarnFindOffer(now, bundled = false) {
  const model = BARN_FIND_MODELS[Math.floor(Math.random() * BARN_FIND_MODELS.length)];
  return {
    id: `barn-${now.toMillis()}-${Math.floor(Math.random() * 100000)}`,
    modelId: model.id,
    discountedPrice: bundled ? 0 : Math.floor(model.basePrice * 0.55),
    expiresAt: Timestamp.fromMillis(now.toMillis() + BARN_FIND_LIFETIME_SECONDS * 1000),
    attempts: 3,
    targetStart: 0.35 + Math.random() * 0.25,
    targetWidth: 0.18,
    bundled,
  };
}

exports.getBarnFindOffer = onCall({ region: 'us-central1' }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Anonymous authentication is required.');
  const playerRef = db.collection('players').doc(request.auth.uid);
  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(playerRef);
    if (!snapshot.exists) throw new HttpsError('failed-precondition', 'Player state has not been created.');
    const data = snapshot.data() || {};
    const now = Timestamp.now();
    const current = data.barnFind;
    if (current && current.expiresAt instanceof Timestamp && current.expiresAt.seconds > now.seconds) {
      return { offer: { ...current, expiresAt: current.expiresAt.toDate().toISOString() } };
    }
    const lastCreated = data.lastBarnFindAt;
    if (lastCreated instanceof Timestamp && now.seconds - lastCreated.seconds < BARN_FIND_GAP_SECONDS) {
      return { offer: null };
    }
    const offer = createBarnFindOffer(now);
    transaction.set(playerRef, { barnFind: offer, lastBarnFindAt: now }, { merge: true });
    return { offer: { ...offer, expiresAt: offer.expiresAt.toDate().toISOString() } };
  });
});

exports.claimBarnFind = onCall({ region: 'us-central1' }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Anonymous authentication is required.');
  const { offerId, wonMinigame } = request.data || {};
  if (typeof offerId !== 'string' || typeof wonMinigame !== 'boolean') {
    throw new HttpsError('invalid-argument', 'Offer ID and minigame result are required.');
  }
  const playerRef = db.collection('players').doc(request.auth.uid);
  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(playerRef);
    if (!snapshot.exists) throw new HttpsError('failed-precondition', 'Player state has not been created.');
    const data = snapshot.data() || {};
    const offer = data.barnFind;
    const now = Timestamp.now();
    if (!offer || offer.id !== offerId || !(offer.expiresAt instanceof Timestamp) || offer.expiresAt.seconds <= now.seconds) {
      throw new HttpsError('failed-precondition', 'That Barn Find has expired.');
    }
    const cash = Number(data.cash || 0);
    const price = Number(offer.discountedPrice || 0);
    if (!wonMinigame && cash < price) throw new HttpsError('failed-precondition', 'Not enough cash for this Barn Find.');
    const model = BARN_FIND_MODELS.find((item) => item.id === offer.modelId);
    if (!model) throw new HttpsError('failed-precondition', 'Unknown Barn Find model.');
    const cars = Array.isArray(data.cars) ? data.cars.map((car) => ({ ...car })) : [];
    if (cars.length >= lotMaxBays(data.lotLevel)) throw new HttpsError('failed-precondition', 'All garage bays are occupied.');
    const nextCash = wonMinigame ? cash : cash - price;
    const car = {
      id: `barn-car-${now.toMillis()}`,
      tier: model.tier,
      stage: 'wrecked',
      purchasedAt: now.toDate().toISOString(),
      stageStartedAt: null,
      modelId: model.id,
      isBarnFind: true,
    };
    const nextCars = [...cars, car];
    transaction.set(playerRef, { cash: nextCash, cars: nextCars, barnFind: null, lastSavedAt: now, schemaVersion: 4 }, { merge: true });
    return { accepted: true, cash: nextCash, cars: nextCars, collectionIds: data.collectionIds || [] };
  });
});


// Phase 6 consumables. RevenueCat should be configured with a webhook/receipt
// verifier before release; the transaction ID is still used as an idempotency key.
const CONSUMABLE_GRANTS = {
  timeSkip: 50,
  barnFindBundle: 75,
};

exports.grantConsumable = onCall({ region: 'us-central1' }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Anonymous authentication is required.');
  const { transactionId, kind } = request.data || {};
  if (typeof transactionId !== 'string' || transactionId.length < 3 || typeof kind !== 'string' || !CONSUMABLE_GRANTS[kind]) {
    throw new HttpsError('invalid-argument', 'A valid RevenueCat transaction and product kind are required.');
  }
  const playerRef = db.collection('players').doc(request.auth.uid);
  const purchaseRef = playerRef.collection('iapTransactions').doc(transactionId.replace(/[^a-zA-Z0-9_-]/g, '_'));
  return db.runTransaction(async (transaction) => {
    const [playerSnapshot, purchaseSnapshot] = await Promise.all([transaction.get(playerRef), transaction.get(purchaseRef)]);
    if (!playerSnapshot.exists) throw new HttpsError('failed-precondition', 'Player state does not exist.');
    const data = playerSnapshot.data() || {};
    if (purchaseSnapshot.exists) {
      const existingOffer = data.barnFind;
      return { accepted: false, premiumCurrency: Number(data.premiumCurrency || 0), barnFindOffer: existingOffer ? { ...existingOffer, expiresAt: existingOffer.expiresAt?.toDate?.().toISOString?.() || existingOffer.expiresAt } : null };
    }
    const amount = CONSUMABLE_GRANTS[kind];
    const premiumCurrency = Number(data.premiumCurrency || 0) + amount;
    const now = Timestamp.now();
    const barnFindOffer = kind === 'barnFindBundle' && !data.barnFind ? createBarnFindOffer(now, true) : data.barnFind || null;
    transaction.set(playerRef, { premiumCurrency, barnFind: barnFindOffer, lastSavedAt: now, schemaVersion: 6 }, { merge: true });
    transaction.set(purchaseRef, { kind, granted: amount, grantedAt: now });
    return { accepted: true, premiumCurrency, barnFindOffer: barnFindOffer ? { ...barnFindOffer, expiresAt: barnFindOffer.expiresAt.toDate().toISOString() } : null };
  });
});

exports.spendPremiumTimeSkip = onCall({ region: 'us-central1' }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Anonymous authentication is required.');
  const { carId } = request.data || {};
  if (typeof carId !== 'string') throw new HttpsError('invalid-argument', 'A car ID is required.');
  const playerRef = db.collection('players').doc(request.auth.uid);
  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(playerRef);
    if (!snapshot.exists) throw new HttpsError('failed-precondition', 'Player state does not exist.');
    const data = snapshot.data() || {};
    const premiumCurrency = Number(data.premiumCurrency || 0);
    if (premiumCurrency < 10) throw new HttpsError('failed-precondition', 'Not enough premium currency.');
    const cars = Array.isArray(data.cars) ? data.cars.map((car) => ({ ...car })) : [];
    const index = cars.findIndex((car) => car.id === carId);
    if (index < 0 || cars[index].stage === 'detailed' || !cars[index].stageStartedAt) {
      throw new HttpsError('failed-precondition', 'That car has no active restoration stage.');
    }
    const stageIndex = STAGE_ORDER.indexOf(cars[index].stage);
    if (stageIndex < 0 || stageIndex >= STAGE_ORDER.length - 1) throw new HttpsError('failed-precondition', 'That restoration stage is invalid.');
    cars[index].stage = STAGE_ORDER[stageIndex + 1];
    cars[index].stageStartedAt = null;
    const nextPremiumCurrency = premiumCurrency - 10;
    transaction.set(playerRef, { premiumCurrency: nextPremiumCurrency, cars, lastSavedAt: Timestamp.now(), schemaVersion: 6 }, { merge: true });
    return { accepted: true, cash: Number(data.cash || 0), cars, premiumCurrency: nextPremiumCurrency };
  });
});
