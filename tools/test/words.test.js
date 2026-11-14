'use strict';

// Tes alur words.txt dengan data contoh 2 stage (6 gambar).

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const { buildRows, checkProject, scanFiles, wordsWithoutImages } = require('../lib/puzzles');
const { loadWords, parseWords, suggestedFileName, wordKey } = require('../lib/words');
const { parsePickedName, planConversions, convertToWebp } = require('../lib/picked');
const {
  buildSearchUrl,
  fetchHits,
  parseStageRange,
  redact,
  renderIndexHtml,
  sourcesRows,
  toSourcesCsv,
} = require('../lib/candidates');

const TOOLS = path.join(__dirname, '..');

const WORDS = `# jawaban|keyword|stage|slot|packId
jeruk|orange fruit|1|1|pasar
semangka|watermelon|1|2|pasar

apel|red apple|1|3|pasar
pisang|banana bunch|2|1|pasar
nanas|pineapple|2|2|pasar
anggur|grapes|2|3|pasar
`;

function tmpDir() {
  return fs.mkdtempSync(path.join(os.tmpdir(), 'kirain-words-'));
}

function writeWords(text = WORDS) {
  const file = path.join(tmpDir(), 'words.txt');
  fs.writeFileSync(file, text);
  return file;
}

function makeFiles(files, { size = 512 } = {}) {
  const dir = tmpDir();
  for (const rel of files) {
    const abs = path.join(dir, rel);
    fs.mkdirSync(path.dirname(abs), { recursive: true });
    fs.writeFileSync(abs, Buffer.alloc(size, 1));
  }
  return dir;
}

function run(script, args, env = {}) {
  return spawnSync(process.execPath, [path.join(TOOLS, script), ...args], {
    encoding: 'utf8',
    cwd: TOOLS,
    env: { ...process.env, ...env },
  });
}

/** Gambar 2 stage contoh, sengaja di subfolder "buah" (bukan packId). */
const IMAGES = [
  'buah/apel_1.webp',
  'buah/jeruk_1.webp',
  'buah/semangka_1.webp',
  'buah/anggur_2.webp',
  'buah/nanas_2.webp',
  'buah/pisang_2.webp',
];

// ---------------------------------------------------------------------------
// words.txt
// ---------------------------------------------------------------------------

test('parseWords: 5 kolom, abaikan baris kosong dan #', () => {
  const { entries, errors } = parseWords(WORDS);
  assert.deepEqual(errors, []);
  assert.equal(entries.length, 6);
  assert.deepEqual(entries[1], {
    line: 3,
    answer: 'semangka',
    keyword: 'watermelon',
    stage: 1,
    slot: 2,
    packId: 'pasar',
    key: 'semangka_1',
  });
  assert.equal(wordKey('KUCING', 31), 'kucing_31');
  assert.equal(suggestedFileName(entries[0]), 'jeruk_1.jpg');
});

test('parseWords: baris bermasalah dilaporkan dan dilewati', () => {
  const { entries, errors } = parseWords(
    [
      'jeruk|orange|1|1|pasar',
      'jeruk|orange lagi|1|2|pasar', // (jawaban, stage) kembar
      'apel|apple|1|1|pasar', // slot kembar
      'ab|x|1|3|pasar', // jawaban terlalu pendek
      'tomat||2|1|pasar', // keyword kosong
      'wortel|carrot|2|4|pasar', // slot salah
      'jagung|corn|x|1|pasar', // stage salah
      'kol|cabbage|2|3|Pa sar', // packId salah
      'empat|kolom|saja|1',
    ].join('\n'),
  );
  assert.equal(entries.length, 1);
  assert.equal(errors.length, 8);
  assert.match(errors[0], /baris 2: jeruk di stage 1 sudah ada di baris 1/);
  assert.match(errors[1], /baris 3: stage 1 slot 1 sudah dipakai/);
  assert.match(errors.at(-1), /baris 9: butuh 5 kolom/);
});

test('loadWords: file tidak ada -> null', () => {
  assert.equal(loadWords(path.join(tmpDir(), 'tidak-ada.txt')), null);
  const w = loadWords(writeWords());
  assert.equal(w.byKey.get('nanas_2').slot, 2);
});

