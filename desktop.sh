#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/hub"

mkdir -p assets
MODEL="assets/Qwen3-0.6B-Q8_0.gguf"
MODEL_URL="https://huggingface.co/Qwen/Qwen3-0.6B-GGUF/resolve/main/Qwen3-0.6B-Q8_0.gguf"

if [ ! -f "$MODEL" ]; then
  echo "Descargando $MODEL..."
  curl -L -o "$MODEL" "$MODEL_URL"
fi

CLOUDFLARED_BIN="assets/cloudflared"
CLOUDFLARED_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-darwin-amd64.tgz"

if [ ! -f "$CLOUDFLARED_BIN" ]; then
  echo "Descargando cloudflared..."
  curl -L -o /tmp/cloudflared.tgz "$CLOUDFLARED_URL"
  tar -xzf /tmp/cloudflared.tgz -C /tmp
  mv /tmp/cloudflared "$CLOUDFLARED_BIN"
  chmod +x "$CLOUDFLARED_BIN"
  rm -f /tmp/cloudflared.tgz
fi

dart --enable-vm-service lib/main.dart "$@"