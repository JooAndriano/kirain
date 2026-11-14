'use strict';

// Logika fetch_candidates.js: cari foto kandidat di Pixabay per kata di
// words.txt, simpan sources.csv dan index.html untuk memilih gambar.
// fetch disuntikkan agar bisa dites tanpa internet. API key tidak pernah
// dicetak atau ditulis ke file.

const fs = require('node:fs');
const path = require('node:path');
const { suggestedFileName } = require('./words');

const PIXABAY_API = 'https://pixabay.com/api/';
const CACHE_MAX_AGE_MS = 24 * 60 * 60 * 1000; // syarat Pixabay: cache 24 jam

const SOURCES_COLUMNS = [
  'answer',
  'keyword',
  'stage',
  'slot',
  'packId',
  'suggestedFile',
  'pixabayId',
  'pageURL',
  'largeImageURL',
  'webformatURL',
  'user',
  'tags',
];

/** URL pencarian Pixabay (foto, safesearch, kata kunci bahasa Inggris). */
function buildSearchUrl({ key, keyword, perPage }) {
  const params = new URLSearchParams({
    key,
    q: keyword,
    image_type: 'photo',
    safesearch: 'true',
    lang: 'en',
    per_page: String(Math.min(200, Math.max(3, perPage))),
  });
  return `${PIXABAY_API}?${params}`;
}

/** Hapus API key dari teks (mis. pesan error) sebelum dicetak. */
function redact(text, key) {
  return key ? String(text).split(key).join('***') : String(text);
}

/**
 * Hasil pencarian untuk satu kata. Memakai cache JSON di [cacheDir] jika
 * umurnya < 24 jam (kecuali [force]). Mengembalikan { hits, fromCache }.
 */
async function fetchHits(entry, { key, perPage, fetchImpl, cacheDir, force = false, now = Date.now }) {
  const cacheFile = path.join(cacheDir, `${entry.key}.json`);
  if (!force && fs.existsSync(cacheFile)) {
    try {
      const cached = JSON.parse(fs.readFileSync(cacheFile, 'utf8'));
      if (
        cached.keyword === entry.keyword &&
        cached.perPage === perPage &&
        now() - cached.fetchedAt < CACHE_MAX_AGE_MS
      ) {
        return { hits: cached.hits, fromCache: true };
      }
    } catch {
      // Cache rusak: ambil ulang.
    }
  }

  let res;
  try {
    res = await fetchImpl(buildSearchUrl({ key, keyword: entry.keyword, perPage }));
  } catch (e) {
    throw new Error(`gagal menghubungi Pixabay: ${redact(e.message, key)}`);
  }
  if (!res.ok) {
    const body = await res.text().catch(() => '');
    throw new Error(`Pixabay HTTP ${res.status}: ${redact(body.slice(0, 200), key)}`);
  }
  const data = await res.json();
  const hits = (data.hits ?? []).map((h) => ({
    id: h.id,
    pageURL: h.pageURL,
    previewURL: h.previewURL,
    webformatURL: h.webformatURL,
    largeImageURL: h.largeImageURL,
    user: h.user,
    tags: h.tags,
  }));
  fs.mkdirSync(cacheDir, { recursive: true });
  fs.writeFileSync(
    cacheFile,
    JSON.stringify({ keyword: entry.keyword, perPage, fetchedAt: now(), hits }, null, 2),
  );
  return { hits, fromCache: false };
}