// ---------------------------------------------------------------------------
// make_puzzles_csv
// ---------------------------------------------------------------------------

test('buildRows + words: slot dan packId dari words.txt, bukan abjad/subfolder', () => {
  const words = loadWords(writeWords());
  const { rows, warnings } = buildRows(scanFiles(makeFiles(IMAGES)), { words });
  assert.deepEqual(warnings, []);
  assert.deepEqual(
    rows.map((r) => [r.stage, r.slot, r.answer, r.packId]),
    [
      [1, 1, 'JERUK', 'pasar'],
      [1, 2, 'SEMANGKA', 'pasar'],
      [1, 3, 'APEL', 'pasar'],
      [2, 1, 'PISANG', 'pasar'],
      [2, 2, 'NANAS', 'pasar'],
      [2, 3, 'ANGGUR', 'pasar'],
    ],
  );
  // Tanpa words: perilaku lama (abjad, subfolder).
  const old = buildRows(scanFiles(makeFiles(IMAGES))).rows;
  assert.deepEqual(old.slice(0, 3).map((r) => [r.answer, r.slot, r.packId]), [
    ['APEL', 1, 'buah'],
    ['JERUK', 2, 'buah'],
    ['SEMANGKA', 3, 'buah'],
  ]);
});

test('buildRows + words: tidak cocok -> perilaku lama + peringatan', () => {
  const words = loadWords(writeWords());
  const files = IMAGES.filter((f) => !f.includes('apel')).concat([
    'buah/belimbing_1.webp', // tidak ada di words.txt
    'buah/jeruk_1_b.webp', // varian kedua jeruk_1
  ]);
  const { rows, warnings } = buildRows(scanFiles(makeFiles(files)), { words });
  assert.equal(warnings.length, 3);
  assert.ok(warnings.some((w) => /belimbing_1.webp: \(belimbing, stage 1\) tidak ada di words.txt/.test(w)));
  assert.ok(warnings.some((w) => /jeruk_1_b.webp: jeruk_1 sudah dipakai buah\/jeruk_1.webp/.test(w)));
  assert.ok(warnings.some((w) => /Stage 1 berisi 4 gambar/.test(w)));

  const stage1 = rows.filter((r) => r.stage === 1).map((r) => [r.slot, r.imageFile, r.packId]);
  // Slot 1 & 2 dari words; sisanya mengisi slot kosong terkecil sesuai abjad.
  assert.deepEqual(stage1, [
    [1, 'jeruk_1.webp', 'pasar'],
    [2, 'semangka_1.webp', 'pasar'],
    [3, 'belimbing_1.webp', 'buah'],
    [4, 'jeruk_1_b.webp', 'buah'],
  ]);
});

test('make_puzzles_csv --words -> check_images lulus (2 stage contoh)', () => {
  const images = makeFiles(IMAGES);
  const wordsFile = writeWords();
  const out = path.join(tmpDir(), 'puzzles.csv');

  const make = run('make_puzzles_csv.js', [images, '--out', out, '--words', wordsFile]);
  assert.equal(make.status, 0, make.stderr);
  const lines = fs.readFileSync(out, 'utf8').trim().split('\n');
  assert.match(lines[1], /^1,1,pasar,jeruk_1\.webp,JERUK,/);
  assert.match(lines[6], /^2,3,pasar,anggur_2\.webp,ANGGUR,/);

  const check = run('check_images.js', ['--csv', out, '--images', images, '--words', wordsFile]);
  assert.equal(check.status, 0, check.stdout + check.stderr);
  assert.match(check.stdout, /Validasi OK: 6 gambar, 2 stage\./);
  assert.doesNotMatch(check.stderr, /belum punya gambar/);
});

test('make_puzzles_csv --words file tidak ada -> gagal', () => {
  const r = run('make_puzzles_csv.js', [
    makeFiles(IMAGES),
    '--out',
    path.join(tmpDir(), 'p.csv'),
    '--words',
    path.join(tmpDir(), 'tidak.txt'),
  ]);
  assert.equal(r.status, 1);
  assert.match(r.stderr, /words.txt tidak ditemukan/);
});

