#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
python3 -m venv .venv
touch .venv/.gdignore
.venv/bin/python register_native_host.py
echo '本機同步工具安裝完成。請在 Chrome/Edge 載入 extension 資料夾，再執行 ./start-linux.sh。'
