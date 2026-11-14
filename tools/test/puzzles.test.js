'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const {
  buildRows,
  checkProject,
  difficultyFor,
  docId,
  parseCsv,
  parseFilename,
  scanFiles,
  toCsv,
  toFirestoreDoc,
  validate,
} = require('../lib/puzzles');

const TOOLS = path.join(__dirname, '..');

/** 2 stage contoh = 6 gambar .webp (isi dummy, ukuran kecil). */
const SAMPLE = [
  'hewan/kucing_1.webp',
  'hewan/gajah_1.webp',
  'hewan/ayam_1_b.webp',
  'buah/pisang_2.webp',
  'buah/mangga_2.webp',
  'buah/semangka_2.webp',
];

function tmpDir() {
  return fs.mkdtempSync(path.join(os.tmpdir(), 'kirain-tools-'));
}

function makeImages(files, { size = 1024 } = {}) {
  const dir = tmpDir();
  for (const rel of files) {
    const abs = path.join(dir, rel);
    fs.mkdirSync(path.dirname(abs), { recursive: true });
    fs.writeFileSync(abs, Buffer.alloc(size, 1));
  }
  return dir;
}

function run(script, args) {
  return spawnSync(process.execPath, [path.join(TOOLS, script), ...args], {
    encoding: 'utf8',
    cwd: TOOLS,
  });
}

/** Baris CSV valid untuk 2 stage (sesuai SAMPLE). */
function validRows() {
  return [
    [1, 1, 'hewan', 'ayam_1_b.webp', 'AYAM'],
    [1, 2, 'hewan', 'gajah_1.webp', 'GAJAH'],
    [1, 3, 'hewan', 'kucing_1.webp', 'KUCING'],
    [2, 1, 'buah', 'mangga_2.webp', 'MANGGA'],
    [2, 2, 'buah', 'pisang_2.webp', 'PISANG'],
    [2, 3, 'buah', 'semangka_2.webp', 'SEMANGKA'],
  ].map(([stage, slot, packId, imageFile, answer], i) => ({
    line: i + 2,
    stage: String(stage),
    slot: String(slot),
    packId,
    imageFile,
    answer,
    focusX: '0.1',
    focusY: '-0.2',
    difficulty: '1',
    active: 'true',
  }));
}

test('parseFilename: pola jawaban_stage[_akhiran].webp', () => {
  assert.deepEqual(parseFilename('kucing_3.webp'), { answer: 'KUCING', stage: 3 });
  assert.deepEqual(parseFilename('ayam_1_b.webp'), { answer: 'AYAM', stage: 1 });
  assert.deepEqual(parseFilename('ayam_12_x_2.webp'), { answer: 'AYAM', stage: 12 });
  assert.equal(parseFilename('Kucing_1.webp'), null);
  assert.equal(parseFilename('kucing.webp'), null);
  assert.equal(parseFilename('kucing_1.png'), null);
  assert.equal(parseFilename('ku cing_1.webp'), null);
});

test('difficultyFor dari panjang jawaban', () => {
  assert.equal(difficultyFor('AYAM'), 1);
  assert.equal(difficultyFor('GAJAH'), 2);
  assert.equal(difficultyFor('KUCING'), 2);
  assert.equal(difficultyFor('SEMANGKA'), 3);
});

test('buildRows: stage, slot abjad, packId, fokus acak, difficulty', () => {
  const dir = makeImages([...SAMPLE, 'sapi_1.webp', 'JELEK.webp', 'catatan.txt']);
  const { rows, skipped, warnings } = buildRows(scanFiles(dir));

  assert.deepEqual(skipped, ['JELEK.webp']);
  // sapi_1.webp (root, pack umum) menjadi stage 1 slot ke-4 -> peringatan.
  assert.equal(warnings.length, 1);
  assert.match(warnings[0], /Stage 1 berisi 4 gambar/);

  const stage1 = rows.filter((r) => r.stage === 1).map((r) => [r.slot, r.imageFile, r.packId]);
  assert.deepEqual(stage1, [
    [1, 'ayam_1_b.webp', 'hewan'],
    [2, 'gajah_1.webp', 'hewan'],
    [3, 'kucing_1.webp', 'hewan'],
    [4, 'sapi_1.webp', 'umum'],
  ]);
  for (const r of rows) {
    assert.ok(r.focusX >= -0.6 && r.focusX <= 0.6);
    assert.ok(r.focusY >= -0.6 && r.focusY <= 0.6);
    assert.equal(Math.round(r.focusX * 100) / 100, r.focusX);
    assert.equal(r.active, true);
    assert.equal(r.difficulty, difficultyFor(r.answer));
  }
  assert.equal(rows.find((r) => r.imageFile === 'semangka_2.webp').answer, 'SEMANGKA');
});

