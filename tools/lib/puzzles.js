'use strict';

// Logika bersama skrip puzzle (make_puzzles_csv, check_images, seed_puzzles).
// Tanpa dependensi, sehingga bisa dites dengan `node --test` tanpa
// firebase-admin dan tanpa internet.

const fs = require('node:fs');
const path = require('node:path');

const COLUMNS = [
  'stage',
  'slot',
  'packId',
  'imageFile',
  'answer',
  'focusX',
  'focusY',
  'difficulty',
  'active',
];

const PUZZLES_PER_STAGE = 3;
const MAX_IMAGE_BYTES = 300 * 1024;
const DEFAULT_PACK = 'umum';

/** jawaban_stage[_akhiran...].webp, mis. kucing_3.webp, kucing_3_b.webp */
const FILENAME_RE = /^([a-z]+)_(\d+)(?:_[a-z0-9]+)*\.webp$/;
const ANSWER_RE = /^[A-Z]{3,12}$/;
const IMAGE_RE = /^[a-z0-9_-]+\.webp$/;

// ---------------------------------------------------------------------------
// Nama file & pembuatan baris
// ---------------------------------------------------------------------------

/** { answer, stage } dari nama file, atau null jika tidak cocok pola. */
function parseFilename(name) {
  const m = FILENAME_RE.exec(name);
  if (!m) return null;
  return { answer: m[1].toUpperCase(), stage: Number(m[2]) };
}

/** Panjang jawaban <=4 -> 1, 5-6 -> 2, >=7 -> 3. */
function difficultyFor(answer) {
  if (answer.length <= 4) return 1;
  if (answer.length <= 6) return 2;
  return 3;
}

/** Angka acak -0.6..0.6 dengan 2 desimal. */
function randomFocus(random = Math.random) {
  const v = Math.round((random() * 1.2 - 0.6) * 100) / 100;
  return Object.is(v, -0) ? 0 : v;
}

/**
 * Semua file di bawah [dir] (rekursif). Mengembalikan
 * [{ rel: 'hewan/kucing_1.webp', name: 'kucing_1.webp', abs, size }].
 * Folder/file berawalan titik dilewati.
 */
function scanFiles(dir) {
  const out = [];
  const walk = (current) => {
    const entries = fs
      .readdirSync(current, { withFileTypes: true })
      .sort((a, b) => a.name.localeCompare(b.name));
    for (const e of entries) {
      if (e.name.startsWith('.')) continue;
      const abs = path.join(current, e.name);
      if (e.isDirectory()) walk(abs);
      else if (e.isFile()) {
        out.push({
          rel: path.relative(dir, abs).split(path.sep).join('/'),
          name: e.name,
          abs,
          size: fs.statSync(abs).size,
        });
      }
    }
  };
  walk(dir);
  return out;
}

/** packId = nama subfolder pertama, atau "umum" jika file ada di root. */
function packIdFor(rel) {
  const parts = rel.split('/');
  return parts.length > 1 ? parts[0] : DEFAULT_PACK;
}

/**
 * Bangun baris CSV dari daftar file .webp (hasil scanFiles).
 * Mengembalikan { rows, skipped, warnings }.
 *
 * - slot = urutan abjad nama file dalam stage yang sama (1..).
 * - startStage: geser nomor stage sehingga stage terkecil menjadi startStage
 *   (jarak antar-stage dipertahankan). null = pakai angka di nama file.
 */
