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

# Example/demo directories to skip only when ROOT is "."
EXCLUDES_DIRS_ROOT_ONLY="ChatExample ChatSwiftUIDemo Example Example_SPM Example_static InboxExample SPMChatExample"

# Directories to always skip regardless of ROOT
EXCLUDES_DIRS_ALWAYS="Vendor PIP"

# Directories to prune (skip entirely, don't descend into them)
PRUNE_DIRS=".git build Pods DerivedData .sonar .sonarqube .scannerwork .sonarlint .build xcuserdata Carthage .idea macos fastlane tmp keys test_output"

# Specific files to skip - these have own copyright but are mixed with our owns
EXCLUDES_FILES="Alamofire.h Kingfisher.h SwiftTryCatch.h SwiftTryCatch.m .gitignore"
# -------------------------------------------

should_exclude_dir() {
  local file_path="$1"
  local relative_path="${file_path#$ROOT/}"

  # Remove leading ./ if present
  relative_path="${relative_path#./}"

  # Always check directories that should be excluded at any nesting level
  for ex in $EXCLUDES_DIRS_ALWAYS; do
    if [[ "$relative_path" == *"/$ex/"* || "$relative_path" == "$ex/"* ]]; then
      return 0
    fi
  done

  # Only check example/demo directories if ROOT is "." (top-level only)
  if [[ "$ROOT" == "." ]]; then
    for ex in $EXCLUDES_DIRS_ROOT_ONLY; do
      if [[ "$relative_path" == "$ex/"* ]]; then
        return 0
      fi
    done
  fi

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

has_infobip_header() {
  local file="$1"
  local header_lines=""

  # Read first 20 lines to check for header
  header_lines=$(head -n 20 "$file")

  # Check if header contains all required Infobip copyright elements
  if echo "$header_lines" | grep -q "Copyright (c)" && \
     echo "$header_lines" | grep -q "Infobip Limited" && \
     echo "$header_lines" | grep -q "Apache License, Version 2.0"; then
    return 0
  fi

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
  # Build the find prune expression
  prune_expr=""
  for dir in $PRUNE_DIRS; do
    if [ -z "$prune_expr" ]; then
      prune_expr="-name $dir"
    else
      prune_expr="$prune_expr -o -name $dir"
    fi
  done

  find "$ROOT" -type d \( $prune_expr \) -prune -o -type f -name "*.$ext" -print | while read -r file; do
    if should_exclude_dir "$file"; then
      continue
    fi
    if should_exclude_file "$file"; then
      continue
    fi
    if has_infobip_header "$file"; then
      continue
    fi

    tmp="$(mktemp)"
    strip_header "$file" > "$tmp"

    filename="$(basename "$file")"   # show filename only in header
    {
      echo "${HEADER//FILENAME_PLACEHOLDER/$filename}"
      cat "$tmp"
    } > "$file"

    rm -f "$tmp"
    echo "[rewrite] $file"
  done
done

