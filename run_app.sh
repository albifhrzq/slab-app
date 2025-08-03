#!/bin/bash

# Script untuk menjalankan aplikasi dengan berbagai konfigurasi (Linux/macOS)

echo "SLAB Aquarium LED Controller - Build Scripts"
echo "============================================"

show_menu() {
    echo ""
    echo "Pilih mode yang ingin dijalankan:"
    echo "1. Development Mode (Mock Mode ON)"
    echo "2. Production Mode (Mock Mode OFF)"
    echo "3. Custom Configuration"
    echo "4. Build APK Release"
    echo "5. Exit"
    echo ""
}

while true; do
    show_menu
    read -p "Masukkan pilihan (1-5): " choice
    
    case $choice in
        1)
            echo ""
            echo "Running in Development Mode (Mock Mode ON)..."
            flutter run --dart-define=MOCK_MODE=true --dart-define=DEBUG_LOGS=true --dart-define=MOCK_DELAY_MS=150
            ;;
        2)
            echo ""
            echo "Running in Production Mode (Mock Mode OFF)..."
            flutter run --dart-define=MOCK_MODE=false --dart-define=DEBUG_LOGS=false --dart-define=BASE_URL=http://192.168.4.1
            ;;
        3)
            echo ""
            echo "Custom Configuration Mode"
            read -p "Enable Mock Mode? (true/false) [true]: " mock_mode
            mock_mode=${mock_mode:-true}
            
            read -p "Base URL [http://192.168.4.1]: " base_url
            base_url=${base_url:-http://192.168.4.1}
            
            read -p "Timeout seconds [5]: " timeout
            timeout=${timeout:-5}
            
            read -p "Mock delay ms [200]: " delay
            delay=${delay:-200}
            
            echo ""
            echo "Running with custom configuration:"
            echo "- Mock Mode: $mock_mode"
            echo "- Base URL: $base_url"
            echo "- Timeout: ${timeout}s"
            echo "- Mock Delay: ${delay}ms"
            echo ""
            
            flutter run --dart-define=MOCK_MODE=$mock_mode --dart-define=BASE_URL=$base_url --dart-define=TIMEOUT_SECONDS=$timeout --dart-define=MOCK_DELAY_MS=$delay --dart-define=DEBUG_LOGS=true
            ;;
        4)
            echo ""
            echo "Building APK Release (Production Mode)..."
            flutter build apk --release --dart-define=MOCK_MODE=false --dart-define=DEBUG_LOGS=false --dart-define=BASE_URL=http://192.168.4.1
            echo ""
            echo "APK berhasil dibuild di: build/app/outputs/flutter-apk/app-release.apk"
            ;;
        5)
            echo ""
            echo "Terima kasih!"
            exit 0
            ;;
        *)
            echo "Pilihan tidak valid. Silakan pilih 1-5."
            ;;
    esac
done
