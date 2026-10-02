#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DISPLAY=:90
export LIBGL_ALWAYS_SOFTWARE=1
export XDG_DATA_HOME="$PWD/output/validation90-data"
mkdir -p "$XDG_DATA_HOME"
godot --headless --editor --path . --import --quit
for script in tests/reminder_policy.gd tests/ui_smoke.gd tests/interaction.gd tests/preview_views.gd; do
  timeout 45 godot --display-driver x11 --path . --script "$script"
done
BENTO_EXTENSION_TEST=1 BENTO_TEST_DISPLAY=:90 .venv/bin/python -m unittest discover -s tests -v
