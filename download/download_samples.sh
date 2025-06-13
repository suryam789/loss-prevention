#!/bin/bash

set -e

SAMPLE_DIR="sample-videos"
mkdir -p "$SAMPLE_DIR"

# List of hardcoded Pexels video page URLs
VIDEO_PAGES=(
  "https://www.pexels.com/video/grocery-checkout-with-fresh-produce-29824278/"
  "https://www.pexels.com/video/person-holding-a-vegetable-and-fruits-5802028/"
  "https://www.pexels.com/video/a-woman-arranging-vegetables-in-a-basket-7246481/"
)

# Function to download a video from a Pexels page
download_pexels_video() {
  page_url="$1"
  echo "📄 Processing page: $page_url"

  # Extract direct .mp4 video URL from page HTML
  video_url=$(curl -s "$page_url" | grep -oP 'href="\K(https://images\.pexels\.com/videos/[^"]+\.mp4)' | head -n 1)

  if [ -z "$video_url" ]; then
    echo "Could not extract video link from: $page_url"
    return
  fi

  filename=$(basename "$video_url")
  output_path="$SAMPLE_DIR/$filename"

  if [ -f "$output_path" ]; then
    echo "Already downloaded: $filename"
  else
    echo " Downloading to: $output_path"
    curl -L "$video_url" -o "$output_path"
  fi
}

# Loop through the hardcoded URLs
for url in "${VIDEO_PAGES[@]}"; do
  download_pexels_video "$url"
done

echo "All videos downloaded to: $SAMPLE_DIR/"
