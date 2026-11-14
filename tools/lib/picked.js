'use strict';

// Logika convert_picked.js: mencocokkan gambar pilihan di tools/picked/ dengan
// words.txt lalu mengubahnya menjadi .webp <= 300 KB. Fungsi pencocokan tanpa
// dependensi; konversi menerima modul sharp sebagai argumen.

const fs = require('node:fs');
const path = require('node:path');
const { MAX_IMAGE_BYTES } = require('./puzzles');

/** jawaban_stage[_akhiran].(jpg|jpeg|png|webp); nama huruf kecil. */
const PICKED_RE = /^([a-z]+)_(\d+)((?:_[a-z0-9]+)*)\.(jpe?g|png|webp)$/i;

/** { answer, stage, base } atau null. base = nama tanpa ekstensi. */
function parsePickedName(name) {
  const m = PICKED_RE.exec(name);
  if (!m) return null;
  const base = name.slice(0, name.length - m[4].length - 1);
  if (base !== base.toLowerCase()) return null;
  return { answer: m[1], stage: Number(m[2]), base };
}

/**
 * Cocokkan file pilihan (hasil scanFiles) dengan [words] (hasil loadWords).
 * Mengembalikan { jobs, unknown }:
 * - jobs: [{ file, entry, outRel }] dengan outRel = "<packId>/<base>.webp".
 * - unknown: [{ rel, reason }] untuk file yang tidak dikenal.
 */
function planConversions(files, words) {
  const jobs = [];
  const unknown = [];
  const outputs = new Map();
  for (const f of files) {
    const info = parsePickedName(f.name);
    if (!info) {
      unknown.push({
        rel: f.rel,
        reason: 'nama tidak cocok pola jawaban_stage[_akhiran].jpg/.png/.webp (huruf kecil)',
      });
      continue;
    }
    const entry = words.byKey.get(`${info.answer}_${info.stage}`);
    if (!entry) {
      unknown.push({
        rel: f.rel,
        reason: `pasangan (${info.answer}, stage ${info.stage}) tidak ada di words.txt`,
      });
      continue;
    }
    const outRel = `${entry.packId}/${info.base}.webp`;
    if (outputs.has(outRel)) {
      unknown.push({
        rel: f.rel,
        reason: `menghasilkan ${outRel} yang sama dengan ${outputs.get(outRel)}`,
      });
      continue;
    }
    outputs.set(outRel, f.rel);
    jobs.push({ file: f, entry, outRel });
  }
  return { jobs, unknown };
}

const QUALITY_STEPS = [82, 74, 66, 58, 50, 42];
const SIZE_STEPS = [1024, 800, 640];

/**
 * Ubah [input] menjadi webp di [output]: sisi terpanjang maks. 1024 px
 * (tidak diperbesar), kualitas diturunkan bertahap sampai <= maxBytes;
 * jika masih terlalu besar, ukuran diperkecil. Mengembalikan
 * { bytes, quality, maxSide }. Melempar jika tetap > maxBytes.
 */
async function convertToWebp(sharp, input, output, { maxBytes = MAX_IMAGE_BYTES } = {}) {
  let last;
  for (const maxSide of SIZE_STEPS) {
    for (const quality of QUALITY_STEPS) {
      const buf = await sharp(input)
        .rotate() // ikuti orientasi EXIF dari kamera/HP
        .resize({ width: maxSide, height: maxSide, fit: 'inside', withoutEnlargement: true })
        .webp({ quality })
        .toBuffer();
      last = buf.length;
      if (buf.length <= maxBytes) {
        fs.mkdirSync(path.dirname(output), { recursive: true });
        fs.writeFileSync(output, buf);
        return { bytes: buf.length, quality, maxSide };
      }
    }
  }
  throw new Error(`tetap ${Math.ceil(last / 1024)} KB setelah dikompres (maks. ${maxBytes / 1024} KB)`);
}

/** true jika [output] sudah ada dan tidak lebih tua dari [input]. */
function isUpToDate(input, output) {
  if (!fs.existsSync(output)) return false;
  return fs.statSync(output).mtimeMs >= fs.statSync(input).mtimeMs;
}

module.exports = {
  PICKED_RE,
  parsePickedName,
  planConversions,
  convertToWebp,
  isUpToDate,
};
