#!/bin/sh
# Exports the web build into docs/ (served by GitHub Pages) and copies the
# browser-side head/tilt tracker next to it.
set -eu
cd "$(dirname "$0")/.."
mkdir -p docs
touch docs/.gdignore docs/.nojekyll
~/.agents/bin/heavy 300 godot --headless --path . --export-release "Web" docs/index.html
cp web/headtrack.js docs/headtrack.js
echo "Built docs/ ($(du -sh docs | cut -f1))"
