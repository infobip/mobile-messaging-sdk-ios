#!/bin/bash
set -euo pipefail

# ----------------- CONFIG -----------------
PROJECT="${1:-MobileMessaging}"
ROOT="${2:-.}"
YEAR="$(date +%Y)"

HEADER="// 
//  FILENAME_PLACEHOLDER
//  $PROJECT
//
//  Copyright (c) 2016-$YEAR Infobip Limited
//  Licensed under the Apache License, Version 2.0
//
"

# File extensions to process
EXTS=("swift" "h" "m" "mm" "c" "cpp" "hpp")

# Directories to skip - adjust list if running for example projects
EXCLUDES_DIRS="ChatExample ChatSwiftUIDemo Example Example_SPM Example_static InboxExample SPMChatExample Vendor PIP"

# Specific files to skip - these have own copyright but are mixed with our owns
EXCLUDES_FILES="Alamofire.h Kingfisher.h SwiftTryCatch.h SwiftTryCatch.m"
# -------------------------------------------

should_exclude_dir() {
  for ex in $EXCLUDES_DIRS; do
    if [[ $1 == *"/$ex/"* ]]; then
      return 0
    fi
  done
  return 1
}

should_exclude_file() {
  local base
  base="$(basename "$1")"
  for ex in $EXCLUDES_FILES; do
    if [[ $base == $ex ]]; then
      return 0
    fi
  done
  return 1
}

strip_header() {
  awk '
  BEGIN { skipping=1 }
  {
    if (skipping) {
      # drop leading blank lines
      if ($0 ~ /^[[:space:]]*$/) next

      # drop lines starting with //, but NOT if they start with ///
      if ($0 ~ /^[[:space:]]*\/\/($|[[:space:]].*|[^\/].*)/) next

      # first non-header line -> stop skipping
      skipping=0
      print $0
      next
    }
    print $0
  }
  ' "$1"
}

for ext in "${EXTS[@]}"; do
  find "$ROOT" -type f -name "*.$ext" | while read -r file; do
    if should_exclude_dir "$file"; then
      continue
    fi
    if should_exclude_file "$file"; then
      echo "[skip] $file"
      continue
    fi

    tmp="$(mktemp)"
    strip_header "$file" > "$tmp"

    relpath="${file#./}"   # show relative path in header
    {
      echo "${HEADER//FILENAME_PLACEHOLDER/$relpath}"
      cat "$tmp"
    } > "$file"

    rm -f "$tmp"
    echo "[rewrite] $file"
  done
done

echo "Done."

