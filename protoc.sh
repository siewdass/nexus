#!/bin/bash
set -e

export PATH="$PATH":"$HOME/.pub-cache/bin"

if ! command -v protoc-gen-dart &>/dev/null; then
  echo "Error: protoc-gen-dart no encontrado."
  echo "Instalalo con: dart pub global activate protoc_plugin"
  exit 1
fi

OUTDIR="$(dirname "$0")/proto/lib"
PROTODIR="$(dirname "$0")/proto"
mkdir -p "$OUTDIR"
protoc --dart_out="grpc:$OUTDIR" -I"$PROTODIR" "$PROTODIR"/jarvis.proto
echo "Stubs regenerados en $OUTDIR/"
