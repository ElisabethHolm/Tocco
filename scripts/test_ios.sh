#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   scripts/test_ios.sh [scheme] [destination]
# Example:
#   scripts/test_ios.sh Tocco "platform=iOS Simulator,name=iPhone 15"

SCHEME="${1:-Tocco}"
DESTINATION="${2:-platform=iOS Simulator,name=iPhone 15}"
PROJECT_FILE="Tocco.xcodeproj"
WORKSPACE_FILE="Tocco.xcworkspace"

if [[ -f "$WORKSPACE_FILE" ]]; then
  CONTAINER=(-workspace "$WORKSPACE_FILE")
elif [[ -f "$PROJECT_FILE" ]]; then
  CONTAINER=(-project "$PROJECT_FILE")
else
  echo "No Xcode project/workspace found."
  echo "Create/open your iOS app target in Xcode first, then run this script again."
  exit 1
fi

echo "Running iOS tests..."
echo "Scheme: $SCHEME"
echo "Destination: $DESTINATION"

if command -v xcbeautify >/dev/null 2>&1; then
  xcodebuild test \
    "${CONTAINER[@]}" \
    -scheme "$SCHEME" \
    -destination "$DESTINATION" \
    -resultBundlePath ".build/TestResults.xcresult" \
    | xcbeautify
else
  xcodebuild test \
    "${CONTAINER[@]}" \
    -scheme "$SCHEME" \
    -destination "$DESTINATION" \
    -resultBundlePath ".build/TestResults.xcresult"
fi

echo
echo "Done. Result bundle: .build/TestResults.xcresult"
