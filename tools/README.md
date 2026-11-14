# tools/: skrip admin Kirain

Skrip di folder ini dijalankan di komputer admin (Node.js ≥ 18) dan **bukan** bagian dari app.
App hanya membaca Firestore. Penulisan data puzzle dilakukan lewat `seed_puzzles.js`.

Konsep data: **1 stage = 3 gambar** (slot 1, 2, 3). Setiap gambar menjadi satu dokumen
di koleksi Firestore `puzzles`, dengan id `stage_<stage 3 digit>_<slot>`, misalnya
`stage_003_2`. App hanya menampilkan stage yang ketiga slotnya lengkap dan aktif. Nomor
stage harus berurutan mulai dari 1. Stage setelah celah nomor tidak tampil.

## Alur singkat

```
words.txt → fetch_candidates → pilih di index.html → simpan ke picked/ → convert_picked
          → make_puzzles_csv → edit di Excel/Sheets → check_images
          → seed_puzzles --dry-run → seed_puzzles → naikkan contentVersion di Remote Config
```

```bash
cd tools
npm install                                # sekali saja (firebase-admin, sharp)
node fetch_candidates.js --stages 1-5      # 1. cari kandidat foto di Pixabay
#                                          # 2. buka candidates/index.html, simpan pilihan ke picked/
node convert_picked.js                     # 3. picked/*.jpg -> images/<packId>/*.webp
node make_puzzles_csv.js images            # 4. buat puzzles.csv (slot/packId dari words.txt)
#                                          # 5. edit puzzles.csv di Excel/Sheets bila perlu
node check_images.js                       # 6. validasi CSV + gambar (tanpa internet)
node seed_puzzles.js --dry-run             # 7. ringkasan dokumen yang akan ditulis
node seed_puzzles.js                       # 8. tulis ke Firestore
#                                          # 9. naikkan contentVersion di Remote Config
```

Unggah juga file `.webp` ke bucket R2 dengan nama yang sama (struktur datar, tanpa subfolder),
karena URL gambar di app = `imageBaseUrl` (Remote Config) + `imageFile`.

> Catatan: app versi sekarang belum membaca `contentVersion`. Daftar puzzle selalu diambil
> dari Firestore saat app dibuka, lalu disimpan sebagai cache lokal untuk dipakai saat
> offline. Tetap naikkan nilainya setiap kali konten berubah, supaya siap saat app
> mulai memakainya.

Folder `tools/images/`, `tools/picked/`, dan `tools/candidates/` ada di `.gitignore`.

## 1. `words.txt`: daftar kata

Satu baris per gambar, 5 kolom dipisah `|`:

```
# jawaban|keyword|stage|slot|packId
jeruk|orange fruit|1|1|pasar
semangka|watermelon|1|2|pasar
apel|red apple|1|3|pasar
pisang|banana bunch|2|1|pasar
nanas|pineapple|2|2|pasar
anggur|grapes|2|3|pasar
```

| Kolom     | Aturan                                                                  |
|-----------|-------------------------------------------------------------------------|
| `jawaban` | huruf `a-z`, panjang 3–12 (ditulis kecil; di app menjadi kapital)        |
| `keyword` | kata kunci pencarian Pixabay, sebaiknya bahasa Inggris (`orange fruit`)  |
| `stage`   | bilangan bulat > 0                                                       |
| `slot`    | 1, 2, atau 3                                                             |
| `packId`  | `a-z 0-9 _ -`, mis. `pasar`                                              |

Baris kosong dan baris berawalan `#` diabaikan. Pasangan (jawaban, stage) dan
(stage, slot) harus unik. Baris yang bermasalah dilaporkan dengan nomor barisnya lalu
dilewati. Kunci pencocokan gambar dengan kata adalah **jawaban + stage**, sehingga nama
file gambar selalu `jawaban_stage`, misalnya `jeruk_1.jpg` atau `jeruk_1.webp`.

## 2. `fetch_candidates.js`: cari kandidat di Pixabay

Butuh API key gratis dari <https://pixabay.com/api/docs/> (login, lalu salin key di halaman
itu). Key dibaca dari environment `PIXABAY_KEY`, tidak disimpan di file, dan tidak pernah
dicetak:

```powershell
$env:PIXABAY_KEY="kunci-anda"     # PowerShell, berlaku untuk jendela ini saja
node fetch_candidates.js --stages 1-5
```

```bash
node fetch_candidates.js [--stages 1-5] [--per 8] [--force] [--words words.txt] [--out folder]
```

