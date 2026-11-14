#!/usr/bin/env node
'use strict';

// Mengisi koleksi Firestore `puzzles` dari puzzles.csv (upsert, aman diulang).
//
//   node seed_puzzles.js --dry-run          # validasi + ringkasan, tidak menulis
//   node seed_puzzles.js                    # validasi lalu tulis
//   node seed_puzzles.js --prune            # + cetak dokumen yang tidak ada di CSV
//   node seed_puzzles.js --prune --yes      # + hapus dokumen tersebut
//   [--csv puzzles.csv] [--images folder]
//
// check_images selalu dijalankan dulu; jika ada error, tidak ada yang ditulis.
// Kredensial: tools/serviceAccountKey.json (JANGAN di-commit, isinya tidak
// pernah dicetak oleh skrip ini).

const fs = require('node:fs');
const path = require('node:path');
const { docId, parseArgs, toFirestoreDoc } = require('./lib/puzzles');
const { defaultPaths, runCheck } = require('./check_images');

const COLLECTION = 'puzzles';
const KEY_PATH = path.join(__dirname, 'serviceAccountKey.json');
const BATCH_LIMIT = 500;

const USAGE =
  'Pemakaian: node seed_puzzles.js [--dry-run] [--prune [--yes]] [--csv file.csv] [--images folder]';

function printSummary(puzzles) {
  const packs = {};
  for (const p of puzzles) packs[p.packId] = (packs[p.packId] ?? 0) + 1;
  console.log(
    `Pack        : ${Object.entries(packs)
      .map(([p, n]) => `${p} (${n})`)
      .join(', ')}`,
  );
  console.log('Dokumen     :');
  for (const p of puzzles) {
    console.log(
      `  ${COLLECTION}/${docId(p.stage, p.slot)}  ${p.answer.padEnd(12)} ${p.imageFile}` +
        (p.active ? '' : '  [nonaktif]'),
    );
  }
}

function openFirestore() {
  if (!fs.existsSync(KEY_PATH)) {
    throw new Error(
      'tools/serviceAccountKey.json tidak ditemukan. Lihat tools/README.md untuk cara membuatnya.',
    );
  }
  // Dimuat hanya saat butuh Firestore, agar --dry-run jalan tanpa npm install.
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
  return admin.firestore();
}

async function write(db, puzzles) {
  for (let i = 0; i < puzzles.length; i += BATCH_LIMIT) {
    const batch = db.batch();
    for (const p of puzzles.slice(i, i + BATCH_LIMIT)) {
      // set() tanpa merge: dokumen ditimpa utuh -> upsert, tanpa duplikat.
      batch.set(db.collection(COLLECTION).doc(docId(p.stage, p.slot)), toFirestoreDoc(p));
    }
    await batch.commit();
  }
  console.log(`Selesai: ${puzzles.length} dokumen ditulis ke "${COLLECTION}".`);
}

/** Dokumen di Firestore yang tidak ada di CSV. Hapus hanya jika [confirm]. */
async function prune(db, puzzles, { confirm }) {
  const keep = new Set(puzzles.map((p) => docId(p.stage, p.slot)));
  const refs = await db.collection(COLLECTION).listDocuments();
  const extra = refs.filter((r) => !keep.has(r.id));
  if (extra.length === 0) {
    console.log('Prune       : tidak ada dokumen di luar CSV.');
    return;
  }
  console.log(`\nDokumen di Firestore yang tidak ada di CSV (${extra.length}):`);
  for (const r of extra) console.log(`  - ${COLLECTION}/${r.id}`);
  if (!confirm) {
    console.log('Tidak dihapus. Tambahkan --yes untuk menghapus dokumen di atas.');
    return;
  }
  for (let i = 0; i < extra.length; i += BATCH_LIMIT) {
    const batch = db.batch();
    for (const r of extra.slice(i, i + BATCH_LIMIT)) batch.delete(r);
    await batch.commit();
  }
  console.log(`Dihapus: ${extra.length} dokumen.`);
}

async function main() {
  const args = parseArgs(process.argv.slice(2), {
    flags: ['dry-run', 'prune', 'yes', 'help'],
    options: ['csv', 'images'],
  });
  if (args.help) {
    console.log(USAGE);
    return;
  }
  if (args.yes && !args.prune) throw new Error('--yes hanya berlaku bersama --prune.');

  // Validasi wajib (check_images) sebelum apa pun ditulis.
  const result = runCheck(defaultPaths(args));
  if (result.errors.length > 0) {
    console.error('Tidak ada yang ditulis ke Firestore.');
    process.exitCode = 1;
    return;
  }
  printSummary(result.puzzles);

  if (args['dry-run']) {
    if (args.prune) {
      console.log('\n--dry-run: prune dilewati (butuh akses Firestore untuk membaca daftar).');
    }
    console.log('\n--dry-run: validasi OK, tidak ada yang ditulis ke Firestore.');
    return;
  }

  const db = openFirestore();
  await write(db, result.puzzles);
  if (args.prune) await prune(db, result.puzzles, { confirm: Boolean(args.yes) });
}

main().catch((e) => {
  console.error(`Gagal: ${e.message}`);
  process.exitCode = 1;
});
