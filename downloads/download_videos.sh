#!/bin/bash

BASE_URL="https://www.pexels.com/video"
OUTPUT_DIR="./sample-videos"

mkdir -p "$OUTPUT_DIR"

# Default slugs if none provided
DEFAULT_SLUGS=(
  "grocery-checkout-with-fresh-produce-29824278"
  "person-holding-a-vegetable-and-fruits-5802028"
  "a-woman-arranging-vegetables-in-a-basket-7246481"
)

# Use input slugs or fallback to default
VIDEO_SLUGS=("$@")
if [ ${#VIDEO_SLUGS[@]} -eq 0 ]; then
  VIDEO_SLUGS=("${DEFAULT_SLUGS[@]}")
fi

for video_slug in "${VIDEO_SLUGS[@]}"; do
  echo "🔍 Processing: $video_slug"
  VIDEO_PAGE_URL="${BASE_URL}/${video_slug}/"

  VIDEO_URL=$(curl -s "$VIDEO_PAGE_URL" | grep -oP 'https://videos\.pexels\.com/videos/[^"]+\.mp4' | head -n 1)

  if [ -n "$VIDEO_URL" ]; then
    filename="${video_slug##*/}.mp4"
    echo "⬇️  Downloading $filename ..."
    curl -L "$VIDEO_URL" -o "$OUTPUT_DIR/$filename"
  else
    echo "Could not fetch video for: $video_slug"
  fi
done