// ---------------------------------------------------------------------------
// check_images
// ---------------------------------------------------------------------------

test('check_images: kata di words.txt tanpa gambar dilaporkan (bukan error)', () => {
  const words = loadWords(writeWords());
  const images = makeFiles(IMAGES.filter((f) => !/nanas|apel/.test(f)));
  assert.deepEqual(
    wordsWithoutImages(words, scanFiles(images)).map((e) => e.key),
    ['apel_1', 'nanas_2'],
  );

  // Lewat CLI: CSV berisi 4 gambar yang ada -> error struktur stage, tetapi
  // daftar kata tanpa gambar tetap tercetak.
  const csv = path.join(tmpDir(), 'puzzles.csv');
  fs.writeFileSync(
    csv,
    [
      'stage,slot,packId,imageFile,answer,focusX,focusY,difficulty,active',
      '1,1,pasar,jeruk_1.webp,JERUK,0,0,2,true',
      '1,2,pasar,semangka_1.webp,SEMANGKA,0,0,3,true',
      '2,1,pasar,pisang_2.webp,PISANG,0,0,2,true',
      '2,3,pasar,anggur_2.webp,ANGGUR,0,0,2,true',
    ].join('\n'),
  );
  const r = run('check_images.js', ['--csv', csv, '--images', images, '--words', words.path]);
  assert.match(r.stderr, /belum punya gambar di folder gambar \(2\)/);
  assert.match(r.stderr, /apel_1\.webp {2}\(stage 1, gambar 3, pasar; baris 5\)/);
  assert.match(r.stderr, /nanas_2\.webp {2}\(stage 2, gambar 2, pasar; baris 7\)/);

  const result = checkProject({ csvPath: csv, imagesDir: images, words });
  assert.equal(result.missingWords.length, 2);
});

test('check_images: masalah words.txt menjadi peringatan', () => {
  const words = loadWords(writeWords(`${WORDS}rusak|baris\n`));
  const images = makeFiles(IMAGES);
  const csv = path.join(tmpDir(), 'p.csv');
  fs.writeFileSync(csv, 'x');
  const result = checkProject({ csvPath: csv, imagesDir: images, words });
  assert.ok(result.warnings.some((w) => /butuh 5 kolom/.test(w)));
});

// ---------------------------------------------------------------------------
// convert_picked
// ---------------------------------------------------------------------------

test('parsePickedName', () => {
  assert.deepEqual(parsePickedName('jeruk_1.jpg'), { answer: 'jeruk', stage: 1, base: 'jeruk_1' });
  assert.deepEqual(parsePickedName('apel_1_b.JPG'), { answer: 'apel', stage: 1, base: 'apel_1_b' });
  assert.equal(parsePickedName('Jeruk_1.jpg'), null);
  assert.equal(parsePickedName('jeruk.jpg'), null);
  assert.equal(parsePickedName('jeruk_1.gif'), null);
});

test('planConversions: cocokkan (jawaban, stage), laporkan yang tidak dikenal', () => {
  const words = loadWords(writeWords());
  const picked = makeFiles([
    'jeruk_1.jpg',
    'pisang_2.png',
    'jeruk_2.jpg', // jeruk ada, tapi di stage 1
    'kucing_31.jpg', // tidak ada di words contoh
    'foto.jpg',
    'jeruk_1.png', // output sama dengan jeruk_1.jpg
  ]);
  const { jobs, unknown } = planConversions(scanFiles(picked), words);
  assert.deepEqual(jobs.map((j) => [j.file.name, j.outRel]), [
    ['jeruk_1.jpg', 'pasar/jeruk_1.webp'],
    ['pisang_2.png', 'pasar/pisang_2.webp'],
  ]);
  const reasons = Object.fromEntries(unknown.map((u) => [u.rel, u.reason]));
  assert.match(reasons['jeruk_2.jpg'], /\(jeruk, stage 2\) tidak ada di words.txt/);
  assert.match(reasons['kucing_31.jpg'], /tidak ada di words.txt/);
  assert.match(reasons['foto.jpg'], /nama tidak cocok pola/);
  assert.match(reasons['jeruk_1.png'], /pasar\/jeruk_1.webp yang sama/);
});

