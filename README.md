## Dependencias

Asegúrate de tener Flutter instalado.

### Librerías estáticas

Las siguientes librerías se linkean estáticamente desde `hub/static/`:

| Librería | Versión | Build |
|----------|---------|-------|
| **llama.cpp** | b4xx (commit reciente) | `cmake -B build -DGGML_METAL=ON -DLLAMA_METAL=ON -DBUILD_SHARED_LIBS=OFF && cmake --build build` |

## Hub

Servidor Dart/Flutter de escritorio con LLM local (Gemma 4 E2B Q4 / Qwen3 0.6B) vía llama.cpp con aceleración Metal.

### Funcionalidad

- **LLM local** — llama_cpp_dart con Metal, contexto configurable por modelo
- **WebRTC server** — `peer_rtc` + PeerJS cloud signaling (`0.peerjs.com:443`), recibe mensajes JSON via DataChannel
- **Think parsing** — extrae tags `<think>...</think>` del stream de tokens en tiempo real
- **Firestore discovery** — registra `peer_id` en `connections/{uuid}` para que Link lo descubra
- **QR linking** — muestra código QR con UUID para vincular con Link
- **Dashboard** — tarjetas de estado (LLM, WebRTC) con indicadores visuales
- **MultiProvider** — `StateService`, `ThemeService`, `PeerRTCService` accesibles vía Provider

### Development

```sh
cd hub
flutter run -d macos
```

### Build

```sh
cd hub
flutter build macos
```

## Link

App Flutter Mobile offline voice-first.

### Features

- Wake word detection offline con TFLite (3 modelos: melspectrograma → embedding → clasificador), threshold 0.51
- Text to speech con Google TTS engine, voz `es-us-x-esd-network`
- Reconocimiento de voz vía `speech_to_text` con timer de silencio de 3s
- **Cliente WebRTC** — `PeerRTCClient` conecta al hub vía `peer_rtc` + PeerJS cloud, streams de `token`/`think`/`done`/`error`
- Descubrimiento del hub por QR → Firestore (lectura de `peer_id`)
- Notificaciones al detectar wake word
- Razonamiento del LLM (think) colapsable con animación
- Historial de interacciones con botones copiar/reproducir
- Tema claro/oscuro con colores personalizados, persistencia vía `ThemeService`

### Pantallas

- **Loading** — QR scanner para vincular con Hub, lee `peer_id` de Firestore
- **Home** — Detección de wake word, historial de conversaciones, FAB para iniciar/parar
- **Settings** — Switch de modo oscuro

### Permisos

- `INTERNET` / `ACCESS_NETWORK_STATE` — conexión WebRTC y Firestore
- `RECORD_AUDIO` — capturar audio del micrófono
- `FOREGROUND_SERVICE` / `FOREGROUND_SERVICE_MICROPHONE` — servicio en segundo plano
- `POST_NOTIFICATIONS` — notificaciones al detectar wake word
- `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` — evitar que el sistema detenga la detección
- `CAMERA` — escanear código QR

### Development

```sh
cd link
flutter run
```

### Build

```sh
cd link
flutter build apk --target-platform android-arm64
```
