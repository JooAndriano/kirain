#!/usr/bin/env node
'use strict';

// Membuat puzzles.csv dari folder gambar .webp.
//
//   node make_puzzles_csv.js <folder gambar> [--start-stage N] [--force] [--out file.csv]
//                            [--words words.txt | --no-words]
//
// Pola nama file: jawaban_stage[_akhiran].webp, mis. kucing_1.webp,
// gajah_1_b.webp.
// Jika tools/words.txt ada (atau --words file), slot dan packId diambil dari
// sana dengan mencocokkan jawaban + stage. Tanpa kecocokan (atau --no-words):
// slot = urutan abjad nama file dalam stage yang sama, packId = subfolder.

const fs = require('node:fs');
const path = require('node:path');
const { buildRows, parseArgs, printList, scanFiles, toCsv } = require('./lib/puzzles');
const { WORDS_PATH, loadWords } = require('./lib/words');

const USAGE =
  'Pemakaian: node make_puzzles_csv.js <folder gambar> [--start-stage N] [--force]\n' +
  '                                   [--out file.csv] [--words words.txt | --no-words]';

function main() {
  const args = parseArgs(process.argv.slice(2), {
    flags: ['force', 'help', 'no-words'],
    options: ['start-stage', 'out', 'words'],
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

  let words = null;
  if (!args['no-words']) {
    const wordsPath = path.resolve(args.words ?? WORDS_PATH);
    words = loadWords(wordsPath);
    if (!words && args.words) throw new Error(`words.txt tidak ditemukan: ${wordsPath}`);
    if (words) {
      console.log(
        `Words       : ${path.relative(process.cwd(), wordsPath) || wordsPath} ` +
          `(${words.entries.length} kata)`,
      );
      printList('Masalah di words.txt (baris dilewati)', words.errors, console.warn);
    }
  }

  const { rows, skipped, warnings } = buildRows(scanFiles(dir), { startStage, words });

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
