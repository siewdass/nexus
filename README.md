## Backend

Servidor Dart que corre un LLM local (Qwen3-0.6B) vía llama.cpp con aceleración Metal.

### Funcionalidad

- **LLM local** — Qwen3-0.6B-Q8_0 con llama.cpp, 99 capas GPU por Metal, contexto 4096
- **Socket.IO server** — puerto `5001`, evento `chat` → recibe texto, responde con streaming de `token` + `done`
- **UDP discovery** — puerto `5002`, responde a `NEXUS_DISCOVER` con `{private, public}` (IP local + URL cloudflared)
- **Túnel Cloudflare** — `cloudflared tunnel --url http://localhost:5001`, URL pública cambiante
- **Hot reload** — `hotreloader: ^4.4.0`, recarga código sin reiniciar el LLM

### Development

```sh
./backend.sh
```

### Build

```sh
cd backend
dart compile exe lib/main.dart -o nexus.bin
```

## Frontend

App Flutter Android que detecta "nexus" offline y se conecta al backend.

### Servicios

- **WakeService** (`services/wake.dart`) — pipeline TFLite de 3 modelos (melspectrograma → embedding → clasificador). Detección offline, threshold 0.51, sliding window de 10 frames, debounce 3s
- **TtsService** (`services/tts.dart`) — Google TTS engine, voz `es-us-x-esd-network`, rate 0.45, pitch 1.0
- **NetworkService** (`services/network.dart`) — cliente Socket.IO, conexión websocket al backend, evento `chat` → streams `token`/`done`
- **Scanner** (`services/scanner.dart`) — descubrimiento UDP broadcast, envía `NEXUS_DISCOVER` a puerto 5002, recibe `{private, public}`
- **Notifications** (`services/notifications.dart`) — canales `nexus_detected` + `nexus_service`, muestra notificación al detectar

### Pantallas

- **Loading** (`screens/loading.dart`) — pantalla de inicio, corre `Scanner.discover()`, navega a Home si encuentra backend
- **Home** (`screens/home.dart`) — botón Play/Stop, pre-buffering de audio, wake word detection, TTS al detectar, vibración + sonido + notificación

### Permisos

- `RECORD_AUDIO` — capturar audio del micrófono
- `FOREGROUND_SERVICE` / `FOREGROUND_SERVICE_MICROPHONE` — servicio en segundo plano
- `POST_NOTIFICATIONS` — notificaciones al detectar wake word
- `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` — evitar que el sistema detenga la detección

### Development

```sh
./frontend.sh
```

### Build

```sh
cd frontend
flutter build apk --target-platform android-arm64
```
