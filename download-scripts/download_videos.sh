#!/bin/bash

# Use SAMPLES_DIR env var if set, otherwise default to /sample-media (for container) or $HOME/sample-media (for host)
OUTPUT_DIR="${SAMPLES_DIR:-/sample-media}"

if [ ! -d "$OUTPUT_DIR" ]; then
  echo "Creating output directory: $OUTPUT_DIR"
  mkdir -p "$OUTPUT_DIR"
else
  echo "Output directory already exists: $OUTPUT_DIR"
fi

echo "Output directory: $OUTPUT_DIR"

VIDEOS=(
  "grocery-checkout-with-fresh-produce-29824278.mp4|https://videos.pexels.com/video-files/29824278/12809924_4096_2160_25fps.mp4"
  "person-holding-a-vegetable-and-fruits-5802028.mp4|https://videos.pexels.com/video-files/5802028/5802028-hd_1920_1080_25fps.mp4"
  "a-woman-arranging-vegetables-in-a-basket-7246481.mp4|https://videos.pexels.com/video-files/7246481/7246481-uhd_2160_3840_25fps.mp4"
)

for entry in "${VIDEOS[@]}"; do
  filename="${entry%%|*}"
  url="${entry##*|}"
  echo "⬇️  Downloading $filename ..."
  wget -O "$OUTPUT_DIR/$filename" "$url"
done

echo "All videos downloaded successfully to $OUTPUT_DIR"
echo "Listing downloaded files:"
ls -lh "$OUTPUT_DIR"
echo "Script completed successfully."
echo "You can now use these videos in your loss prevention application."