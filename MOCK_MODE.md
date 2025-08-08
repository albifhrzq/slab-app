# Mock Mode untuk Testing Tanpa Hardware

## Cara Mengaktifkan Mock Mode dengan Environment Variables

### 1. Menggunakan Script Otomatis (Recommended)

**Windows:**
```bash
run_app.bat
```

**Linux/macOS:**
```bash
chmod +x run_app.sh
./run_app.sh
```

### 2. Menggunakan Flutter Command Line

#### Development Mode (Mock ON):
```bash
flutter run --dart-define=MOCK_MODE=true --dart-define=DEBUG_LOGS=true
```

#### Production Mode (Mock OFF):
```bash
flutter run --dart-define=MOCK_MODE=false --dart-define=DEBUG_LOGS=false
```

#### Custom Configuration:
```bash
flutter run \
  --dart-define=MOCK_MODE=true \
  --dart-define=BASE_URL=http://192.168.1.100 \
  --dart-define=TIMEOUT_SECONDS=10 \
  --dart-define=MOCK_DELAY_MS=300 \
  --dart-define=DEBUG_LOGS=true
```

## Environment Variables yang Tersedia

| Variable | Default | Deskripsi |
|----------|---------|-----------|
| `MOCK_MODE` | `kDebugMode` | Enable/disable mock mode |
| `BASE_URL` | `http://192.168.4.1` | ESP32 controller URL |
| `TIMEOUT_SECONDS` | `5` | HTTP request timeout |
| `MOCK_DELAY_MS` | `200` | Mock response delay |
| `DEBUG_LOGS` | `kDebugMode` | Enable debug logging |
| `MAX_RETRIES` | `5` | Connection retry attempts |
| `RETRY_INTERVAL` | `10` | Retry interval (seconds) |
| `PING_INTERVAL` | `15` | Ping interval (seconds) |

## Fitur Mock Mode

### ✅ Fungsi yang Di-mock:
- **Connection & Ping**: Selalu berhasil dengan latency simulasi
- **Profile Management**: CRUD operasi dengan data tersimpan di memory
- **Time Management**: Menggunakan waktu sistem smartphone
- **Manual LED Control**: Update mock profile values dengan delay realistis
- **Mode Setting**: Toggle antara automatic/manual/off

### 🎯 Data Mock Default:

#### Current Profile:
```dart
{
  'royalBlue': 128,
  'blue': 100,
  'uv': 50,
  'violet': 75,
  'red': 25,
  'green': 40,
  'white': 200,
}
```

#### Time Ranges:
- **Morning**: 06:00 - 10:00
- **Midday**: 10:00 - 16:00  
- **Evening**: 16:00 - 22:00
- **Night**: 22:00 - 06:00

## Debug Panel

Aplikasi menampilkan debug panel di development mode yang menunjukkan:
- Status Mock Mode (ON/OFF)
- Base URL yang digunakan
- Konfigurasi timeout dan delay
- Perintah untuk mengubah mode

## Build untuk Production

### Development APK:
```bash
flutter build apk --dart-define=MOCK_MODE=true
```

### Production APK:
```bash
flutter build apk --release --dart-define=MOCK_MODE=false --dart-define=BASE_URL=http://192.168.4.1
```

## Perbedaan Mock vs Real Hardware

| Aspek | Mock Mode | Real Hardware |
|-------|-----------|---------------|
| Connection | Selalu sukses | Tergantung WiFi & ESP32 |
| Response Time | Configurable (200ms default) | 100-1000ms+ |
| Data Persistence | Memory only | ESP32 NVRAM |
| Time Source | Smartphone | RTC DS3231 |
| LED Output | Log only | Physical PWM pins |

## Testing Scenarios

### ✅ Skenario yang Bisa Ditest:
- UI responsiveness dan layout
- Navigation antar screens
- Form validation dan input handling
- State management dengan Provider
- Profile switching dan time-based logic
- Manual control interactions
- Mode switching (Auto/Manual/Off)

### ❌ Skenario yang Tidak Bisa Ditest:
- Real network connectivity issues
- Hardware pin control dan PWM output
- RTC time synchronization
- WiFi AP mode connection
- ESP32 restart/recovery scenarios

## Troubleshooting

1. **Debug Panel tidak muncul**: Pastikan running di debug mode (`flutter run`)
2. **Environment variables tidak terbaca**: Restart flutter dan pastikan syntax benar
3. **Mock mode tidak berubah**: Environment variables hanya berlaku saat startup aplikasi

Dengan environment variables ini, Anda bisa dengan mudah switch antara mode development dan production tanpa mengubah source code!
