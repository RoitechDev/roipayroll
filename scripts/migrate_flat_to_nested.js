#!/usr/bin/env node
/*
  One-time Firestore migration: flat root collections -> companies/{companyId}/{collection}

  Usage:
    node scripts/migrate_flat_to_nested.js --dry-run
    node scripts/migrate_flat_to_nested.js

  Prerequisites:
    1) npm i firebase-admin
    2) Set GOOGLE_APPLICATION_CREDENTIALS to a service account json path
*/

const admin = require('firebase-admin');

const args = process.argv.slice(2);
const dryRun = args.includes('--dry-run');

const ROOT_COLLECTIONS = [
  'attendance',
  'employees',
  'payrolls',
  'loans',
  'leave_requests',
  'leave_balances',
  'leave_types',
  'deduction_types',
  'employee_deductions',
  'deduction_transactions',
  'employee_allowances',
  'notifications',
  'public_holidays',
  'shifts',
  'attendance_summaries',
  'leave_encashments',
  'users',
];

// Legacy fallback mapping for docs missing companyId.
const LEGACY_DOC_COMPANY_FALLBACK = {
  original_company: 'original_company',
};

admin.initializeApp();
const db = admin.firestore();

function getCompanyId(data) {
  if (data && typeof data.companyId === 'string' && data.companyId.trim()) {
    return data.companyId.trim();
  }
  return null;
}

async function ensureCompanyDoc(companyId) {
  const ref = db.collection('companies').doc(companyId);
  const snap = await ref.get();
  if (snap.exists || dryRun) return;
  await ref.set(
    {
      id: companyId,
      name: companyId,
      isMigrationSeed: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );
}

async function migrateCollection(collectionName) {
  const snapshot = await db.collection(collectionName).get();
  if (snapshot.empty) {
    console.log(`[${collectionName}] no docs`);
    return {copied: 0, skipped: 0};
  }

  let copied = 0;
  let skipped = 0;
  let batch = db.batch();
  let ops = 0;

  for (const doc of snapshot.docs) {
    const data = doc.data() || {};
    let companyId = getCompanyId(data);

    if (!companyId && LEGACY_DOC_COMPANY_FALLBACK[doc.id]) {
      companyId = LEGACY_DOC_COMPANY_FALLBACK[doc.id];
    }

    if (!companyId) {
      skipped += 1;
      console.log(`[${collectionName}] skip ${doc.id} (missing companyId)`);
      continue;
    }

    await ensureCompanyDoc(companyId);
    const targetRef = db
      .collection('companies')
      .doc(companyId)
      .collection(collectionName)
      .doc(doc.id);

    const payload = {
      ...data,
      migratedAt: admin.firestore.FieldValue.serverTimestamp(),
      migrationVersion: 'flat-to-nested-v1',
    };

    if (dryRun) {
      console.log(
        `[DRY] ${collectionName}/${doc.id} -> companies/${companyId}/${collectionName}/${doc.id}`,
      );
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

  if (!dryRun && ops > 0) {
    await batch.commit();
  }

  return {copied, skipped};
}

async function main() {
  console.log(`Starting migration (dryRun=${dryRun})`);
  let totalCopied = 0;
  let totalSkipped = 0;

  for (const collectionName of ROOT_COLLECTIONS) {
    const {copied, skipped} = await migrateCollection(collectionName);
    totalCopied += copied;
    totalSkipped += skipped;
    console.log(`[${collectionName}] copied=${copied}, skipped=${skipped}`);
  }

  console.log(`Done. copied=${totalCopied}, skipped=${totalSkipped}`);
  if (!dryRun) {
    console.log('Root collections were NOT deleted.');
  }
}

main().catch((err) => {
  console.error('Migration failed:', err);
  process.exit(1);
});
