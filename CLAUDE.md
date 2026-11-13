# Kirain (Flutter, Android only)
- Game tebak gambar dengan zoom-out manual. State: Riverpod.
- Logika game di domain/ (Dart murni, tanpa import Flutter). Widget tidak berisi logika.
- Tema dan warna hanya di lib/ui/theme.dart.
- Selalu jalankan `flutter analyze` dan `flutter test` sebelum menyatakan selesai.
- Tanpa login. Progress nanti disimpan lokal lewat satu repository.
- Jangan tambah paket di luar yang diminta.
- Semua akses data progress lewat ProgressRepository (abstract). Implementasi lokal: LocalProgressRepository (shared_preferences). UI/notifier tidak boleh memanggil shared_preferences langsung.