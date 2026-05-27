#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/backend"

mkdir -p assets
MODEL="assets/Qwen3-0.6B-Q8_0.gguf"
MODEL_URL="https://huggingface.co/Qwen/Qwen3-0.6B-GGUF/resolve/main/Qwen3-0.6B-Q8_0.gguf"

if [ ! -f "$MODEL" ]; then
  echo "Descargando $MODEL..."
  curl -L -o "$MODEL" "$MODEL_URL"
fi

dart run lib/main.dart "$@"
