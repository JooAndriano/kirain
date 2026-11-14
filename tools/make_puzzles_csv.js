#!/usr/bin/env node
'use strict';

// Membuat puzzles.csv dari folder gambar .webp.
//
//   node make_puzzles_csv.js <folder gambar> [--start-stage N] [--force] [--out file.csv]
//
// Pola nama file: jawaban_stage[_akhiran].webp, mis. kucing_1.webp,
// gajah_1_b.webp. Subfolder pertama = packId ("umum" jika di root).
// slot = urutan abjad nama file dalam stage yang sama.

const fs = require('node:fs');
const path = require('node:path');
const { buildRows, parseArgs, printList, scanFiles, toCsv } = require('./lib/puzzles');

const USAGE =
  'Pemakaian: node make_puzzles_csv.js <folder gambar> [--start-stage N] [--force] [--out file.csv]';

function main() {
  const args = parseArgs(process.argv.slice(2), {
    flags: ['force', 'help'],
    options: ['start-stage', 'out'],
  });
  if (args.help) {
    console.log(USAGE);
    return;
  }
  if (args._.length !== 1) throw new Error(`Butuh tepat satu folder gambar.\n${USAGE}`);

  const dir = path.resolve(args._[0]);
  if (!fs.existsSync(dir) || !fs.statSync(dir).isDirectory()) {
    throw new Error(`Folder tidak ditemukan: ${dir}`);
  }

  let startStage = null;
  if (args['start-stage'] !== undefined) {
    startStage = Number(args['start-stage']);
    if (!Number.isInteger(startStage) || startStage < 1) {
      throw new Error('--start-stage harus bilangan bulat >= 1.');
    }
  }

  const out = path.resolve(args.out ?? path.join(__dirname, 'puzzles.csv'));
  if (fs.existsSync(out) && !args.force) {
    throw new Error(
      `${path.relative(process.cwd(), out) || out} sudah ada. ` +
        'Pakai --force untuk menimpa.',
    );
  }

  const { rows, skipped, warnings } = buildRows(scanFiles(dir), { startStage });

  printList(
    'Nama file tidak cocok pola jawaban_stage[_akhiran].webp, dilewati',
    skipped,
    console.warn,
  );
  printList('Peringatan', warnings, console.warn);

  if (rows.length === 0) throw new Error('Tidak ada gambar .webp yang cocok pola.');

  fs.writeFileSync(out, toCsv(rows));
  const stages = new Set(rows.map((r) => r.stage));
  console.log(
    `\n${rows.length} gambar, ${stages.size} stage -> ` +
      `${path.relative(process.cwd(), out) || out}`,
  );
  console.log('Langkah berikutnya: edit di Excel/Sheets bila perlu, lalu node check_images.js');
}

try {
  main();
} catch (e) {
  console.error(`Gagal: ${e.message}`);
  process.exitCode = 1;
}