let sharp = null;
try {
  sharp = require('sharp');
} catch {
  // Lewati tes konversi jika sharp belum terpasang.
}

test('convert_picked: 2 stage contoh -> webp <= 300 KB di images/<packId>/', { skip: !sharp }, async () => {
  const picked = tmpDir();
  const images = tmpDir();
  const wordsFile = writeWords();
  const names = ['jeruk_1', 'semangka_1', 'apel_1', 'pisang_2', 'nanas_2', 'anggur_2'];
  for (const [i, n] of names.entries()) {
    // Gambar acak 1600x1200 (noise sulit dikompres) agar kompresi diuji.
    const raw = Buffer.alloc(1600 * 1200 * 3);
    for (let j = 0; j < raw.length; j++) raw[j] = (j * 2654435761 + i * 97) & 0xff;
    await sharp(raw, { raw: { width: 1600, height: 1200, channels: 3 } })
      .jpeg({ quality: 95 })
      .toFile(path.join(picked, `${n}.jpg`));
  }
  fs.writeFileSync(path.join(picked, 'misteri_9.jpg'), 'bukan gambar');

  const r = run('convert_picked.js', ['--picked', picked, '--images', images, '--words', wordsFile]);
  assert.equal(r.status, 1, 'ada file tidak dikenal -> kode keluar 1');
  assert.match(r.stderr, /misteri_9.jpg: pasangan \(misteri, stage 9\) tidak ada di words.txt/);
  assert.match(r.stdout, /6 dikonversi, 0 dilewati, 1 tidak dikenal, 0 gagal/);

  for (const n of names) {
    const out = path.join(images, 'pasar', `${n}.webp`);
    const meta = await sharp(out).metadata();
    assert.equal(meta.format, 'webp');
    assert.ok(Math.max(meta.width, meta.height) <= 1024);
    assert.ok(fs.statSync(out).size <= 300 * 1024);
  }

  // Jalan ulang: dilewati karena sudah ada; hasilnya lolos make -> check.
  fs.rmSync(path.join(picked, 'misteri_9.jpg'));
  const again = run('convert_picked.js', ['--picked', picked, '--images', images, '--words', wordsFile]);
  assert.equal(again.status, 0, again.stderr);
  assert.match(again.stdout, /0 dikonversi, 6 dilewati/);

  const csv = path.join(tmpDir(), 'puzzles.csv');
  assert.equal(run('make_puzzles_csv.js', [images, '--out', csv, '--words', wordsFile]).status, 0);
  const check = run('check_images.js', ['--csv', csv, '--images', images, '--words', wordsFile]);
  assert.equal(check.status, 0, check.stdout + check.stderr);
});

test('convertToWebp: gambar kecil tidak diperbesar', { skip: !sharp }, async () => {
  const dir = tmpDir();
  const input = path.join(dir, 'kecil.png');
  await sharp({ create: { width: 300, height: 200, channels: 3, background: '#ff8a3d' } })
    .png()
    .toFile(input);
  const out = path.join(dir, 'pasar', 'kecil.webp');
  const r = await convertToWebp(sharp, input, out);
  assert.equal(r.quality, 82);
  const meta = await sharp(out).metadata();
  assert.deepEqual([meta.width, meta.height], [300, 200]);
});

// ---------------------------------------------------------------------------
// fetch_candidates (tanpa internet: fetch palsu)
// ---------------------------------------------------------------------------

function fakeHit(id, entry) {
  return {
    id,
    pageURL: `https://pixabay.com/photos/${entry.answer}-${id}/`,
    previewURL: `https://cdn.pixabay.test/${id}_150.jpg`,
    webformatURL: `https://cdn.pixabay.test/${id}_640.jpg`,
    largeImageURL: `https://cdn.pixabay.test/${id}_1280.jpg`,
    user: 'fotografer',
    tags: `${entry.keyword}, fruit, "segar"`,
  };
}

