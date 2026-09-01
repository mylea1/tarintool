#!/usr/bin/env bash
set -euo pipefail

FLAVOR="${1:-}"
if [[ "$FLAVOR" != "cn" && "$FLAVOR" != "global" ]]; then
  echo "Usage: build_android_release.sh <cn|global>" >&2
  exit 2
fi

MOBILE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "Missing $name. Release builds never fall back to the debug signing key." >&2
    exit 1
  fi
}

require_env KILO_ANDROID_STORE_PASSWORD
require_env KILO_ANDROID_KEY_ALIAS
require_env KILO_ANDROID_KEY_PASSWORD

if [[ -z "${KILO_ANDROID_KEYSTORE:-}" && -z "${KILO_ANDROID_KEYSTORE_B64:-}" ]]; then
  echo "Set KILO_ANDROID_KEYSTORE to a .jks path or KILO_ANDROID_KEYSTORE_B64 in CI." >&2
  exit 1
fi

if [[ -z "${KILO_ANDROID_KEYSTORE:-}" ]]; then
  SIGNING_DIR="$MOBILE_ROOT/build/kilo-signing"
  mkdir -p "$SIGNING_DIR"
  export KILO_ANDROID_KEYSTORE="$SIGNING_DIR/kilo-release.jks"
  if base64 --help 2>&1 | grep -q -- '--decode'; then
    printf '%s' "$KILO_ANDROID_KEYSTORE_B64" | base64 --decode > "$KILO_ANDROID_KEYSTORE"
  else
    printf '%s' "$KILO_ANDROID_KEYSTORE_B64" | base64 -D > "$KILO_ANDROID_KEYSTORE"
  fi
fi

if [[ ! -f "$KILO_ANDROID_KEYSTORE" ]]; then
  echo "Release signing keystore was not found at $KILO_ANDROID_KEYSTORE." >&2
  exit 1
fi

cd "$MOBILE_ROOT"
flutter pub get
COMMON_DART_DEFINES=(
  "--dart-define=APP_MARKET=$FLAVOR"
  "--dart-define=KILO_SOURCE_COMMIT=${KILO_SOURCE_COMMIT:-unknown}"
)
flutter build apk --release --flavor "$FLAVOR" "${COMMON_DART_DEFINES[@]}"
flutter build appbundle --release --flavor "$FLAVOR" "${COMMON_DART_DEFINES[@]}"

APK_PATH="$MOBILE_ROOT/build/app/outputs/flutter-apk/app-${FLAVOR}-release.apk"
AAB_PATH="$MOBILE_ROOT/build/app/outputs/bundle/${FLAVOR}Release/app-${FLAVOR}-release.aab"
if [[ ! -f "$APK_PATH" || ! -f "$AAB_PATH" ]]; then
  echo "Flutter completed without both signed $FLAVOR APK and AAB artifacts." >&2
  exit 1
fi

hash_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

echo "ANDROID FLAVOR: $FLAVOR"
echo "APK:            $APK_PATH"
echo "APK SHA256:     $(hash_file "$APK_PATH")"
echo "AAB:            $AAB_PATH"
echo "AAB SHA256:     $(hash_file "$AAB_PATH")"