- Kata kunci pencarian = kolom `keyword`. Hasilnya foto saja, dengan safesearch aktif.
- `--stages` membatasi stage yang dicari (`3` atau `1-5`). `--per` mengatur jumlah kandidat
  per kata (3–200, default 8).
- Hasil ditulis di `tools/candidates/`:
  - `index.html`: buka di browser. Di bawah setiap thumbnail tertulis **"Stage N, Gambar
    slot"** dan **nama file yang disarankan** (`jawaban_stage.jpg`), lengkap dengan tombol
    Salin. Klik gambar untuk membuka versi besar.
  - `sources.csv`: satu baris per kandidat, berisi `answer, keyword, stage, slot,
    packId, suggestedFile, pixabayId, pageURL, largeImageURL, webformatURL, user, tags`.
  - `cache/`: hasil API per kata, dipakai ulang selama 24 jam sesuai syarat Pixabay.
    `--force` mengabaikan cache.
- Jeda antarpermintaan 0,7 detik, karena batas Pixabay 100 permintaan per menit.
- Lisensi Pixabay membolehkan pemakaian komersial tanpa atribusi. Pembuat dan halaman
  sumber tetap dicatat di `sources.csv`.

Unduh gambar pilihan dari halaman besarnya, lalu simpan ke `tools/picked/` dengan nama yang
disarankan. Ekstensi `.jpg`, `.jpeg`, `.png`, dan `.webp` diterima. Akhiran opsional seperti
`jeruk_1_b.jpg` boleh dipakai, tetapi hanya file pertama per kata (urutan abjad) yang dipakai
`make_puzzles_csv`.

## 3. `convert_picked.js`: ubah ke webp

```bash
node convert_picked.js [--force] [--picked folder] [--images folder] [--words words.txt]
```

- Setiap file di `tools/picked/` harus cocok dengan pasangan (jawaban, stage) di `words.txt`.
  File yang tidak dikenal (nama tidak sesuai pola, pasangan tidak ada di `words.txt`, atau
  dua file yang menghasilkan output sama) **dilaporkan dan tidak dikonversi**, dan skrip
  keluar dengan kode 1.
- Hasilnya `tools/images/<packId>/<nama>.webp`, dengan packId dari `words.txt`.
- Sisi terpanjang maksimal 1024 px (gambar kecil tidak diperbesar), dan orientasi EXIF
  dari HP diikuti. Kualitas diturunkan bertahap (82 → 42) sampai ≤ 300 KB; jika masih
  terlalu besar, ukurannya diperkecil.
- File hasil yang sudah ada dan lebih baru dari sumbernya dilewati. `--force` mengonversi ulang.

## 4. `make_puzzles_csv.js`

```bash
node make_puzzles_csv.js <folder gambar> [--start-stage N] [--force] [--out file.csv]
                         [--words words.txt | --no-words]
```

- Memindai `.webp` secara rekursif dengan pola nama `jawaban_stage[_akhiran].webp`. Nama
  yang tidak cocok pola dilaporkan dan dilewati.
- **Jika `tools/words.txt` ada** (atau `--words file`), `slot` dan `packId` diambil dari
  sana dengan mencocokkan jawaban + stage dari nama file.
- Jika tidak cocok, atau dengan `--no-words`, dipakai perilaku lama disertai peringatan:
  `slot` = urutan abjad nama file dalam stage yang sama (mengisi slot yang belum dipakai
  words), `packId` = nama subfolder, atau `umum` jika file ada di root.
- `focusX`/`focusY` diisi acak -0.6..0.6. `difficulty` dihitung dari panjang jawaban
  (≤4 → 1, 5–6 → 2, ≥7 → 3). `active` = `true`.
- `--start-stage N` menggeser nomor stage file yang **tidak** cocok words, sehingga stage
  terkecilnya menjadi N. Stage dari `words.txt` tidak pernah digeser.
- Hasilnya ditulis ke `tools/puzzles.csv`. File yang sudah ada **tidak** ditimpa kecuali
  dengan `--force`.

## 5. Edit `puzzles.csv`

| Kolom        | Aturan                                                                 |
|--------------|------------------------------------------------------------------------|
| `stage`      | bilangan bulat > 0. Berurutan mulai dari 1, tanpa celah. Merupakan kunci progress pemain, jadi jangan menukar isi stage yang sudah rilis. |
| `slot`       | 1, 2, atau 3. Setiap stage tepat punya slot 1,2,3 (unik).               |
| `packId`     | tidak boleh kosong, dan sama untuk ketiga gambar dalam satu stage       |
| `imageFile`  | nama file saja: `.webp`, huruf kecil, tanpa spasi (`a-z 0-9 _ -`)       |
| `answer`     | huruf `A-Z` kapital, panjang 3–12, tidak boleh kembar dalam satu stage  |
| `focusX`     | -1..1 (−1 = kiri, 0 = tengah, 1 = kanan)                               |
| `focusY`     | -1..1 (−1 = atas, 0 = tengah, 1 = bawah)                               |
| `difficulty` | bilangan bulat ≥ 1                                                     |
| `active`     | `true` / `false`                                                       |

