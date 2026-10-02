#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
python3 -m venv .venv
touch .venv/.gdignore
.venv/bin/python -m pip install -r requirements.txt
.venv/bin/python -m playwright install chromium
echo '安裝完成。執行 ./start-linux.sh；需先安裝 Godot 4.4+。'
