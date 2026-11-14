#!/usr/bin/env node
'use strict';

// Validasi puzzles.csv terhadap folder gambar lokal (tanpa internet).
//
//   node check_images.js [--csv puzzles.csv] [--images folder] [--words words.txt]
//
// Default: tools/puzzles.csv, tools/images/, dan tools/words.txt (jika ada).
// Keluar dengan kode 1 jika ada error. Peringatan (file tidak dipakai,
// kata di words.txt yang belum punya gambar) tidak menggagalkan.

const path = require('node:path');
const { checkProject, parseArgs, printList } = require('./lib/puzzles');
const { WORDS_PATH, loadWords } = require('./lib/words');

const USAGE =
  'Pemakaian: node check_images.js [--csv puzzles.csv] [--images folder] [--words words.txt]';

const rel = (p) => path.relative(process.cwd(), p) || p;

/**
 * Jalankan validasi dan cetak hasil. [wordsPath] null = tanpa words.txt.
 * Mengembalikan hasil checkProject.
 */
function runCheck({ csvPath, imagesDir, wordsPath = null }) {
  console.log(`CSV         : ${rel(csvPath)}`);
  console.log(`Gambar      : ${rel(imagesDir)}`);
  const words = wordsPath ? loadWords(wordsPath) : null;
  if (words) console.log(`Words       : ${rel(wordsPath)} (${words.entries.length} kata)`);

  const result = checkProject({ csvPath, imagesDir, words });
  printList('Peringatan', result.warnings, console.warn);
  printList(
    'Kata di words.txt yang belum punya gambar di folder gambar',
    result.missingWords.map(
      (e) => `${e.key}.webp  (stage ${e.stage}, gambar ${e.slot}, ${e.packId}; baris ${e.line})`,
    ),
    console.warn,
  );

  if (result.errors.length > 0) {
    printList('Error', result.errors, console.error);
    console.error(`\nValidasi GAGAL: ${result.errors.length} error.`);
  } else {
    const stages = new Set(result.puzzles.map((p) => p.stage));
    const notes = result.warnings.length + result.missingWords.length;
    console.log(
      `\nValidasi OK: ${result.puzzles.length} gambar, ${stages.size} stage` +
        (notes ? `, ${notes} peringatan.` : '.'),
    );
  }
  return result;
}

function defaultPaths(args) {
  return {
    csvPath: path.resolve(args.csv ?? path.join(__dirname, 'puzzles.csv')),
    imagesDir: path.resolve(args.images ?? path.join(__dirname, 'images')),
  };
}

if (require.main === module) {
  try {
    const args = parseArgs(process.argv.slice(2), {
      flags: ['help'],
      options: ['csv', 'images', 'words'],
    });
    if (args.help) console.log(USAGE);
    else {
      const wordsPath = path.resolve(args.words ?? WORDS_PATH);
      if (args.words && !require('node:fs').existsSync(wordsPath)) {
        throw new Error(`words.txt tidak ditemukan: ${wordsPath}`);
      }
      if (runCheck({ ...defaultPaths(args), wordsPath }).errors.length > 0) {
        process.exitCode = 1;
      }
    }
  } catch (e) {
    console.error(`Gagal: ${e.message}`);
    process.exitCode = 1;
  }
}

module.exports = { runCheck, defaultPaths };
