#!/usr/bin/env bash
set -euo pipefail

PDF_FILE_NAME="the-managers-path-a-guide-for-tech-leaders-camille-fournier_compress.pdf"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_FILE_PATH="${REPO_ROOT}/${PDF_FILE_NAME}"
MOBILE_PDF_PATH="${MOBILE_PDF_PATH:-/data/data/com.termux/files/home/storage/downloads/${PDF_FILE_NAME}}"

if [[ ! -f "${REPO_FILE_PATH}" ]]; then
  echo "Repo PDF missing: ${REPO_FILE_PATH}"
  exit 1
fi

if [[ ! -f "${MOBILE_PDF_PATH}" ]]; then
  echo "Phone PDF missing (environment-specific): ${MOBILE_PDF_PATH}"
  echo "No sync action can be completed until the phone path is available."
  exit 0
fi

get_mtime() {
  local file_path="$1"

  if stat -f "%m" "${file_path}" >/dev/null 2>&1; then
    stat -f "%m" "${file_path}"
  else
    stat -c "%Y" "${file_path}"
  fi
}

get_repo_commit_time() {
  local commit_ts
  commit_ts="$(git -C "${REPO_ROOT}" log -1 --format="%ct" -- "${PDF_FILE_NAME}" 2>/dev/null || true)"
  if [[ -z "${commit_ts}" ]]; then
    echo "0"
    return
  fi
  echo "${commit_ts}"
}

repo_commit_ts="$(get_repo_commit_time)"
repo_mtime="$(get_mtime "${REPO_FILE_PATH}")"
if git -C "${REPO_ROOT}" diff --quiet -- "${PDF_FILE_NAME}"; then
  repo_effective_ts="${repo_commit_ts}"
else
  repo_effective_ts="${repo_mtime}"
fi
mobile_mtime="$(get_mtime "${MOBILE_PDF_PATH}")"

if (( mobile_mtime > repo_effective_ts )); then
  echo "Phone copy is newer; syncing it into the repo, then mirroring back."
  cp "${MOBILE_PDF_PATH}" "${REPO_FILE_PATH}"
else
  echo "Repo copy is newer; syncing it into the phone path."
  cp "${REPO_FILE_PATH}" "${MOBILE_PDF_PATH}"
fi

if ! git -C "${REPO_ROOT}" diff --quiet -- "${PDF_FILE_NAME}"; then
  echo "Repo file changed. Committing and pushing."
  git -C "${REPO_ROOT}" add "${PDF_FILE_NAME}"
  git -C "${REPO_ROOT}" commit -m "chore: sync managers path PDF from mobile or repo"
  git -C "${REPO_ROOT}" push
else
  echo "No repo changes to commit."
fi
