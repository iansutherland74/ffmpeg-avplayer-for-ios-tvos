#!/usr/bin/env bash
set -euo pipefail

# Copies FFmpeg 8.1 visionOS XCFrameworks from a local ffmpeg-kit-8.1 checkout
# into this repository's visionOS package vendor directory.

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEFAULT_SOURCE_DIR="${ROOT_DIR}/../ffmpeg-kit-8.1/prebuilt-visionos/FFmpegXCFrameworks"
TARGET_DIR="${ROOT_DIR}/visionOS/FFmpegXCFrameworks"

SOURCE_DIR="${1:-$DEFAULT_SOURCE_DIR}"

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "ERROR: Source directory not found: $SOURCE_DIR"
  echo "Usage: $0 [path-to-FFmpegXCFrameworks]"
  exit 1
fi

mkdir -p "$TARGET_DIR"
rsync -a --delete "$SOURCE_DIR/" "$TARGET_DIR/"

echo "Copied visionOS XCFrameworks into: $TARGET_DIR"
echo "You can now open visionOS/Package.swift as a local Swift package."
