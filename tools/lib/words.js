'use strict';

// Daftar kata (tools/words.txt): satu baris per gambar,
//   jawaban|keyword|stage|slot|packId
// Baris kosong dan baris berawalan "#" diabaikan. Tanpa dependensi.

const fs = require('node:fs');
const path = require('node:path');

const WORDS_PATH = path.join(__dirname, '..', 'words.txt');
const WORD_COLUMNS = ['jawaban', 'keyword', 'stage', 'slot', 'packId'];

const ANSWER_RE = /^[a-z]{3,12}$/;
const PACK_RE = /^[a-z0-9_-]+$/;

/** Kunci pencocokan gambar <-> kata: "jawaban_stage", mis. "kucing_31". */
function wordKey(answer, stage) {
  return `${String(answer).toLowerCase()}_${Number(stage)}`;
}

/**
 * Parse isi words.txt. Mengembalikan { entries, errors }.
 * entry = { line, answer (huruf kecil), keyword, stage, slot, packId, key }.
 * Baris bermasalah tidak masuk entries.
 */
function parseWords(text) {
  const entries = [];
  const errors = [];
  const byKey = new Map();
  const bySlot = new Map();
  const lines = text.replace(/^﻿/, '').split(/\r?\n/);

  lines.forEach((rawLine, i) => {
    const raw = rawLine.trim();
    if (raw === '' || raw.startsWith('#')) return;
    const at = `words.txt baris ${i + 1}`;
    const cells = raw.split('|').map((c) => c.trim());
    if (cells.length !== WORD_COLUMNS.length) {
      errors.push(
        `${at}: butuh ${WORD_COLUMNS.length} kolom ${WORD_COLUMNS.join('|')}, ada ${cells.length}.`,
      );
      return;
    }
    const [answerRaw, keyword, stageRaw, slotRaw, packId] = cells;
    const answer = answerRaw.toLowerCase();
    const stage = /^\d+$/.test(stageRaw) ? Number(stageRaw) : NaN;
    const slot = /^\d+$/.test(slotRaw) ? Number(slotRaw) : NaN;

    const rowErrors = [];
    if (!ANSWER_RE.test(answer)) {
      rowErrors.push(`${at}: jawaban "${answerRaw}" hanya boleh huruf a-z, panjang 3-12.`);
    }
    if (keyword === '') rowErrors.push(`${at}: keyword kosong.`);
    if (!(stage > 0)) rowErrors.push(`${at}: stage "${stageRaw}" harus bilangan bulat > 0.`);
    if (!(slot >= 1 && slot <= 3)) rowErrors.push(`${at}: slot "${slotRaw}" harus 1, 2, atau 3.`);
    if (!PACK_RE.test(packId)) {
      rowErrors.push(`${at}: packId "${packId}" hanya boleh a-z, 0-9, _ atau -.`);
    }
    if (rowErrors.length > 0) {
      errors.push(...rowErrors);
      return;
    }

    const key = wordKey(answer, stage);
    if (byKey.has(key)) {
      errors.push(`${at}: ${answer} di stage ${stage} sudah ada di baris ${byKey.get(key)}.`);
      return;
    }
    const slotKey = `${stage}/${slot}`;
    if (bySlot.has(slotKey)) {
      errors.push(`${at}: stage ${stage} slot ${slot} sudah dipakai di baris ${bySlot.get(slotKey)}.`);
      return;
    }
    byKey.set(key, i + 1);
    bySlot.set(slotKey, i + 1);
    entries.push({ line: i + 1, answer, keyword, stage, slot, packId, key });
  });

  return { entries, errors };
}

/**
 * Baca words.txt. File tidak ada -> null (fitur words dimatikan).
 * Mengembalikan { entries, errors, byKey: Map<key, entry>, path } atau null.
 */
function loadWords(file = WORDS_PATH) {
  if (!fs.existsSync(file)) return null;
  const result = parseWords(fs.readFileSync(file, 'utf8'));
  return {
    ...result,
    byKey: new Map(result.entries.map((e) => [e.key, e])),
    path: file,
  };
}

/** Nama file yang disarankan untuk gambar pilihan, mis. "kucing_31.jpg". */
function suggestedFileName(entry, ext = 'jpg') {
  return `${entry.key}.${ext}`;
}

module.exports = {
  WORDS_PATH,
  WORD_COLUMNS,
  wordKey,
  parseWords,
  loadWords,
  suggestedFileName,
};
