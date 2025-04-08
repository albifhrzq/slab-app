# Logo Aplikasi

Tempatkan file logo aplikasi di folder ini dengan ketentuan:

## Nama File
1. `app_logo.png` - Logo utama aplikasi
2. `app_logo_foreground.png` - Logo foreground untuk Android adaptive icon

## Ukuran
- `app_logo.png` - Minimal 1024x1024 pixel (persegi)
- `app_logo_foreground.png` - Minimal 1024x1024 pixel (persegi, dengan padding yang cukup di sekitar logo)

## Kualitas
- Format: PNG dengan transparent background
- Resolusi: High resolution (300 DPI direkomendasikan)

## Setelah Menempatkan Logo
Jalankan perintah berikut untuk menghasilkan semua ukuran icon yang diperlukan:

```bash
flutter pub get
flutter pub run flutter_launcher_icons
```

## Catatan
- Logo akan otomatis diubah ukurannya untuk berbagai device
- Adaptive icon untuk Android akan menggunakan background warna #00203F (biru gelap) 