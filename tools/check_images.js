#!/usr/bin/env node
'use strict';

// Validasi puzzles.csv terhadap folder gambar lokal (tanpa internet).
//
//   node check_images.js [--csv puzzles.csv] [--images folder]
//
// Default: tools/puzzles.csv dan tools/images/. Keluar dengan kode 1 jika
// ada error; peringatan (mis. file tidak dipakai) tidak menggagalkan.

const path = require('node:path');
const { checkProject, parseArgs, printList } = require('./lib/puzzles');

const USAGE = 'Pemakaian: node check_images.js [--csv puzzles.csv] [--images folder]';

/** Jalankan validasi dan cetak hasil. Mengembalikan hasil checkProject. */
function runCheck({ csvPath, imagesDir }) {
  console.log(`CSV         : ${path.relative(process.cwd(), csvPath) || csvPath}`);
  console.log(`Gambar      : ${path.relative(process.cwd(), imagesDir) || imagesDir}`);
  const result = checkProject({ csvPath, imagesDir });
  printList('Peringatan', result.warnings, console.warn);
  if (result.errors.length > 0) {
    printList('Error', result.errors, console.error);
    console.error(`\nValidasi GAGAL: ${result.errors.length} error.`);
  } else {
    const stages = new Set(result.puzzles.map((p) => p.stage));
    console.log(
      `\nValidasi OK: ${result.puzzles.length} gambar, ${stages.size} stage` +
        (result.warnings.length ? `, ${result.warnings.length} peringatan.` : '.'),
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
      options: ['csv', 'images'],
    });
    if (args.help) console.log(USAGE);
    else if (runCheck(defaultPaths(args)).errors.length > 0) process.exitCode = 1;
  } catch (e) {
    console.error(`Gagal: ${e.message}`);
    process.exitCode = 1;
  }
}

module.exports = { runCheck, defaultPaths };
