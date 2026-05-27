# Jarvis

Wake word detection (Android) + LLM backend con gRPC.

## Estructura

```
jarvis/
├── proto/                 # Definiciones .proto (compartidas)
│   └── jarvis.proto
├── backend/               # Servidor Dart + LLM (llama.cpp)
│   └── pubspec.yaml
├── frontend/              # App Flutter (wake word + TTS)
│   └── pubspec.yaml
└── README.md
```

## Proto / gRPC

### 1. Instalar protoc-gen-dart

```sh
dart pub global activate protoc_plugin
```

Asegurate que `~/.pub-cache/bin` esté en tu `PATH`:

```sh
export PATH="$PATH":"$HOME/.pub-cache/bin"
```

Agregá esa línea a `~/.zshrc` para que persista.

### 2. Generar stubs Dart

Desde `backend/`:

```sh
cd backend
protoc --dart_out="grpc:lib/src/generated" -I../proto ../proto/jarvis.proto
```

Esto genera:
- `lib/src/generated/jarvis.pb.dart` — mensajes
- `lib/src/generated/jarvis.pbgrpc.dart` — servicio gRPC
- `lib/src/generated/jarvis.pbjson.dart` — JSON

### 3. Regenerar

Cuando cambies `proto/jarvis.proto`, repetí el paso 2.

## Backend

### Requisitos

- `libllama.dylib` (compilado de llama.cpp)
- Modelo GGUF (ej. `Qwen3.5-0.8B-Q8.gguf`)

Ambos en la raíz de `jarvis/`.

### Dev

```sh
cd backend
dart pub get
dart run lib/main.dart
```

Servidor gRPC en `0.0.0.0:50051`.

### Compilar

```sh
cd backend
dart compile exe lib/main.dart -o bin/jarvis
```

## Frontend

```sh
cd frontend
flutter pub get
flutter run
```

### Build release

```sh
cd frontend
flutter build apk --target-platform android-arm64
```