File boleh disimpan ulang dari Excel berbahasa Indonesia (pemisah `;` dan desimal koma
`0,25`), karena keduanya dikenali. Baris kosong dan baris berawalan `#` diabaikan.

## 6. `check_images.js`

```bash
node check_images.js [--csv puzzles.csv] [--images folder] [--words words.txt]
```

Validasi lokal tanpa internet. Default memakai `tools/puzzles.csv`, `tools/images/`, dan
`tools/words.txt` (jika ada). Semua aturan di tabel atas diperiksa, ditambah: file gambar
ada, ≤ 300 KB, dan nama file tidak dipakai dua kali. Skrip keluar dengan kode 1 jika ada error.

Hal berikut dilaporkan sebagai **peringatan** (tidak menggagalkan):
- file gambar yang tidak dipakai di CSV;
- masalah format `words.txt`;
- **pasangan (jawaban, stage) di `words.txt` yang belum punya gambar** di `tools/images/`,
  dicetak sebagai daftar `jeruk_1.webp (stage 1, gambar 1, pasar; baris 2)`. Daftar ini
  bisa dipakai untuk melihat kata mana yang masih harus dicari gambarnya.

## 7. `seed_puzzles.js`

Butuh service account key (lihat bagian 8) dan `npm install`.

```bash
node seed_puzzles.js --dry-run            # validasi + daftar dokumen, tidak menulis
node seed_puzzles.js                      # validasi lalu tulis (upsert)
node seed_puzzles.js --prune              # tulis + cetak dokumen Firestore yang tidak ada di CSV
node seed_puzzles.js --prune --yes        # tulis + HAPUS dokumen tersebut
#   opsi: --csv file.csv --images folder
```

- `check_images` selalu dijalankan dulu. Jika ada satu saja error, **tidak ada** yang ditulis.
- Dokumen ditulis dengan `set()` ke `puzzles/stage_003_2` dan seterusnya, sehingga aman
  dijalankan ulang. Isi dokumen: `stage`, `slot`, `packId`, `imageFile`, `answer`,
  `focusX`, `focusY`, `difficulty`, `active`.
- Menghapus baris dari CSV tidak menghapus dokumennya kecuali dengan `--prune --yes`.
  Untuk menyembunyikan sementara, ubah `active` menjadi `false`. Satu gambar yang
  nonaktif akan menyembunyikan seluruh stage-nya.

## 8. Service account key

1. Buka [Firebase Console](https://console.firebase.google.com/) dan pilih project Kirain.
2. Klik ikon gerigi → **Project settings** → tab **Service accounts**.
3. Klik **Generate new private key** → **Generate key**. File JSON akan terunduh.
4. Ganti namanya menjadi `serviceAccountKey.json` dan simpan di `tools/serviceAccountKey.json`.

> ⚠️ File ini memberi akses admin penuh ke project. File ini sudah tercantum di `.gitignore`.
> **Jangan pernah** meng-commit, mengirim lewat chat, atau mengunggahnya ke mana pun. Skrip
> tidak pernah mencetak isinya. Jika bocor, hapus key-nya di halaman Service accounts lalu
> buat yang baru.

## 9. Tes

```bash
cd tools
node --test        # atau: npm test
```

Tes tidak butuh internet. Isinya:

- `test/puzzles.test.js`: make → check → seed `--dry-run` pada 2 stage contoh, ditambah
  kasus gagal (slot hilang, celah stage, answer kembar, packId campur, file > 300 KB,
  file tidak dipakai, `--force`).
- `test/words.test.js`: alur `words.txt` dengan data contoh 2 stage (6 kata), yaitu parsing
  `words.txt`, slot/packId dari words versus perilaku lama, kata tanpa gambar di
  `check_images`, dan file tidak dikenal di `convert_picked`. Juga konversi webp
  sungguhan ≤ 300 KB (dilewati jika `sharp` belum terpasang), serta `fetch_candidates`
  dengan fetch palsu (cache 24 jam, key tidak bocor, `sources.csv`, dan `index.html`).
