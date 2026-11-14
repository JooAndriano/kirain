# tools/: skrip admin Kirain

Skrip di folder ini dijalankan di komputer admin (Node.js ≥ 18) dan **bukan** bagian dari app.
App hanya membaca Firestore. Penulisan data puzzle dilakukan lewat `seed_puzzles.js`.

Konsep data: **1 stage = 3 gambar** (slot 1, 2, 3). Setiap gambar menjadi satu dokumen
di koleksi Firestore `puzzles`, dengan id `stage_<stage 3 digit>_<slot>`, misalnya
`stage_003_2`. App hanya menampilkan stage yang ketiga slotnya lengkap dan aktif. Nomor
stage harus berurutan mulai dari 1. Stage setelah celah nomor tidak tampil.

## Alur singkat

```
siapkan gambar → make_puzzles_csv → edit di Excel/Sheets → check_images
              → seed_puzzles --dry-run → seed_puzzles → naikkan contentVersion di Remote Config
```

```bash
cd tools
node make_puzzles_csv.js images            # 1. buat puzzles.csv dari folder gambar
#                                          # 2. edit puzzles.csv di Excel/Sheets bila perlu
node check_images.js                       # 3. validasi CSV + gambar (tanpa internet)
node seed_puzzles.js --dry-run             # 4. ringkasan dokumen yang akan ditulis
node seed_puzzles.js                       # 5. tulis ke Firestore
#                                          # 6. naikkan contentVersion di Remote Config
```

Unggah juga file gambar ke bucket R2 dengan nama yang sama (struktur datar, tanpa subfolder),
karena URL gambar di app = `imageBaseUrl` (Remote Config) + `imageFile`.

> Catatan: app versi sekarang belum membaca `contentVersion`. Daftar puzzle selalu diambil
> dari Firestore saat app dibuka, lalu disimpan sebagai cache lokal untuk dipakai saat
> offline. Tetap naikkan nilainya setiap kali konten berubah, supaya siap saat app
> mulai memakainya.

## 1. Siapkan gambar

Taruh gambar `.webp` di `tools/images/` (folder ini di-`.gitignore`, sehingga gambar tidak
masuk git). Satu subfolder mewakili satu pack:

```
tools/images/
  hewan/kucing_1.webp
  hewan/gajah_1.webp
  hewan/ayam_1_b.webp
  buah/pisang_2.webp
  buah/mangga_2.webp
  buah/semangka_2.webp
```

Pola nama file: `jawaban_stage[_akhiran].webp`, ditulis dengan huruf kecil, misalnya
`kucing_1.webp` atau `ayam_1_b.webp`.

- `jawaban` = huruf a-z saja, menjadi `answer` (uppercase).
- `stage` = angka setelah `_` pertama.
- akhiran opsional (`_b`, `_v2`, …) hanya untuk membedakan nama file.
- Nama file harus unik di seluruh subfolder (R2 datar). Ukuran maksimal 300 KB per gambar.

## 2. `make_puzzles_csv.js`

```bash
node make_puzzles_csv.js <folder gambar> [--start-stage N] [--force] [--out file.csv]
```

- Memindai `.webp` secara rekursif. Nama yang tidak cocok pola dilaporkan dan dilewati.
- `slot` = urutan abjad nama file dalam stage yang sama. `packId` = nama subfolder, atau
  `umum` jika file ada di root folder.
- `focusX`/`focusY` diisi acak -0.6..0.6. `difficulty` dihitung dari panjang jawaban
  (≤4 → 1, 5–6 → 2, ≥7 → 3). `active` = `true`.
- `--start-stage N` menggeser nomor stage sehingga stage terkecil menjadi N, berguna saat
  menambah batch baru setelah stage yang sudah ada.
- Hasilnya ditulis ke `tools/puzzles.csv`. File yang sudah ada **tidak** ditimpa kecuali
  dengan `--force`.

## 3. Edit `puzzles.csv`

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

## 4. `check_images.js`

```bash
node check_images.js [--csv puzzles.csv] [--images folder]
```

Validasi lokal tanpa internet. Default memakai `tools/puzzles.csv` dan `tools/images/`.
Semua aturan di tabel atas diperiksa, ditambah: file gambar ada, ≤ 300 KB, dan nama file
tidak dipakai dua kali. File gambar yang tidak dipakai di CSV dilaporkan sebagai
**peringatan**. Skrip keluar dengan kode 1 jika ada error.

## 5. `seed_puzzles.js`

Butuh service account key (lihat bagian 6) dan `npm install` (sekali saja).

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

## 6. Service account key

1. Buka [Firebase Console](https://console.firebase.google.com/) dan pilih project Kirain.
2. Klik ikon gerigi → **Project settings** → tab **Service accounts**.
3. Klik **Generate new private key** → **Generate key**. File JSON akan terunduh.
4. Ganti namanya menjadi `serviceAccountKey.json` dan simpan di `tools/serviceAccountKey.json`.

> ⚠️ File ini memberi akses admin penuh ke project. File ini sudah tercantum di `.gitignore`.
> **Jangan pernah** meng-commit, mengirim lewat chat, atau mengunggahnya ke mana pun. Skrip
> tidak pernah mencetak isinya. Jika bocor, hapus key-nya di halaman Service accounts lalu
> buat yang baru.

```bash
cd tools
npm install
```

## 7. Tes

```bash
cd tools
node --test        # atau: npm test
```

Tes membuat 2 stage contoh (6 gambar dummy) di folder sementara, lalu menjalankan
make → check → seed `--dry-run`, ditambah kasus gagal (slot hilang, celah stage, answer
kembar, packId campur, file > 300 KB, file tidak dipakai, `--force`). Tes tidak butuh
internet maupun `npm install`.
