#!/usr/bin/env node
'use strict';

// Mengisi koleksi Firestore `levels` dari levels.csv (upsert, aman diulang).
//
//   node seed_levels.js --dry-run            # validasi + ringkasan saja
//   node seed_levels.js                      # validasi lalu tulis
//   node seed_levels.js --csv path/lain.csv  # CSV lain
//
// Kredensial: tools/serviceAccountKey.json (JANGAN di-commit, isinya tidak
// pernah dicetak oleh skrip ini).

const fs = require('node:fs');
const path = require('node:path');
const { validateCsv, docId, toFirestoreDoc } = require('./lib/validate_levels');

const COLLECTION = 'levels';
const KEY_PATH = path.join(__dirname, 'serviceAccountKey.json');
const BATCH_LIMIT = 500;

function parseArgs(argv) {
  const args = { dryRun: false, csv: path.join(__dirname, 'levels.csv') };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--dry-run') args.dryRun = true;
    else if (a === '--csv') args.csv = path.resolve(argv[++i] ?? '');
    else if (a === '--help' || a === '-h') args.help = true;
    else throw new Error(`Argumen tidak dikenal: ${a}`);
  }
  return args;
}

function printSummary(levels) {
  const orders = levels.map((l) => l.order).sort((a, b) => a - b);
  const packs = {};
  for (const l of levels) packs[l.packId] = (packs[l.packId] ?? 0) + 1;
  const active = levels.filter((l) => l.active).length;

  console.log(`Level valid : ${levels.length} (aktif ${active}, nonaktif ${levels.length - active})`);
  console.log(`Order       : ${orders[0]} .. ${orders[orders.length - 1]}`);
  console.log(
    `Pack        : ${Object.entries(packs)
      .map(([p, n]) => `${p} (${n})`)
      .join(', ')}`,
  );
  console.log('Dokumen     :');
  for (const l of [...levels].sort((a, b) => a.order - b.order)) {
    console.log(
      `  ${COLLECTION}/${docId(l.order)}  ${l.answer.padEnd(12)} ${l.imageFile}` +
        (l.active ? '' : '  [nonaktif]'),
    );
  }
}

async function write(levels) {
  if (!fs.existsSync(KEY_PATH)) {
    throw new Error(
      'tools/serviceAccountKey.json tidak ditemukan. Lihat tools/README.md ' +
        'untuk cara membuatnya.',
    );
  }
  // Dimuat hanya saat menulis, agar --dry-run jalan tanpa npm install.
  const admin = require('firebase-admin');
  let serviceAccount;
  try {
    serviceAccount = JSON.parse(fs.readFileSync(KEY_PATH, 'utf8'));
  } catch {
    // Jangan sertakan isi file di pesan error.
    throw new Error('serviceAccountKey.json bukan JSON yang valid.');
  }
  admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
  console.log(`Project     : ${serviceAccount.project_id ?? '(tidak diketahui)'}`);

  const db = admin.firestore();
  for (let i = 0; i < levels.length; i += BATCH_LIMIT) {
    const batch = db.batch();
    for (const l of levels.slice(i, i + BATCH_LIMIT)) {
      // set() tanpa merge: dokumen ditimpa utuh -> upsert, tanpa duplikat.
      batch.set(db.collection(COLLECTION).doc(docId(l.order)), toFirestoreDoc(l));
    }
    await batch.commit();
  }
  console.log(`Selesai: ${levels.length} dokumen ditulis ke "${COLLECTION}".`);
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help) {
    console.log('Pemakaian: node seed_levels.js [--dry-run] [--csv file.csv]');
    return;
  }

  if (!fs.existsSync(args.csv)) throw new Error(`CSV tidak ditemukan: ${args.csv}`);
  console.log(`CSV         : ${path.relative(process.cwd(), args.csv) || args.csv}`);

  const { levels, errors } = validateCsv(fs.readFileSync(args.csv, 'utf8'));
  if (errors.length > 0) {
    console.error(`\nValidasi gagal (${errors.length} masalah), tidak ada yang ditulis:`);
    for (const e of errors) console.error(`  - ${e}`);
    process.exitCode = 1;
    return;
  }

  printSummary(levels);

  if (args.dryRun) {
    console.log('\n--dry-run: validasi OK, tidak ada yang ditulis ke Firestore.');
    return;
  }
  await write(levels);
}

main().catch((e) => {
  console.error(`Gagal: ${e.message}`);
  process.exitCode = 1;
});
