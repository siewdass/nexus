## Backend

Servidor Dart que corre un LLM local (Qwen3-0.6B) vía llama.cpp con aceleración Metal.

### Funcionalidad

- **LLM local** — Qwen3-0.6B-Q8_0 con llama.cpp, 99 capas GPU por Metal, contexto **16384**
- **Socket.IO server** — puerto `5001`, evento `chat` → recibe texto, responde con streaming de `think` + `token` + `done`
- **Think parsing** — extrae tags `<think>...</think>` del stream de tokens en tiempo real, emite evento separado `think`
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

App Flutter Android offline voice first.

### Features

- Wake word detection offline con TFLite (3 modelos: melspectrograma → embedding → clasificador), threshold 0.51
- Text to speech con Google TTS engine, voz `es-us-x-esd-network`
- Reconocimiento de voz continuo vía `speech_to_text`, auto-restart tras 5s de silencio, loop de conversación automático
- Cliente Socket.IO con streams de `token`/`think`/`done`/`errors`
- Descubrimiento automático del backend por UDP broadcast (puerto 5002)
- Notificaciones al detectar wake word
- Razonamiento del LLM (think) colapsable con animación
- Historial de interacciones con botones copiar/reproducir

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
