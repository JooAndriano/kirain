#!/usr/bin/env node
'use strict';

// Mengubah gambar pilihan di tools/picked/ menjadi .webp (<= 300 KB) di
// tools/images/<packId>/.
//
//   node convert_picked.js [--force] [--picked folder] [--images folder] [--words words.txt]
//
// Nama file pilihan harus jawaban_stage[_akhiran].jpg/.jpeg/.png/.webp, dan
// pasangan (jawaban, stage) harus ada di words.txt. File yang tidak dikenal
// dilaporkan dan tidak dikonversi (kode keluar 1). Hasil yang sudah ada dan
// lebih baru dari sumbernya dilewati kecuali dengan --force.

const fs = require('node:fs');
const path = require('node:path');
const { parseArgs, printList, scanFiles } = require('./lib/puzzles');
const { WORDS_PATH, loadWords } = require('./lib/words');
const { convertToWebp, isUpToDate, planConversions } = require('./lib/picked');

const USAGE =
  'Pemakaian: node convert_picked.js [--force] [--picked folder] [--images folder] [--words words.txt]';

const rel = (p) => path.relative(process.cwd(), p) || p;

async function main() {
  const args = parseArgs(process.argv.slice(2), {
    flags: ['force', 'help'],
    options: ['picked', 'images', 'words'],
  });
  if (args.help) {
    console.log(USAGE);
    return;
  }

  const pickedDir = path.resolve(args.picked ?? path.join(__dirname, 'picked'));
  const imagesDir = path.resolve(args.images ?? path.join(__dirname, 'images'));
  const wordsPath = path.resolve(args.words ?? WORDS_PATH);

  const words = loadWords(wordsPath);
  if (!words) throw new Error(`words.txt tidak ditemukan: ${wordsPath}`);
  if (!fs.existsSync(pickedDir)) throw new Error(`Folder pilihan tidak ditemukan: ${pickedDir}`);

  console.log(`Words       : ${rel(wordsPath)} (${words.entries.length} kata)`);
  console.log(`Pilihan     : ${rel(pickedDir)}`);
  console.log(`Hasil       : ${rel(imagesDir)}`);
  printList('Masalah di words.txt (baris dilewati)', words.errors, console.warn);

  const { jobs, unknown } = planConversions(scanFiles(pickedDir), words);
  printList(
    'File tidak dikenal, tidak dikonversi',
    unknown.map((u) => `${u.rel}: ${u.reason}`),
    console.warn,
  );

  let converted = 0;
  let skipped = 0;
  const failed = [];
  if (jobs.length > 0) {
    let sharp;
    try {
      sharp = require('sharp');
    } catch {
      throw new Error('Paket sharp belum terpasang. Jalankan: cd tools && npm install');
    }
    console.log('');
    for (const job of jobs) {
      const output = path.join(imagesDir, ...job.outRel.split('/'));
      const label = `${job.file.rel} -> ${job.outRel}`;
      if (!args.force && isUpToDate(job.file.abs, output)) {
        skipped++;
        console.log(`  lewati  ${label} (sudah ada)`);
        continue;
      }
      try {
        const r = await convertToWebp(sharp, job.file.abs, output);
        converted++;
        console.log(
          `  ok      ${label}  ${Math.ceil(r.bytes / 1024)} KB, q${r.quality}, maks ${r.maxSide}px` +
            `  (stage ${job.entry.stage}, gambar ${job.entry.slot})`,
        );
      } catch (e) {
        failed.push(`${job.file.rel}: ${e.message}`);
      }
    }
  }
  printList('Gagal dikonversi', failed, console.error);

  console.log(
    `\nSelesai: ${converted} dikonversi, ${skipped} dilewati, ` +
      `${unknown.length} tidak dikenal, ${failed.length} gagal.`,
  );
  if (unknown.length > 0 || failed.length > 0) process.exitCode = 1;
}

main().catch((e) => {
  console.error(`Gagal: ${e.message}`);
  process.exitCode = 1;
});