test('buildRows --start-stage menggeser nomor stage', () => {
  const dir = makeImages(SAMPLE);
  const { rows } = buildRows(scanFiles(dir), { startStage: 10 });
  assert.deepEqual([...new Set(rows.map((r) => r.stage))], [10, 11]);
});

test('make -> check: 2 stage contoh (6 gambar) lulus', () => {
  const images = makeImages(SAMPLE);
  const out = path.join(tmpDir(), 'puzzles.csv');

  const make = run('make_puzzles_csv.js', [images, '--out', out]);
  assert.equal(make.status, 0, make.stderr);
  const csv = fs.readFileSync(out, 'utf8');
  assert.match(csv, /^stage,slot,packId,imageFile,answer,focusX,focusY,difficulty,active\n/);
  assert.equal(csv.trim().split('\n').length, 7);

  const check = run('check_images.js', ['--csv', out, '--images', images]);
  assert.equal(check.status, 0, check.stdout + check.stderr);
  assert.match(check.stdout, /Validasi OK: 6 gambar, 2 stage/);

  const seed = run('seed_puzzles.js', ['--dry-run', '--csv', out, '--images', images]);
  assert.equal(seed.status, 0, seed.stdout + seed.stderr);
  assert.match(seed.stdout, /puzzles\/stage_002_3/);
  assert.match(seed.stdout, /tidak ada yang ditulis/);
});

test('make tidak menimpa CSV tanpa --force', () => {
  const images = makeImages(SAMPLE);
  const out = path.join(tmpDir(), 'puzzles.csv');
  fs.writeFileSync(out, 'lama');

  const blocked = run('make_puzzles_csv.js', [images, '--out', out]);
  assert.equal(blocked.status, 1);
  assert.match(blocked.stderr, /--force/);
  assert.equal(fs.readFileSync(out, 'utf8'), 'lama');

  const forced = run('make_puzzles_csv.js', [images, '--out', out, '--force']);
  assert.equal(forced.status, 0, forced.stderr);
  assert.notEqual(fs.readFileSync(out, 'utf8'), 'lama');
});

test('seed --dry-run menolak CSV tidak valid tanpa menulis', () => {
  const images = makeImages(SAMPLE);
  const out = path.join(tmpDir(), 'puzzles.csv');
  const rows = validRows().slice(0, 5); // stage 2 kurang satu
  fs.writeFileSync(
    out,
    toCsv(rows.map((r) => ({ ...r }))),
  );
  const seed = run('seed_puzzles.js', ['--dry-run', '--csv', out, '--images', images]);
  assert.equal(seed.status, 1);
  assert.match(seed.stderr, /Tidak ada yang ditulis/);
});

test('parseCsv: pemisah titik koma dan desimal koma (Excel Indonesia)', () => {
  const text =
    '﻿stage;slot;packId;imageFile;answer;focusX;focusY;difficulty;active\r\n' +
    '1;1;hewan;ayam_1_b.webp;AYAM;0,25;-0,5;1;TRUE\r\n' +
    ';;;;;;;;\r\n';
  const { rows, errors, delimiter } = parseCsv(text);
  assert.deepEqual(errors, []);
  assert.equal(delimiter, ';');
  assert.equal(rows.length, 1);
  const { errors: vErrors } = validate(rows, null);
  // Hanya error struktur stage (1 gambar), bukan error angka/active.
  assert.ok(vErrors.every((e) => /Stage 1|slot/.test(e)), vErrors.join('\n'));
});

test('validate: CSV valid + gambar lengkap lulus, file tak terpakai = peringatan', () => {
  const images = scanFiles(makeImages([...SAMPLE, 'hewan/sapi_9.webp']));
  const { puzzles, errors, warnings } = validate(validRows(), images);
  assert.deepEqual(errors, []);
  assert.equal(puzzles.length, 6);
  assert.deepEqual(warnings, ['File hewan/sapi_9.webp tidak dipakai di CSV.']);
});

