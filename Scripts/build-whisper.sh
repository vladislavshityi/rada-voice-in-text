#!/bin/zsh
# Builds whisper.cpp (pinned commit) as one static library with Metal
# and places headers + library in Vendor/whisper for SwiftPM to link.
set -euo pipefail

WHISPER_REPO="https://github.com/ggml-org/whisper.cpp"
WHISPER_COMMIT="231638a0717b7822784297e5980965ffcec05810"
VAD_MODEL_URL="https://huggingface.co/ggml-org/whisper-vad/resolve/main/ggml-silero-v5.1.2.bin"
VAD_MODEL_SHA256="29940d98d42b91fbd05ce489f3ecf7c72f0a42f027e4875919a28fb4c04ea2cf"

ROOT="${0:A:h:h}"
SRC="$ROOT/Vendor/whisper.cpp"
OUT="$ROOT/Vendor/whisper"

command -v cmake >/dev/null || { echo "cmake is required: brew install cmake"; exit 1; }

if [[ ! -d "$SRC/.git" ]]; then
  git init -q "$SRC"
  git -C "$SRC" remote add origin "$WHISPER_REPO"
fi
git -C "$SRC" fetch -q --depth 1 origin "$WHISPER_COMMIT"
git -C "$SRC" checkout -q --force "$WHISPER_COMMIT"

cmake -Wno-dev -Wno-deprecated -S "$SRC" -B "$SRC/build" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0 \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DBUILD_SHARED_LIBS=OFF \
  -DGGML_METAL=ON \
  -DGGML_METAL_EMBED_LIBRARY=ON \
  -DGGML_NATIVE=OFF \
  -DWHISPER_BUILD_EXAMPLES=OFF \
  -DWHISPER_BUILD_TESTS=OFF \
  -DWHISPER_BUILD_SERVER=OFF >/dev/null 2>&1
cmake --build "$SRC/build" --config Release -j "$(sysctl -n hw.ncpu)" --target whisper >/dev/null

rm -rf "$OUT" && mkdir -p "$OUT/include" "$OUT/lib"
cp "$SRC/include/whisper.h" "$SRC"/ggml/include/{ggml.h,ggml-cpu.h,ggml-backend.h,ggml-alloc.h} "$OUT/include/"
libtool -static -o "$OUT/lib/libwhisper-bundle.a" \
  "$SRC/build/src/libwhisper.a" \
  "$SRC"/build/ggml/src/libggml{,-base,-cpu}.a \
  "$SRC/build/ggml/src/ggml-blas/libggml-blas.a" \
  "$SRC/build/ggml/src/ggml-metal/libggml-metal.a" 2>/dev/null

# Silero VAD model (≈0.9 MB) is bundled into the app: it removes silence
# before decoding and prevents Whisper hallucinations on quiet audio.
curl -fsSL -o "$OUT/ggml-silero-vad.bin" "$VAD_MODEL_URL"
echo "$VAD_MODEL_SHA256  $OUT/ggml-silero-vad.bin" | shasum -a 256 -c --quiet

echo "whisper.cpp ${WHISPER_COMMIT:0:7} → $OUT"
