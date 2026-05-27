# Jarvis

## Backend (Dart)

### Dev
```sh
cd backend
dart pub get
dart run lib/main.dart
```

### Prod
```sh
cd backend
dart pub get
dart compile exe lib/main.dart -o bin/jarvis
```

## Frontend (Flutter)

### Dev
```sh
cd frontend
flutter pub get
flutter run
```

### Prod
```sh
cd frontend
flutter pub get
flutter build apk --target-platform android-arm64
```
