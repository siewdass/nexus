## Dependencias

```sh
brew install protobuf
```

Asegúrate de tener Flutter instalado. El código proto compartido está en `grpc/nexus.proto` y se compila con `./generate.sh`.

## Hub

Servidor Dart/Flutter de escritorio con LLM local (Qwen3-0.6B) vía llama.cpp con aceleración Metal.

### Funcionalidad

- **LLM local** — Qwen3-0.6B-Q8_0 con llama.cpp, 99 capas GPU por Metal, contexto **16384**
- **gRPC server** — puerto `5001`, `NexusService` con RPCs:
  - `Message` (server-streaming) — recibe texto, emite `think`/`reply`/`done`/`error` en un solo stream
  - `SettingsFetch` — lectura de `SharedPreferences` (campo `tunnel`)
  - `SettingsPatch` — escribe `SharedPreferences` y aplica cambio en vivo
- **Think parsing** — extrae tags `<think>...</think>` del stream de tokens en tiempo real
- **UDP discovery** — puerto `5002`, responde a `NEXUS_DISCOVER` con `{private, public}`
- **Túnel Cloudflare** — `cloudflared tunnel --url http://localhost:5001`, gestionado por `TunnelService`
- **Dashboard** — tarjetas de estado (LLM, gRPC, Tunnel) con indicadores visuales
- **Settings** — DragToMoveArea personalizado (sin AppBar), toggle de tema y tunnel, icono de guardar
- **MultiProvider** — `StateService`, `SettingsService`, `ThemeService` accesibles vía Provider

### Development

```sh
./desktop.sh
```

OR

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
- Reconocimiento de voz vía `speech_to_text` con timer de silencio de 3s y timeout de 1s para resultados tardíos
- **Cliente gRPC** — `GrpcClientService` conecta al hub vía `NexusService`, con `NetworkService` envolviendo la misma API pública que antes (`connect`, `sendChat`, streams de `token`/`think`/`done`/`error`)
- Descubrimiento automático del backend por UDP broadcast (puerto 5002)
- Notificaciones al detectar wake word
- Razonamiento del LLM (think) colapsable con animación
- Historial de interacciones con botones copiar/reproducir
- Tema claro/oscuro con colores personalizados, persistencia vía `ThemeService`

### Pantallas

- **Loading** — Busca el servidor Nexus por UDP (5 intentos, 2s timeout), muestra progreso
- **Home** — Detección de wake word, historial de conversaciones, FAB para iniciar/parar
- **Settings** — Switch de modo oscuro

### Permisos

- `INTERNET` / `ACCESS_NETWORK_STATE` — conexión gRPC y descubrimiento UDP
- `RECORD_AUDIO` — capturar audio del micrófono
- `FOREGROUND_SERVICE` / `FOREGROUND_SERVICE_MICROPHONE` — servicio en segundo plano
- `POST_NOTIFICATIONS` — notificaciones al detectar wake word
- `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` — evitar que el sistema detenga la detección

### Development

```sh
./mobile.sh
```

OR

```sh
cd link
flutter run
```

### Build

```sh
cd link
flutter build apk --target-platform android-arm64
```


