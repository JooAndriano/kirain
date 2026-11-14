#!/usr/bin/env node
'use strict';

// Mencari foto kandidat di Pixabay untuk setiap kata di words.txt.
//
//   node fetch_candidates.js [--stages 1-5] [--per 8] [--force] [--words words.txt] [--out folder]
//
// Kata kunci pencarian = kolom keyword di words.txt. Hasil di tools/candidates/:
//   index.html   halaman memilih gambar ("Stage N, Gambar slot" + nama file saran)
//   sources.csv  satu baris per kandidat (stage, slot, packId, URL, pembuat, ...)
//   cache/       hasil API per kata (dipakai ulang selama 24 jam)
//
// API key Pixabay dibaca dari environment PIXABAY_KEY dan tidak pernah dicetak.

const fs = require('node:fs');
const path = require('node:path');
const { parseArgs, printList } = require('./lib/puzzles');
const { WORDS_PATH, loadWords } = require('./lib/words');
const {
  fetchHits,
  parseStageRange,
  renderIndexHtml,
  sourcesRows,
  toSourcesCsv,
} = require('./lib/candidates');

const USAGE =
  'Pemakaian: node fetch_candidates.js [--stages 1-5] [--per 8] [--force] [--words words.txt] [--out folder]';

// Batas Pixabay: 100 permintaan / 60 detik.
const REQUEST_GAP_MS = 700;

const rel = (p) => path.relative(process.cwd(), p) || p;
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function main() {
  const args = parseArgs(process.argv.slice(2), {
    flags: ['force', 'help'],
    options: ['stages', 'per', 'words', 'out'],
  });
  if (args.help) {
    console.log(USAGE);
    return;
  }

  const key = (process.env.PIXABAY_KEY ?? '').trim();
  if (!key) {
    throw new Error(
      'Environment PIXABAY_KEY belum diisi. Ambil API key gratis di https://pixabay.com/api/docs/ ' +
        'lalu jalankan (PowerShell): $env:PIXABAY_KEY="kunci-anda"',
    );
  }

  const perPage = args.per === undefined ? 8 : Number(args.per);
  if (!Number.isInteger(perPage) || perPage < 3 || perPage > 200) {
    throw new Error('--per harus bilangan bulat 3..200.');
  }

  const wordsPath = path.resolve(args.words ?? WORDS_PATH);
  const words = loadWords(wordsPath);
  if (!words) throw new Error(`words.txt tidak ditemukan: ${wordsPath}`);
  printList('Masalah di words.txt (baris dilewati)', words.errors, console.warn);

  let entries = words.entries;
  if (args.stages !== undefined) {
    const range = parseStageRange(args.stages);
    if (!range) throw new Error('--stages harus berbentuk N atau A-B, mis. 3 atau 1-5.');
    entries = entries.filter((e) => e.stage >= range[0] && e.stage <= range[1]);
  }
  entries = [...entries].sort((a, b) => a.stage - b.stage || a.slot - b.slot);
  if (entries.length === 0) throw new Error('Tidak ada kata yang cocok.');

  const outDir = path.resolve(args.out ?? path.join(__dirname, 'candidates'));
  const cacheDir = path.join(outDir, 'cache');
  console.log(`Words       : ${rel(wordsPath)} (${entries.length} kata dipilih)`);
  console.log(`Hasil       : ${rel(outDir)}\n`);

  const groups = [];
  let requested = false;
  for (const entry of entries) {
    if (requested) await sleep(REQUEST_GAP_MS);
    const label = `stage ${entry.stage}/${entry.slot} ${entry.answer} ("${entry.keyword}")`;
    try {
      const { hits, fromCache } = await fetchHits(entry, {
        key,
        perPage,
        fetchImpl: fetch,
        cacheDir,
        force: Boolean(args.force),
      });
      requested = !fromCache;
      groups.push({ entry, hits });
      console.log(`  ${fromCache ? 'cache' : 'api  '}  ${label}: ${hits.length} kandidat`);
    } catch (e) {
      requested = true;
      groups.push({ entry, hits: [], error: e.message });
      console.error(`  gagal  ${label}: ${e.message}`);
    }
  }

  fs.mkdirSync(outDir, { recursive: true });
  fs.writeFileSync(path.join(outDir, 'sources.csv'), toSourcesCsv(sourcesRows(groups)));
  fs.writeFileSync(path.join(outDir, 'index.html'), renderIndexHtml(groups));

  const failed = groups.filter((g) => g.error).length;
  console.log(
    `\nSelesai: ${groups.length} kata, ${failed} gagal. Buka ${rel(path.join(outDir, 'index.html'))} ` +
      'di browser, lalu simpan gambar pilihan ke tools/picked/.',
  );
  if (failed > 0) process.exitCode = 1;
}

main().catch((e) => {
  console.error(`Gagal: ${e.message}`);
  process.exitCode = 1;
});
