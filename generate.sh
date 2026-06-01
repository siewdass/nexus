#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
PROTO_DIR="$PROJECT_ROOT/grpc"
OUT_DIR="$PROTO_DIR/lib/src"
PLUGIN="$HOME/.pub-cache/bin/protoc-gen-dart"

mkdir -p "$OUT_DIR"

protoc \
  --dart_out=grpc:"$OUT_DIR" \
  --plugin=protoc-gen-dart="$PLUGIN" \
  -I"$PROTO_DIR" \
  "$PROTO_DIR/nexus.proto"

echo "✓ Generated Dart gRPC code in $OUT_DIR"