test('buildSearchUrl memakai keyword; redact menyembunyikan key', () => {
  const url = new URL(buildSearchUrl({ key: 'RAHASIA', keyword: 'orange fruit', perPage: 8 }));
  assert.equal(url.searchParams.get('q'), 'orange fruit');
  assert.equal(url.searchParams.get('image_type'), 'photo');
  assert.equal(url.searchParams.get('per_page'), '8');
  assert.equal(redact('gagal ?key=RAHASIA&q=x', 'RAHASIA'), 'gagal ?key=***&q=x');
  assert.deepEqual(parseStageRange('3'), [3, 3]);
  assert.deepEqual(parseStageRange('1-5'), [1, 5]);
  assert.equal(parseStageRange('5-1'), null);
});

test('fetchHits: cache 24 jam, error tanpa membocorkan key', async () => {
  const { entries } = parseWords(WORDS);
  const cacheDir = tmpDir();
  let calls = 0;
  const fetchImpl = async (url) => {
    calls++;
    const q = new URL(url).searchParams.get('q');
    const entry = entries.find((e) => e.keyword === q);
    return {
      ok: true,
      json: async () => ({ hits: [fakeHit(1, entry), fakeHit(2, entry)] }),
    };
  };
  let now = 1_000_000;
  const opts = { key: 'K', perPage: 8, fetchImpl, cacheDir, now: () => now };

  const a = await fetchHits(entries[0], opts);
  assert.equal(a.fromCache, false);
  assert.equal(a.hits.length, 2);
  const b = await fetchHits(entries[0], opts);
  assert.equal(b.fromCache, true);
  assert.equal(calls, 1);
  now += 25 * 60 * 60 * 1000;
  await fetchHits(entries[0], opts);
  assert.equal(calls, 2);
  assert.doesNotMatch(fs.readFileSync(path.join(cacheDir, 'jeruk_1.json'), 'utf8'), /"key"/);

  const failing = async () => ({ ok: false, status: 400, text: async () => '[ERROR 400] key K salah' });
  await assert.rejects(
    fetchHits(entries[1], { ...opts, fetchImpl: failing, force: true }),
    (e) => /HTTP 400/.test(e.message) && !/ K /.test(e.message),
  );
});

test('sources.csv membawa stage/slot/packId; index.html "Stage N, Gambar slot" + nama file', () => {
  const { entries } = parseWords(WORDS);
  const groups = entries.map((entry, i) => ({ entry, hits: [fakeHit(100 + i, entry)] }));
  groups[5] = { entry: entries[5], hits: [], error: 'Pixabay HTTP 429' };

  const csv = toSourcesCsv(sourcesRows(groups));
  const lines = csv.trim().split('\n');
  assert.equal(
    lines[0],
    'answer,keyword,stage,slot,packId,suggestedFile,pixabayId,pageURL,largeImageURL,webformatURL,user,tags',
  );
  assert.equal(lines.length, 6); // 5 kata dengan 1 kandidat
  assert.match(lines[2], /^semangka,watermelon,1,2,pasar,semangka_1\.jpg,101,/);
  assert.match(lines[2], /,"watermelon, fruit, ""segar"""$/);

  const html = renderIndexHtml(groups, { generatedAt: new Date('2026-11-14T00:00:00Z') });
  assert.match(html, /<div class="where">Stage 1, Gambar 2<\/div>/);
  assert.match(html, /<code>semangka_1\.jpg<\/code>/);
  assert.match(html, /<div class="where">Stage 2, Gambar 1<\/div>[\s\S]*?pisang_2\.jpg/);
  assert.match(html, /Gagal: Pixabay HTTP 429/);
  assert.match(html, /&quot;segar&quot;/); // tag di-escape
});

test('fetch_candidates tanpa PIXABAY_KEY -> pesan jelas, tanpa jaringan', () => {
  const r = run('fetch_candidates.js', ['--words', writeWords(), '--out', tmpDir()], {
    PIXABAY_KEY: '',
  });
  assert.equal(r.status, 1);
  assert.match(r.stderr, /PIXABAY_KEY belum diisi/);
});
