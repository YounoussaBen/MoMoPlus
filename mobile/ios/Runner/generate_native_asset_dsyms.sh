#!/bin/sh

set -eu

# Flutter native assets are embedded by xcode_backend.sh, but some Flutter
# versions do not copy their dSYM into an iOS archive. App Store Connect
# requires a matching dSYM for every embedded framework, including the
# objective_c runtime pulled in by path_provider_foundation.
case "${CONFIGURATION:-}" in
  Release|Profile) ;;
  *) exit 0 ;;
esac

frameworks_dir="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
dsym_dir="${DWARF_DSYM_FOLDER_PATH:-}"
binary="${frameworks_dir}/objective_c.framework/objective_c"
output="${dsym_dir}/objective_c.framework.dSYM"

[ -n "$dsym_dir" ] || exit 0
[ -f "$binary" ] || exit 0

binary_uuid="$(/usr/bin/xcrun dwarfdump --uuid "$binary" | awk 'NR == 1 { print $2 }')"
[ -n "$binary_uuid" ] || exit 0

if [ -f "${output}/Contents/Resources/DWARF/objective_c" ]; then
  existing_uuid="$(/usr/bin/xcrun dwarfdump --uuid "${output}/Contents/Resources/DWARF/objective_c" | awk 'NR == 1 { print $2 }')"
  if [ "$existing_uuid" = "$binary_uuid" ]; then
    exit 0
  fi
fi

rm -rf "$output"
/usr/bin/xcrun dsymutil "$binary" -o "$output"
