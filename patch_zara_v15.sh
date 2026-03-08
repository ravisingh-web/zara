#!/bin/bash
# ═══════════════════════════════════════════════════════════════════
# Z.A.R.A. v15.0 — AUTO PATCHER
# Run karo: bash patch_zara_v15.sh  (project root se)
# ═══════════════════════════════════════════════════════════════════

set -e
RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'

echo -e "${CYAN}╔══ Z.A.R.A. v15.0 Patcher ══════════════════════╗${NC}"

# Verify we're in project root
if [ ! -f "pubspec.yaml" ]; then
  echo -e "${RED}❌ pubspec.yaml nahi mila — project root mein run karo!${NC}"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

patch_file() {
  local src="$1"
  local dst="$2"
  local name="$(basename $dst)"
  if [ ! -f "$src" ]; then
    echo -e "${RED}  ❌ Source missing: $src${NC}"; return
  fi
  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
  echo -e "${GREEN}  ✅ $name${NC}"
}

echo -e "${CYAN}── Patching files...${NC}"
patch_file "$SCRIPT_DIR/settings_screen.dart"         "lib/screens/settings_screen.dart"
patch_file "$SCRIPT_DIR/api_keys.dart"                "lib/core/constants/api_keys.dart"
patch_file "$SCRIPT_DIR/tts_service.dart"             "lib/services/tts_service.dart"
patch_file "$SCRIPT_DIR/zara_provider.dart"           "lib/features/zara_engine/providers/zara_provider.dart"
patch_file "$SCRIPT_DIR/ai_api_service.dart"          "lib/services/ai_api_service.dart"
patch_file "$SCRIPT_DIR/ZaraAccessibilityService.kt"  "android/app/src/main/kotlin/com/mahakal/zara/ZaraAccessibilityService.kt"

echo ""
echo -e "${CYAN}── Running flutter pub get...${NC}"
flutter pub get

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅ Patch complete! Build karo:                  ║${NC}"
echo -e "${GREEN}║     flutter build apk --debug                    ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
