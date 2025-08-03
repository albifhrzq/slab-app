@echo off
REM Script untuk menjalankan aplikasi dengan berbagai konfigurasi

echo SLAB Aquarium LED Controller - Build Scripts
echo ============================================

:menu
echo.
echo Pilih mode yang ingin dijalankan:
echo 1. Development Mode (Mock Mode ON)
echo 2. Production Mode (Mock Mode OFF)
echo 3. Custom Configuration
echo 4. Build APK Release
echo 5. Exit
echo.
set /p choice="Masukkan pilihan (1-5): "

if "%choice%"=="1" goto dev_mode
if "%choice%"=="2" goto prod_mode
if "%choice%"=="3" goto custom_mode
if "%choice%"=="4" goto build_apk
if "%choice%"=="5" goto exit
goto menu

:dev_mode
echo.
echo Running in Development Mode (Mock Mode ON)...
flutter run --dart-define=MOCK_MODE=true --dart-define=DEBUG_LOGS=true --dart-define=MOCK_DELAY_MS=150
goto menu

:prod_mode
echo.
echo Running in Production Mode (Mock Mode OFF)...
flutter run --dart-define=MOCK_MODE=false --dart-define=DEBUG_LOGS=false --dart-define=BASE_URL=http://192.168.4.1
goto menu

:custom_mode
echo.
echo Custom Configuration Mode
set /p mock_mode="Enable Mock Mode? (true/false) [true]: "
if "%mock_mode%"=="" set mock_mode=true

set /p base_url="Base URL [http://192.168.4.1]: "
if "%base_url%"=="" set base_url=http://192.168.4.1

set /p timeout="Timeout seconds [5]: "
if "%timeout%"=="" set timeout=5

set /p delay="Mock delay ms [200]: "
if "%delay%"=="" set delay=200

echo.
echo Running with custom configuration:
echo - Mock Mode: %mock_mode%
echo - Base URL: %base_url%
echo - Timeout: %timeout%s
echo - Mock Delay: %delay%ms
echo.

flutter run --dart-define=MOCK_MODE=%mock_mode% --dart-define=BASE_URL=%base_url% --dart-define=TIMEOUT_SECONDS=%timeout% --dart-define=MOCK_DELAY_MS=%delay% --dart-define=DEBUG_LOGS=true
goto menu

:build_apk
echo.
echo Building APK Release (Production Mode)...
flutter build apk --release --dart-define=MOCK_MODE=false --dart-define=DEBUG_LOGS=false --dart-define=BASE_URL=http://192.168.4.1
echo.
echo APK berhasil dibuild di: build\app\outputs\flutter-apk\app-release.apk
pause
goto menu

:exit
echo.
echo Terima kasih!
exit
