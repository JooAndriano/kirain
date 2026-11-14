'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const {
  parseCsv,
  validateCsv,
  docId,
  toFirestoreDoc,
} = require('../lib/validate_levels');

const HEADER = 'order,packId,imageFile,answer,focusX,focusY,difficulty,active';
const csv = (...rows) => [HEADER, ...rows].join('\n');
const OK = '1,hewan,kucing.webp,KUCING,0,0,1,true';

test('CSV valid -> level terisi dengan tipe yang benar', () => {
  const { levels, errors } = validateCsv(
    csv(OK, '2,buah,pisang.webp,PISANG,-0.5,1,2,false') + '\r\n\r\n',
  );
  assert.deepEqual(errors, []);
  assert.equal(levels.length, 2);
  assert.deepEqual(levels[1], {
    order: 2,
    packId: 'buah',
    imageFile: 'pisang.webp',
    answer: 'PISANG',
    focusX: -0.5,
    focusY: 1,
    difficulty: 2,
    active: false,
  });
});

test('order harus bilangan bulat > 0 dan unik', () => {
  for (const bad of ['0', '-1', '1.5', 'satu', '']) {
    const { errors } = validateCsv(csv(`${bad},hewan,kucing.webp,KUCING,0,0,1,true`));
    assert.ok(errors.some((e) => e.includes('order')), `order "${bad}"`);
  }
  const { levels, errors } = validateCsv(csv(OK, '1,hewan,anjing.webp,ANJING,0,0,1,true'));
  assert.equal(levels.length, 0);
  assert.match(errors[0], /order 1 sudah dipakai di baris 2/);
});

test('answer hanya A-Z kapital, panjang 3-12', () => {
  for (const bad of ['KU', 'ABCDEFGHIJKLM', 'kucing', 'KUE LAPIS', 'KUC1NG', 'KÜCING']) {
    const { errors } = validateCsv(csv(`1,hewan,kucing.webp,${bad},0,0,1,true`));
    assert.ok(errors.some((e) => e.includes('answer')), `answer "${bad}"`);
  }
  for (const good of ['KUE', 'ABCDEFGHIJKL']) {
    assert.deepEqual(validateCsv(csv(`1,hewan,kucing.webp,${good},0,0,1,true`)).errors, []);
  }
});

test('focusX/focusY antara -1 dan 1', () => {
  for (const bad of ['1.01', '-1.5', 'tengah', '']) {
    const { errors } = validateCsv(csv(`1,hewan,kucing.webp,KUCING,${bad},0,1,true`));
    assert.ok(errors.some((e) => e.includes('focusX')), `focusX "${bad}"`);
  }
  assert.deepEqual(validateCsv(csv('1,hewan,kucing.webp,KUCING,-1,1,1,true')).errors, []);
  assert.deepEqual(validateCsv(csv('1,hewan,kucing.webp,KUCING,.5,-0.25,1,true')).errors, []);
});

test('imageFile .webp, huruf kecil, tanpa spasi', () => {
  for (const bad of ['Kucing.webp', 'kucing.png', 'kucing lucu.webp', 'img/kucing.webp', 'kucing.WEBP', '.webp']) {
    const { errors } = validateCsv(csv(`1,hewan,${bad},KUCING,0,0,1,true`));
    assert.ok(errors.some((e) => e.includes('imageFile')), `imageFile "${bad}"`);
  }
  assert.deepEqual(validateCsv(csv('1,hewan,kucing_01-a.webp,KUCING,0,0,1,true')).errors, []);
});

test('difficulty, active, packId diperiksa', () => {
  const { errors } = validateCsv(csv('1,,kucing.webp,KUCING,0,0,0,ya'));
  assert.ok(errors.some((e) => e.includes('packId')));
  assert.ok(errors.some((e) => e.includes('difficulty')));
  assert.ok(errors.some((e) => e.includes('active')));
});

test('header salah atau jumlah kolom salah ditolak', () => {
  assert.match(validateCsv('order,answer\n1,KUCING').errors[0], /header/);
  assert.match(validateCsv(csv('1,hewan,kucing.webp,KUCING,0,0,1')).errors[0], /butuh 8 kolom/);
  assert.match(validateCsv('').errors[0], /kosong/);
  assert.match(validateCsv(HEADER).errors[0], /tidak berisi level/);
});

test('satu baris salah -> tidak ada level yang dikembalikan (tidak menulis sebagian)', () => {
  const { levels, errors } = validateCsv(csv(OK, '2,buah,pisang.webp,pisang,0,0,1,true'));
  assert.equal(levels.length, 0);
  assert.equal(errors.length, 1);
  assert.match(errors[0], /^Baris 3:/);
});

test('parseCsv melewati baris kosong dan komentar', () => {
  const { rows, errors } = parseCsv(`# komentar\n${HEADER}\n\n${OK}\n# lagi\n`);
  assert.deepEqual(errors, []);
  assert.equal(rows.length, 1);
  assert.equal(rows[0].line, 4);
});

test('docId memakai 3 digit', () => {
  assert.equal(docId(1), 'level_001');
  assert.equal(docId(42), 'level_042');
  assert.equal(docId(999), 'level_999');
  assert.equal(docId(1000), 'level_1000');
});

test('dokumen Firestore memuat id = order', () => {
  const [level] = validateCsv(csv(OK)).levels;
  assert.deepEqual(toFirestoreDoc(level), { id: 1, ...level });
});