function csvCell(v) {
  const s = v == null ? '' : String(v);
  return /[",\n\r]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
}

/** Baris sources.csv: satu baris per kandidat, membawa stage/slot/packId. */
function sourcesRows(groups) {
  const rows = [];
  for (const { entry, hits } of groups) {
    for (const h of hits) {
      rows.push({
        answer: entry.answer,
        keyword: entry.keyword,
        stage: entry.stage,
        slot: entry.slot,
        packId: entry.packId,
        suggestedFile: suggestedFileName(entry),
        pixabayId: h.id,
        pageURL: h.pageURL,
        largeImageURL: h.largeImageURL,
        webformatURL: h.webformatURL,
        user: h.user,
        tags: h.tags,
      });
    }
  }
  return rows;
}

function toSourcesCsv(rows) {
  const lines = [SOURCES_COLUMNS.join(',')];
  for (const r of rows) lines.push(SOURCES_COLUMNS.map((c) => csvCell(r[c])).join(','));
  return lines.join('\n') + '\n';
}

function esc(s) {
  return String(s ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

/**
 * Halaman pemilihan gambar. Di bawah tiap thumbnail: "Stage N, Gambar slot"
 * dan nama file yang disarankan (jawaban_stage.jpg).
 */
function renderIndexHtml(groups, { generatedAt = new Date() } = {}) {
  const sections = groups
    .map(({ entry, hits, error }) => {
      const label = `Stage ${entry.stage}, Gambar ${entry.slot}`;
      const file = suggestedFileName(entry);
      const cards = hits
        .map(
          (h) => `
      <figure class="card">
        <a href="${esc(h.largeImageURL)}" target="_blank" rel="noopener">
          <img src="${esc(h.webformatURL || h.previewURL)}" alt="${esc(h.tags)}" loading="lazy">
        </a>
        <figcaption>
          <div class="where">${esc(label)}</div>
          <div class="file"><code>${esc(file)}</code>
            <button type="button" data-copy="${esc(file)}">Salin</button></div>
          <div class="meta"><a href="${esc(h.pageURL)}" target="_blank" rel="noopener">Pixabay #${esc(h.id)}</a> · ${esc(h.user)}</div>
        </figcaption>
      </figure>`,
        )
        .join('');
      const body = error
        ? `<p class="empty">Gagal: ${esc(error)}</p>`
        : hits.length === 0
          ? '<p class="empty">Tidak ada hasil. Coba ganti keyword di words.txt.</p>'
          : `<div class="grid">${cards}\n    </div>`;
      return `
  <section id="${esc(entry.key)}">
    <h2>${esc(label)} · ${esc(entry.answer.toUpperCase())}
      <small>keyword "${esc(entry.keyword)}" · pack ${esc(entry.packId)} · simpan sebagai <code>${esc(file)}</code></small></h2>
    ${body}
  </section>`;
    })
    .join('\n');

  return `<!doctype html>
<html lang="id">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Kandidat Gambar Kirain</title>
<style>
  :root { --bg: #fcf1d6; --card: #fff; --text: #3b2a20; --muted: #7a6a5e; --accent: #e8661f; }
  body { margin: 0; padding: 16px; background: var(--bg); color: var(--text);
         font: 14px/1.4 system-ui, sans-serif; }
  h1 { margin: 0 0 4px; }
  .intro { color: var(--muted); margin: 0 0 24px; }
  h2 { font-size: 18px; margin: 28px 0 10px; }
  h2 small { display: block; font-size: 13px; font-weight: normal; color: var(--muted); }
  .grid { display: grid; gap: 12px; grid-template-columns: repeat(auto-fill, minmax(200px, 1fr)); }
  .card { margin: 0; background: var(--card); border-radius: 12px; overflow: hidden;
          box-shadow: 0 2px 8px rgba(59, 42, 32, .12); }
  .card img { display: block; width: 100%; aspect-ratio: 1; object-fit: cover; background: #eee; }
  figcaption { padding: 8px 10px 10px; }
  .where { font-weight: 600; }
  .file { display: flex; gap: 6px; align-items: center; margin: 4px 0; }
  .file code { color: var(--accent); font-weight: 600; word-break: break-all; }
  .file button { margin-left: auto; font-size: 12px; cursor: pointer; }
  .meta, .empty { color: var(--muted); font-size: 12px; }
  .meta a { color: inherit; }
</style>
</head>
<body>
<h1>Kandidat Gambar Kirain</h1>
<p class="intro">Dibuat ${esc(generatedAt.toISOString())} · ${groups.length} kata.
Klik gambar untuk membuka versi besar, unduh, lalu simpan ke <code>tools/picked/</code>
dengan nama file yang tertulis di bawahnya. Setelah itu jalankan <code>node convert_picked.js</code>.</p>
${sections}
<script>
  document.addEventListener('click', (e) => {
    const b = e.target.closest('button[data-copy]');
    if (!b) return;
    navigator.clipboard?.writeText(b.dataset.copy).then(() => {
      b.textContent = 'Tersalin';
      setTimeout(() => { b.textContent = 'Salin'; }, 1200);
    });
  });
</script>
</body>
</html>
`;
}

/** "3" -> [3,3], "1-5" -> [1,5]; null jika format salah. */
function parseStageRange(text) {
  const m = /^(\d+)(?:-(\d+))?$/.exec(String(text).trim());
  if (!m) return null;
  const from = Number(m[1]);
  const to = m[2] ? Number(m[2]) : from;
  return from >= 1 && to >= from ? [from, to] : null;
}

module.exports = {
  PIXABAY_API,
  SOURCES_COLUMNS,
  buildSearchUrl,
  redact,
  fetchHits,
  sourcesRows,
  toSourcesCsv,
  renderIndexHtml,
  parseStageRange,
};
