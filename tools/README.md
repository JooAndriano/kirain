# tools/ — skrip admin Kirain

Skrip di sini dijalankan di komputer admin (Node.js ≥ 18), **bukan** bagian dari app.
App hanya membaca Firestore; penulisan level dilakukan lewat `seed_levels.js`.

## 1. Buat service account key

1. Buka [Firebase Console](https://console.firebase.google.com/) → pilih project Kirain.
2. Klik ikon gerigi → **Project settings** → tab **Service accounts**.
3. Klik **Generate new private key** → **Generate key**. File JSON akan terunduh.
4. Ganti namanya menjadi `serviceAccountKey.json` dan simpan di folder `tools/`
   (`tools/serviceAccountKey.json`).

> ⚠️ File ini memberi akses admin penuh ke project. Sudah tercantum di `.gitignore` —
> **jangan pernah** di-commit, dikirim lewat chat, atau diunggah ke mana pun.
> Jika bocor, hapus key-nya di halaman Service accounts dan buat yang baru.

## 2. Instal dependensi

```bash
cd tools
npm install
```

(`--dry-run` dan tes validasi tidak butuh `npm install`.)

## 3. Siapkan `levels.csv`

Kolom (urutan wajib sama):

| Kolom        | Aturan                                                                 |
|--------------|------------------------------------------------------------------------|
| `order`      | bilangan bulat > 0, unik. Nomor level di app & kunci progress pemain. Jangan dipakai ulang untuk soal lain. |
| `packId`     | tidak boleh kosong (mis. `hewan`)                                      |
| `imageFile`  | nama file di R2: berakhiran `.webp`, huruf kecil, tanpa spasi (`a-z 0-9 _ -`) |
| `answer`     | hanya huruf `A-Z` kapital, panjang 3–12                                |
| `focusX`     | -1..1 (−1 = kiri, 0 = tengah, 1 = kanan)                               |
| `focusY`     | -1..1 (−1 = atas, 0 = tengah, 1 = bawah)                               |
| `difficulty` | bilangan bulat ≥ 1                                                     |
| `active`     | `true` / `false` (level nonaktif tidak tampil di app)                  |

Contoh (`tools/levels.csv`):

```csv
order,packId,imageFile,answer,focusX,focusY,difficulty,active
1,hewan,kucing.webp,KUCING,0,0,1,true
2,buah,pisang.webp,PISANG,-0.2,-0.1,1,true
3,benda,sepeda.webp,SEPEDA,0.2,0,2,true
```

Baris kosong dan baris berawalan `#` diabaikan. Tanda kutip/koma di dalam nilai tidak didukung.

URL gambar di app = `imageBaseUrl` (Remote Config) + `imageFile`, jadi pastikan file
dengan nama yang sama sudah diunggah ke bucket R2.

## 4. Jalankan

```bash
cd tools

# Validasi + ringkasan saja, tidak menulis apa pun
node seed_levels.js --dry-run

# Tulis ke Firestore (koleksi `levels`)
node seed_levels.js

# Pakai file CSV lain
node seed_levels.js --dry-run --csv ../data/pack2.csv
```

- Jika ada satu saja baris yang tidak valid, skrip mencetak semua masalah (dengan nomor
  baris) dan keluar dengan kode 1 **tanpa menulis apa pun**.
- Dokumen ditulis ke `levels/level_001`, `levels/level_002`, … (order 3 digit) memakai
  `set()`, sehingga skrip aman dijalankan ulang: dokumen yang sama ditimpa, tidak ada
  duplikat. Isi dokumen: `id` (= order), `order`, `packId`, `imageFile`, `answer`,
  `focusX`, `focusY`, `difficulty`, `active`.
- Menghapus baris dari CSV **tidak** menghapus dokumennya di Firestore. Untuk
  menyembunyikan level, ubah `active` menjadi `false` lalu jalankan ulang.

## 5. Tes validasi

```bash
cd tools
node --test        # atau: npm test
```
