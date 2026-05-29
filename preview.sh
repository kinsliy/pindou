#!/bin/sh
set -e
PORT="${PORT:-4173}"
python3 -m http.server "$PORT" -d "$(dirname "$0")"
