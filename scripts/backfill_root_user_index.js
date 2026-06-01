#!/usr/bin/env node
/*
  One-time Firestore migration: rebuild root /users index from nested company users.

  Usage:
    node scripts/backfill_root_user_index.js --dry-run
    node scripts/backfill_root_user_index.js

  Prerequisites:
    1) npm i firebase-admin
    2) Set GOOGLE_APPLICATION_CREDENTIALS to a service account json path
*/

const admin = require('firebase-admin');

const args = process.argv.slice(2);
const dryRun = args.includes('--dry-run');

admin.initializeApp();
const db = admin.firestore();

async function main() {
  console.log(`Starting root user index backfill (dryRun=${dryRun})`);

  const companiesSnapshot = await db.collection('companies').get();
  if (companiesSnapshot.empty) {
    console.log('No companies found.');
    return;
  }

  let copied = 0;
  let skipped = 0;
  let batch = db.batch();
  let ops = 0;

  for (const companyDoc of companiesSnapshot.docs) {
    const companyId = companyDoc.id;
    const usersSnapshot = await db
      .collection('companies')
      .doc(companyId)
      .collection('users')
      .get();

    for (const userDoc of usersSnapshot.docs) {
      const data = userDoc.data() || {};
      const uid = userDoc.id;

      if (!uid || typeof uid !== 'string') {
        skipped += 1;
        console.log(`[${companyId}] skip invalid uid for nested user doc`);
        continue;
      }

      const payload = {
        ...data,
        id: data.id || uid,
        companyId: data.companyId || companyId,
        indexedAt: admin.firestore.FieldValue.serverTimestamp(),
        indexVersion: 'nested-to-root-user-index-v1',
      };

      const targetRef = db.collection('users').doc(uid);

      if (dryRun) {
        console.log(`[DRY] companies/${companyId}/users/${uid} -> users/${uid}`);
      } else {
        batch.set(targetRef, payload, {merge: true});
        ops += 1;
        if (ops >= 450) {
          await batch.commit();
          batch = db.batch();
          ops = 0;
        }
      }

      copied += 1;
    }
  }

  if (!dryRun && ops > 0) {
    await batch.commit();
  }

  console.log(`Done. copied=${copied}, skipped=${skipped}`);
}

main().catch((err) => {
  console.error('Backfill failed:', err);
  process.exit(1);
});