function buildRows(files, { startStage = null, random = Math.random } = {}) {
  const skipped = [];
  const warnings = [];
  const parsed = [];

  for (const f of files) {
    if (!f.name.toLowerCase().endsWith('.webp')) continue;
    const info = parseFilename(f.name);
    if (!info) {
      skipped.push(f.rel);
      continue;
    }
    parsed.push({ ...info, file: f });
  }

  if (parsed.length > 0 && startStage != null) {
    const min = Math.min(...parsed.map((p) => p.stage));
    for (const p of parsed) p.stage = p.stage - min + startStage;
  }

  const byStage = new Map();
  for (const p of parsed) {
    if (!byStage.has(p.stage)) byStage.set(p.stage, []);
    byStage.get(p.stage).push(p);
  }

  const rows = [];
  for (const stage of [...byStage.keys()].sort((a, b) => a - b)) {
    const list = byStage
      .get(stage)
      .sort((a, b) => (a.file.name < b.file.name ? -1 : a.file.name > b.file.name ? 1 : 0));
    if (list.length !== PUZZLES_PER_STAGE) {
      warnings.push(
        `Stage ${stage} berisi ${list.length} gambar (harus ${PUZZLES_PER_STAGE}): ` +
          list.map((p) => p.file.rel).join(', '),
      );
    }
    list.forEach((p, i) => {
      rows.push({
        stage,
        slot: i + 1,
        packId: packIdFor(p.file.rel),
        imageFile: p.file.name,
        answer: p.answer,
        focusX: randomFocus(random),
        focusY: randomFocus(random),
        difficulty: difficultyFor(p.answer),
        active: true,
      });
    });
  }
  return { rows, skipped, warnings };
}

function toCsv(rows) {
  const lines = [COLUMNS.join(',')];
  for (const r of rows) lines.push(COLUMNS.map((c) => String(r[c])).join(','));
  return lines.join('\n') + '\n';
}

// ---------------------------------------------------------------------------
// Parsing CSV
// ---------------------------------------------------------------------------

/** Pisah satu baris; mendukung nilai bertanda kutip ganda sederhana. */
function splitLine(line, delimiter) {
  const cells = [];
  let cur = '';
  let quoted = false;
  for (let i = 0; i < line.length; i++) {
    const ch = line[i];
    if (quoted) {
      if (ch === '"' && line[i + 1] === '"') {
        cur += '"';
        i++;
      } else if (ch === '"') quoted = false;
      else cur += ch;
    } else if (ch === '"') quoted = true;
    else if (ch === delimiter) {
      cells.push(cur.trim());
      cur = '';
    } else cur += ch;
  }
  cells.push(cur.trim());
  return cells;
}

/**
 * CSV dengan pemisah `,` atau `;` (Excel berbahasa Indonesia menyimpan
 * dengan `;` dan desimal koma). Baris kosong dan baris berawalan `#`
 * dilewati. Mengembalikan { rows, errors, delimiter }; setiap row membawa
 * nomor baris aslinya (`line`).
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
    return { rows, errors: ['CSV kosong (tidak ada header).'], delimiter: ',' };
  }

  const headerRaw = lines[headerLine];
  const delimiter =
    headerRaw.split(';').length > headerRaw.split(',').length ? ';' : ',';
  const header = splitLine(headerRaw, delimiter);
  if (header.join(',') !== COLUMNS.join(',')) {
    errors.push(
      `Baris ${headerLine + 1}: header harus "${COLUMNS.join(',')}", ` +
        `ditemukan "${header.join(',')}".`,
    );
    return { rows, errors, delimiter };
  }

  for (let i = headerLine + 1; i < lines.length; i++) {
    const raw = lines[i].trim();
    if (raw === '' || raw.startsWith('#')) continue;
    // Baris kosong versi Excel: ";;;;;;;;"
    if (raw.split('').every((ch) => ch === delimiter)) continue;
    const cells = splitLine(raw, delimiter);
    if (cells.length !== COLUMNS.length) {
      errors.push(`Baris ${i + 1}: butuh ${COLUMNS.length} kolom, ada ${cells.length}.`);
      continue;
    }
    const row = { line: i + 1 };
    COLUMNS.forEach((c, j) => {
      row[c] = cells[j];
    });
    rows.push(row);
  }
  return { rows, errors, delimiter };
}

function parseIntStrict(s) {
  return /^-?\d+$/.test(s) ? Number(s) : NaN;
}

/** Menerima titik atau koma desimal (Excel lokal Indonesia). */
function parseNumberStrict(s) {
  const t = String(s).replace(',', '.');
  return /^-?(\d+(\.\d+)?|\.\d+)$/.test(t) ? Number(t) : NaN;
}

// ---------------------------------------------------------------------------
// Validasi
// ---------------------------------------------------------------------------

/**
 * Indeks gambar lokal berdasarkan nama file (R2 berstruktur datar, jadi
 * nama file harus unik di seluruh subfolder).
 * Mengembalikan { byName: Map<name, file>, duplicates: Map<name, rel[]> }.
 */