test('validate: slot hilang / ganda', () => {
  const rows = validRows();
  rows[2].slot = '2'; // stage 1: slot 1,2,2
  const { errors } = validate(rows, null);
  assert.ok(errors.some((e) => /Stage 1: harus tepat 3 gambar/.test(e)), errors.join('\n'));
});

test('validate: celah nomor stage', () => {
  const rows = validRows().map((r) => (r.stage === '2' ? { ...r, stage: '3' } : r));
  const { errors } = validate(rows, null);
  assert.ok(errors.some((e) => /stage 2 tidak ada/.test(e)), errors.join('\n'));

  const noOne = validRows().map((r) => ({ ...r, stage: String(Number(r.stage) + 1) }));
  assert.ok(validate(noOne, null).errors.some((e) => /stage 1 tidak ada/.test(e)));
});

test('validate: answer kembar dalam satu stage, packId campur', () => {
  const rows = validRows();
  rows[1].answer = 'AYAM';
  rows[4].packId = 'lain';
  const { errors } = validate(rows, null);
  assert.ok(errors.some((e) => /answer AYAM kembar/.test(e)), errors.join('\n'));
  assert.ok(errors.some((e) => /Stage 2: packId harus sama/.test(e)), errors.join('\n'));
});

test('validate: aturan per baris', () => {
  const rows = validRows();
  rows[0].answer = 'AB';
  rows[1].answer = 'Gajah';
  rows[2].focusX = '1.5';
  rows[3].imageFile = 'Mangga 2.webp';
  rows[4].imageFile = 'pisang_2.png';
  rows[5].active = 'ya';
  const { errors, puzzles } = validate(rows, null);
  assert.equal(puzzles.length, 0);
  for (const re of [
    /Baris 2: answer "AB"/,
    /Baris 3: answer "Gajah"/,
    /Baris 4: focusX "1.5"/,
    /Baris 5: imageFile "Mangga 2.webp"/,
    /Baris 6: imageFile "pisang_2.png"/,
    /Baris 7: active "ya"/,
  ]) {
    assert.ok(errors.some((e) => re.test(e)), `${re} tidak ditemukan:\n${errors.join('\n')}`);
  }
});

test('validate: file tidak ada, terlalu besar, nama ganda antar folder', () => {
  const dir = makeImages(SAMPLE.filter((f) => !f.includes('kucing')));
  fs.writeFileSync(path.join(dir, 'buah', 'mangga_2.webp'), Buffer.alloc(301 * 1024));
  fs.mkdirSync(path.join(dir, 'lain'));
  fs.writeFileSync(path.join(dir, 'lain', 'gajah_1.webp'), 'x');

  const { errors } = validate(validRows(), scanFiles(dir));
  assert.ok(errors.some((e) => /kucing_1.webp tidak ada/.test(e)), errors.join('\n'));
  assert.ok(errors.some((e) => /mangga_2.webp berukuran 301 KB/.test(e)), errors.join('\n'));
  assert.ok(errors.some((e) => /gajah_1.webp ada di lebih dari satu folder/.test(e)));
});

test('checkProject: CSV atau folder tidak ada', () => {
  const dir = tmpDir();
  assert.match(
    checkProject({ csvPath: path.join(dir, 'x.csv'), imagesDir: dir }).errors[0],
    /CSV tidak ditemukan/,
  );
  fs.writeFileSync(path.join(dir, 'p.csv'), 'a');
  assert.match(
    checkProject({ csvPath: path.join(dir, 'p.csv'), imagesDir: path.join(dir, 'tidak') })
      .errors[0],
    /Folder gambar tidak ditemukan/,
  );
});

test('docId dan isi dokumen Firestore', () => {
  assert.equal(docId(3, 2), 'stage_003_2');
  assert.equal(docId(120, 1), 'stage_120_1');
  const { puzzles } = validate(validRows(), null);
  const doc = toFirestoreDoc(puzzles[0]);
  assert.deepEqual(Object.keys(doc).sort(), [
    'active',
    'answer',
    'difficulty',
    'focusX',
    'focusY',
    'imageFile',
    'packId',
    'slot',
    'stage',
  ]);
  assert.equal(doc.focusX, 0.1);
  assert.equal(doc.line, undefined);
});
