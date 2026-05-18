#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

PROJECT_NAME="Events Tracker"
SCHEME_NAME="Events Tracker"

CONFIGURATION="${CONFIGURATION:-Debug}"
DESTINATION="${DESTINATION:-platform=macOS}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-${REPO_ROOT}/.build/DerivedData}"
SOURCE_PACKAGES_PATH="${SOURCE_PACKAGES_PATH:-${REPO_ROOT}/.build/SourcePackages}"
OUTPUT_DIR="${OUTPUT_DIR:-${REPO_ROOT}/dist}"
CODE_SIGNING_ALLOWED="${CODE_SIGNING_ALLOWED:-NO}"
CODE_SIGNING_REQUIRED="${CODE_SIGNING_REQUIRED:-NO}"

PROJECT_PATH="${REPO_ROOT}/${PROJECT_NAME}.xcodeproj"
BUILT_APP="${DERIVED_DATA_PATH}/Build/Products/${CONFIGURATION}/${PROJECT_NAME}.app"
OUTPUT_APP="${OUTPUT_DIR}/${PROJECT_NAME}.app"

if [[ ! -d "${PROJECT_PATH}" ]]; then
  echo "error: Xcode project not found at ${PROJECT_PATH}" >&2
  exit 1
fi

mkdir -p "${OUTPUT_DIR}"

xcodebuild \
  -project "${PROJECT_PATH}" \
  -scheme "${SCHEME_NAME}" \
  -configuration "${CONFIGURATION}" \
  -destination "${DESTINATION}" \
  -derivedDataPath "${DERIVED_DATA_PATH}" \
  -clonedSourcePackagesDirPath "${SOURCE_PACKAGES_PATH}" \
  CODE_SIGNING_ALLOWED="${CODE_SIGNING_ALLOWED}" \
  CODE_SIGNING_REQUIRED="${CODE_SIGNING_REQUIRED}" \
  build

if [[ ! -d "${BUILT_APP}" ]]; then
  echo "error: expected app bundle was not created at ${BUILT_APP}" >&2
  exit 1
fi

rm -rf "${OUTPUT_APP}"
ditto "${BUILT_APP}" "${OUTPUT_APP}"

echo "Built app bundle:"
echo "${OUTPUT_APP}"