function indexImages(files) {
  const byName = new Map();
  const duplicates = new Map();
  for (const f of files) {
    if (byName.has(f.name)) {
      const list = duplicates.get(f.name) ?? [byName.get(f.name).rel];
      list.push(f.rel);
      duplicates.set(f.name, list);
    } else byName.set(f.name, f);
  }
  return { byName, duplicates };
}

/**
 * Validasi baris CSV (hasil parseCsv) terhadap folder gambar lokal.
 * [images] = hasil scanFiles, atau null untuk melewati cek file.
 * Mengembalikan { puzzles, errors, warnings }. `puzzles` hanya terisi jika
 * tidak ada error sama sekali.
 */
function validate(rows, images) {
  const errors = [];
  const warnings = [];
  const puzzles = [];

  // --- Per baris ---
  for (const r of rows) {
    const at = `Baris ${r.line}`;
    const rowErrors = [];

    const stage = parseIntStrict(r.stage);
    if (!Number.isInteger(stage) || stage <= 0) {
      rowErrors.push(`${at}: stage "${r.stage}" harus bilangan bulat > 0.`);
    }
    const slot = parseIntStrict(r.slot);
    if (!Number.isInteger(slot) || slot < 1 || slot > PUZZLES_PER_STAGE) {
      rowErrors.push(`${at}: slot "${r.slot}" harus 1, 2, atau 3.`);
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
        `${at}: answer "${r.answer}" hanya boleh huruf A-Z (kapital), panjang 3-12.`,
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
      rowErrors.push(`${at}: difficulty "${r.difficulty}" harus bilangan bulat >= 1.`);
    }

    const activeRaw = String(r.active).toLowerCase();
    if (!['true', 'false'].includes(activeRaw)) {
      rowErrors.push(`${at}: active "${r.active}" harus true atau false.`);
    }

    if (rowErrors.length > 0) {
      errors.push(...rowErrors);
      continue;
    }
    puzzles.push({
      line: r.line,
      stage,
      slot,
      packId: r.packId,
      imageFile: r.imageFile,
      answer: r.answer,
      focusX,
      focusY,
      difficulty,
      active: activeRaw === 'true',
    });
  }

  // --- Per stage ---
  const byStage = new Map();
  for (const p of puzzles) {
    if (!byStage.has(p.stage)) byStage.set(p.stage, []);
    byStage.get(p.stage).push(p);
  }
  const stageNumbers = [...byStage.keys()].sort((a, b) => a - b);

  for (const stage of stageNumbers) {
    const list = byStage.get(stage);
    const at = `Stage ${stage}`;
    const lines = list.map((p) => p.line).join(', ');

    const slots = list.map((p) => p.slot).sort((a, b) => a - b);
    if (slots.join(',') !== '1,2,3') {
      errors.push(
        `${at}: harus tepat 3 gambar dengan slot 1,2,3 unik; ditemukan ` +
          `slot [${slots.join(',')}] (baris ${lines}).`,
      );
    }

    const answers = new Map();
    for (const p of list) {
      if (answers.has(p.answer)) {
        errors.push(
          `${at}: answer ${p.answer} kembar (baris ${answers.get(p.answer)} dan ${p.line}).`,
        );
      } else answers.set(p.answer, p.line);
    }

    const packs = [...new Set(list.map((p) => p.packId))];
    if (packs.length > 1) {
      errors.push(`${at}: packId harus sama dalam satu stage, ditemukan ${packs.join(', ')}.`);
    }

    const active = list.filter((p) => p.active).length;
    if (active > 0 && active < list.length) {
      warnings.push(
        `${at}: sebagian gambar nonaktif; app hanya menampilkan stage yang ` +
          'ketiga gambarnya aktif.',
      );
    }
  }

  // Nomor stage berurutan mulai 1 tanpa celah.
  for (let i = 0; i < stageNumbers.length; i++) {
    if (stageNumbers[i] !== i + 1) {
      errors.push(
        `Nomor stage harus berurutan mulai 1 tanpa celah: stage ${i + 1} tidak ada ` +
          `(ditemukan ${stageNumbers.join(', ')}).`,
      );
      break;
    }
  }

  // imageFile tidak dipakai dua kali.
  const usedBy = new Map();
  for (const p of puzzles) {
    if (usedBy.has(p.imageFile)) {
      errors.push(
        `Baris ${p.line}: imageFile ${p.imageFile} sudah dipakai di baris ${usedBy.get(p.imageFile)}.`,
      );
    } else usedBy.set(p.imageFile, p.line);
  }

  // --- File gambar lokal ---
  if (images) {
    const { byName, duplicates } = indexImages(images);
    for (const [name, rels] of duplicates) {
      errors.push(
        `Nama file ${name} ada di lebih dari satu folder (${rels.join(', ')}); ` +
          'di R2 nama file harus unik.',
      );
    }
    for (const p of puzzles) {
      const f = byName.get(p.imageFile);
      if (!f) {
        errors.push(`Baris ${p.line}: file ${p.imageFile} tidak ada di folder gambar.`);
      } else if (f.size > MAX_IMAGE_BYTES) {
        errors.push(
          `Baris ${p.line}: ${f.rel} berukuran ${Math.ceil(f.size / 1024)} KB ` +
            `(maks. ${MAX_IMAGE_BYTES / 1024} KB).`,
        );
      }
    }
    for (const f of images) {
      if (!usedBy.has(f.name)) {
        warnings.push(`File ${f.rel} tidak dipakai di CSV.`);
      }
    }
  }

  if (rows.length === 0) errors.push('CSV tidak berisi puzzle.');

  return { puzzles: errors.length === 0 ? puzzles : [], errors, warnings };
}

