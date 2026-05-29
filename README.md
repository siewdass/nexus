## Backend

Nexus Desktop — Servidor Socket.IO que corre un LLM (Qwen3-0.6B) via llama.cpp con Metal (GPU).

### Features

- **LLM local** — Qwen3-0.6B-Q8_0 via llama.cpp con aceleración Metal
- **Socket.IO** — comunicación bidireccional en tiempo real
- **Túnel Cloudflare** — acceso remoto sin exponer puertos
- **Hot reload** — recarga de código en desarrollo sin reiniciar el LLM

### Development

```sh
./backend.sh
```

O manual:

```sh
cd backend
dart pub get
dart --enable-vm-service lib/main.dart
```

### Build

```sh
cd backend
dart compile exe lib/main.dart -o nexus.bin
```

## Frontend

Nexus Companion — App Flutter para Android que detecta "nexus" offline con TFLite.

### Features

- **Wake word detection offline** — "nexus" via TFLite, sin internet, con pantalla apagada
- **Notificación + vibración + sonido** al detectar el wake word
- **Foreground service** — sigue escuchando con la app en segundo plano
- **TTS** — voces del sistema con Google TTS engine
- **Socket.IO** — se conecta al backend para chat con el LLM

### Permisos

- `RECORD_AUDIO` — capturar audio del micrófono
- `FOREGROUND_SERVICE` / `FOREGROUND_SERVICE_MICROPHONE` — servicio en segundo plano
- `POST_NOTIFICATIONS` — notificaciones al detectar wake word
- `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` — evitar que el sistema detenga la detección

### Development

```sh
./frontend.sh
```

O manual:

```sh
cd frontend
flutter pub get
flutter run
```

### Build

```sh
cd frontend
flutter build apk --target-platform android-arm64
```

