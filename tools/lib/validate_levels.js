'use strict';

// Validasi levels.csv sebelum ditulis ke Firestore. Tanpa dependensi,
// sehingga bisa dites dengan `node --test` tanpa firebase-admin.

const COLUMNS = [
  'order',
  'packId',
  'imageFile',
  'answer',
  'focusX',
  'focusY',
  'difficulty',
  'active',
];

const ANSWER_RE = /^[A-Z]{3,12}$/;
const IMAGE_RE = /^[a-z0-9_-]+\.webp$/;

/**
 * CSV sederhana: dipisah koma, tanpa tanda kutip. Baris kosong dan baris
 * yang diawali `#` dilewati. Mengembalikan { rows, errors }, setiap row
 * membawa nomor baris aslinya (`line`).
 */
function parseCsv(text) {
  const errors = [];
  const rows = [];
  const lines = text.replace(/^﻿/, '').split(/\r?\n/);

  let headerLine = -1;
  for (let i = 0; i < lines.length; i++) {
    const raw = lines[i].trim();
    if (raw === '' || raw.startsWith('#')) continue;
    headerLine = i;
    break;
  }
  if (headerLine < 0) {
    return { rows, errors: ['CSV kosong (tidak ada header).'] };
  }

  const header = lines[headerLine].split(',').map((h) => h.trim());
  if (header.join(',') !== COLUMNS.join(',')) {
    errors.push(
      `Baris ${headerLine + 1}: header harus "${COLUMNS.join(',')}", ` +
        `ditemukan "${header.join(',')}".`,
    );
    return { rows, errors };
  }

  for (let i = headerLine + 1; i < lines.length; i++) {
    const raw = lines[i].trim();
    if (raw === '' || raw.startsWith('#')) continue;
    const cells = raw.split(',').map((c) => c.trim());
    if (cells.length !== COLUMNS.length) {
      errors.push(
        `Baris ${i + 1}: butuh ${COLUMNS.length} kolom, ada ${cells.length}.`,
      );
      continue;
    }
    const row = { line: i + 1 };
    COLUMNS.forEach((c, j) => {
      row[c] = cells[j];
    });
    rows.push(row);
  }
  return { rows, errors };
}

function parseIntStrict(s) {
  return /^-?\d+$/.test(s) ? Number(s) : NaN;
}

function parseNumberStrict(s) {
  return /^-?(\d+(\.\d+)?|\.\d+)$/.test(s) ? Number(s) : NaN;
}

/**
 * Validasi baris hasil parseCsv. Mengembalikan { levels, errors }.
 * `levels` hanya terisi jika tidak ada error sama sekali.
 */
function validateRows(rows) {
  const errors = [];
  const levels = [];
  const seenOrder = new Map();

  for (const r of rows) {
    const at = `Baris ${r.line}`;
    const rowErrors = [];

    const order = parseIntStrict(r.order);
    if (!Number.isInteger(order) || order <= 0) {
      rowErrors.push(`${at}: order "${r.order}" harus bilangan bulat > 0.`);
    } else if (seenOrder.has(order)) {
      rowErrors.push(
        `${at}: order ${order} sudah dipakai di baris ${seenOrder.get(order)}.`,
      );
    } else {
      seenOrder.set(order, r.line);
    }

    if (r.packId === '') rowErrors.push(`${at}: packId kosong.`);

    if (!IMAGE_RE.test(r.imageFile)) {
      rowErrors.push(
        `${at}: imageFile "${r.imageFile}" harus berakhiran .webp, ` +
          'huruf kecil, tanpa spasi (a-z, 0-9, _ atau -).',
      );
    }

    if (!ANSWER_RE.test(r.answer)) {
      rowErrors.push(
        `${at}: answer "${r.answer}" hanya boleh huruf A-Z (kapital), ` +
          'panjang 3-12.',
      );
    }

    const focusX = parseNumberStrict(r.focusX);
    const focusY = parseNumberStrict(r.focusY);
    for (const [name, v, rawV] of [
      ['focusX', focusX, r.focusX],
      ['focusY', focusY, r.focusY],
    ]) {
      if (Number.isNaN(v) || v < -1 || v > 1) {
        rowErrors.push(`${at}: ${name} "${rawV}" harus angka antara -1 dan 1.`);
      }
    }

    const difficulty = parseIntStrict(r.difficulty);
    if (!Number.isInteger(difficulty) || difficulty < 1) {
      rowErrors.push(
        `${at}: difficulty "${r.difficulty}" harus bilangan bulat >= 1.`,
      );
    }

    const activeRaw = r.active.toLowerCase();
    if (!['true', 'false'].includes(activeRaw)) {
      rowErrors.push(`${at}: active "${r.active}" harus true atau false.`);
    }

    if (rowErrors.length > 0) {
      errors.push(...rowErrors);
      continue;
    }
    levels.push({
      order,
      packId: r.packId,
      imageFile: r.imageFile,
      answer: r.answer,
      focusX,
      focusY,
      difficulty,
      active: activeRaw === 'true',
    });
  }

  return { levels: errors.length === 0 ? levels : [], errors };
}

/** "level_" + order 3 digit, mis. 7 -> level_007. */
function docId(order) {
  return `level_${String(order).padStart(3, '0')}`;
}

/** Isi dokumen Firestore. `id` = order agar Level.id di app konsisten. */
function toFirestoreDoc(level) {
  return { id: level.order, ...level };
}

/** Parse + validasi teks CSV sekaligus. */
function validateCsv(text) {
  const parsed = parseCsv(text);
  if (parsed.errors.length > 0) return { levels: [], errors: parsed.errors };
  const result = validateRows(parsed.rows);
  if (result.levels.length === 0 && result.errors.length === 0) {
    result.errors.push('CSV tidak berisi level.');
  }
  return result;
}

module.exports = {
  COLUMNS,
  parseCsv,
  validateRows,
  validateCsv,
  docId,
  toFirestoreDoc,
};