/**
 * Baca CSV + pindai folder gambar, lalu validasi.
 * Mengembalikan { puzzles, errors, warnings }.
 */
function checkProject({ csvPath, imagesDir }) {
  if (!fs.existsSync(csvPath)) {
    return { puzzles: [], errors: [`CSV tidak ditemukan: ${csvPath}`], warnings: [] };
  }
  if (!fs.existsSync(imagesDir) || !fs.statSync(imagesDir).isDirectory()) {
    return {
      puzzles: [],
      errors: [`Folder gambar tidak ditemukan: ${imagesDir}`],
      warnings: [],
    };
  }
  const parsed = parseCsv(fs.readFileSync(csvPath, 'utf8'));
  if (parsed.errors.length > 0) {
    return { puzzles: [], errors: parsed.errors, warnings: [] };
  }
  return validate(parsed.rows, scanFiles(imagesDir));
}

// ---------------------------------------------------------------------------
// Firestore
// ---------------------------------------------------------------------------

/** "stage_" + stage 3 digit + "_" + slot, mis. (3, 2) -> stage_003_2. */
function docId(stage, slot) {
  return `stage_${String(stage).padStart(3, '0')}_${slot}`;
}

/** Isi dokumen Firestore (tanpa nomor baris). */
function toFirestoreDoc(p) {
  return {
    stage: p.stage,
    slot: p.slot,
    packId: p.packId,
    imageFile: p.imageFile,
    answer: p.answer,
    focusX: p.focusX,
    focusY: p.focusY,
    difficulty: p.difficulty,
    active: p.active,
  };
}

/** Argumen `--nama nilai` / flag sederhana. */
function parseArgs(argv, { flags = [], options = [] }) {
  const args = { _: [] };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a.startsWith('--')) {
      const name = a.slice(2);
      if (flags.includes(name)) args[name] = true;
      else if (options.includes(name)) {
        const v = argv[++i];
        if (v === undefined || v.startsWith('--')) {
          throw new Error(`Argumen --${name} butuh nilai.`);
        }
        args[name] = v;
      } else throw new Error(`Argumen tidak dikenal: ${a}`);
    } else if (a === '-h') args.help = true;
    else args._.push(a);
  }
  return args;
}

function printList(title, items, stream = console.log) {
  if (items.length === 0) return;
  stream(`\n${title} (${items.length}):`);
  for (const item of items) stream(`  - ${item}`);
}

module.exports = {
  COLUMNS,
  PUZZLES_PER_STAGE,
  MAX_IMAGE_BYTES,
  FILENAME_RE,
  parseFilename,
  difficultyFor,
  randomFocus,
  scanFiles,
  packIdFor,
  buildRows,
  toCsv,
  parseCsv,
  validate,
  checkProject,
  docId,
  toFirestoreDoc,
  parseArgs,
  printList,
};
