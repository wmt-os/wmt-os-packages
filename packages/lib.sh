#!/bin/bash
# Copyright (C) 2026 Logan Russell <me@lrussell.net>

export BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
OUT=${OUT:-$SRC/dist}
. "$BASE_DIR/config.sh"

renice "$NICE" -p $$ >/dev/null 2>&1 || true
