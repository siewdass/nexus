# Nexus

Wake word detection offline (Android) + LLM backend con Socket.IO.

## Features

- **Wake word detection offline** — "hey nexus" via TFLite, sin internet, con pantalla apagada
- **Notificación + vibración + sonido** al detectar el wake word
- **LLM local** — Qwen3-0.6B via llama.cpp con Metal (GPU)
- **Socket.IO** — comunicación en tiempo real entre app y backend
- **TTS** — voces del sistema con Google TTS engine
- **Túnel Cloudflare** — acceso remoto sin exponer puertos

## Backend

Servidor Socket.IO que corre un LLM (Qwen3-0.6B) via llama.cpp.

### Requisitos

- `backend/assets/libllama.dylib` — compilado de llama.cpp
- `backend/assets/Qwen3-0.6B-Q8_0.gguf` — modelo (se descarga solo si falta)

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
dart compile exe lib/main.dart -o nexus.bin
```

Servidor Socket.IO en `0.0.0.0:5001`. Eventos:

| Evento | Dirección | Descripción |
|---|---|---|
| `chat` | cliente → servidor | `{text: "consulta"}` |
| `token` | servidor → cliente | fragmento de texto generado |5
| `done` | servidor → cliente | generación terminada |
| `error` | servidor → cliente | mensaje de error |

## Frontend

App Flutter que detecta "hey nexus" offline con TFLite, reproduce sonido/vibra/notifica, y se conecta al backend via Socket.IO.

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

