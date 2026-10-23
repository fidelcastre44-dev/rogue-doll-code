#!/bin/bash
# Télécharge les captures CMU utilisées (clips.py) : bash tools/cmu/fetch.sh <dossier>
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
D=${1:-$HOME/cmu}; mkdir -p "$D/bvh"
[ -d "$D/repo" ] || { git clone --depth 1 --filter=blob:none --sparse https://github.com/Shriinivas/cmubvh "$D/repo"; git -C "$D/repo" sparse-checkout set --no-cone /README.md; }
cd "$D/repo"
for id in $(grep -oE '"file": "[0-9]+_[0-9]+"' "$HERE/clips.py" | grep -oE '[0-9]+_[0-9]+' | sort -u); do
  p=$(git ls-tree -r --name-only HEAD | grep -E "/${id%_*}/Data/${id}\.zip$")
  git sparse-checkout add "/$p" 2>/dev/null; unzip -o -q "$p" -d "$D/bvh"
done
ls "$D/bvh"
