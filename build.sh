#!/bin/bash
set -e

echo "[+] Initializing live-build config..."
lb config \
  --distribution jammy \
  --architectures amd64 \
  --linux-flavours generic \
  --archive-areas "main restricted universe multiverse" \
  --bootloader grub \
  --syslinux-theme none \
  --gfxboot false \
  --bootappend-live "boot=live quiet splash nomodeset"

echo "[+] Building ISO (this takes 15-25 mins)..."
sudo lb build

echo "[✓] Done! ISO: live-image-amd64.hybrid.iso ($(du -h live-image-amd64.hybrid.iso 2>/dev/null || echo 'not found'))"
