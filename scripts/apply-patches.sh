#!/bin/bash
set -e

cd "$(dirname "$0")/.."

PATCHES_DIR="patches"

if [ ! -d "$PATCHES_DIR" ]; then
  echo "⚠️  No patches directory found"
  exit 0
fi

echo "📦 Applying patches..."

cd openclaw

for patch in ../$PATCHES_DIR/*.patch; do
  if [ -f "$patch" ]; then
    echo "  → $(basename "$patch")"
    git apply --ignore-whitespace --whitespace=fix "$patch" || {
      echo "❌ Failed to apply $(basename "$patch")"
      exit 1
    }
  fi
done

echo "✅ All patches applied"
