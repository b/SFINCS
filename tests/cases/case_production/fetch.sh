#!/bin/sh
# Download and unpack the production-style SFINCS validation case.
# See README.md for provenance, licensing, and case characteristics.
set -e

ARCHIVE_URL="https://github.com/b/SFINCS/releases/download/case-production-v1/case_production.tar.gz"
ARCHIVE_SHA256="5fff1bfd20940a3723f75e2c4c99de66d431e173f45556c7e3f3e86eefd7b6fc"
ARCHIVE_NAME="case_production.tar.gz"

cd "$(dirname "$0")"

# Idempotent: skip if the case is already extracted.
if [ -f sfincs.inp ]; then
    echo "case already extracted (sfincs.inp present); nothing to do."
    exit 0
fi

trap 'rm -f "$ARCHIVE_NAME"' EXIT INT TERM

curl -fsSL "$ARCHIVE_URL" -o "$ARCHIVE_NAME"

printf '%s  %s\n' "$ARCHIVE_SHA256" "$ARCHIVE_NAME" | sha256sum -c -

tar -xzf "$ARCHIVE_NAME"

rm -f "$ARCHIVE_NAME"
trap - EXIT INT TERM

if [ ! -f sfincs.inp ]; then
    echo "fetch.sh: archive extracted but sfincs.inp not found" >&2
    exit 1
fi

echo "case_production: ready ($(pwd)/sfincs.inp)"
