#!/usr/bin/env bash
# Build script to get git repo info
set -euo pipefail

buildid="unknown-version"
gitdir="$(readlink -f "$PWD")/../../../.git"
if command -v git >/dev/null && [[ -e "$gitdir" ]]; then
  buildid="$(git --git-dir="$gitdir" describe --long --always --dirty --tags --abbrev=16)"
fi

if [[ ! -f version ]] || ! cmp version <(printf '%s' "$buildid") >/dev/null 2>&1; then
  printf '%s' "$buildid" > version
fi
