#!/bin/bash
# Prépare un projet Godot de cuisson HORS dépôt (/home/claude/bake) : les FBX Mixamo listés dans data/anim_list.json y sont
# liés (liens symboliques), les modèles copiés, puis Godot importe tout. Ensuite : tools/bake/run_bake.sh
set -e
V2=$(cd "$(dirname "$0")/../.." && pwd)
REPO=$(cd "$V2/.." && pwd)
B=${BAKE_DIR:-/home/claude/bake}
mkdir -p "$B/src" "$B/assets/hero" "$B/assets/anims" "$B/tools"
cp -r "$V2/assets/hero/male" "$V2/assets/hero/female" "$B/assets/hero/"
cp "$V2/assets/anims/Mannequin_F.glb" "$B/assets/anims/"
cp "$V2/tools/bake/bake.gd" "$V2/tools/bake/anim_sheet.gd" "$V2/tools/bake/mx_times.gd" "$B/tools/" 2>/dev/null || true
cp "$V2/data/anim_list.json" "$B/anim_list.json"
cat > "$B/project.godot" <<EOP
config_version=5
[application]
config/name="bake"
config/features=PackedStringArray("4.7")
[rendering]
textures/vram_compression/import_etc2_astc=true
EOP
python3 - "$V2/data/anim_list.json" "$B/src" "$REPO" <<'PY'
import json, os, sys
lst, dst, repo = sys.argv[1:4]
d = json.load(open(lst))
for k, v in d.items():
    if k.startswith("_"): continue
    src, opts = v
    kind, name = src.split(":", 1)
    if kind == "v2": p = f"{repo}/anim_library/mixamo_v2/rd_v2__{name}.fbx"
    else: p = f"{repo}/proto_combat/mixamo_src/rd_{name}.fbx"
    if not os.path.exists(p): print("MANQUE", k, p); continue
    link = f"{dst}/{k}.fbx"
    if os.path.islink(link): os.remove(link)
    os.symlink(p, link)
print("liens ok")
PY
cd "$B" && timeout 1500 ${GODOT:-/home/claude/godot} --headless --path . --import 2>&1 | grep -iE "error|fbx|import" | tail -5 || true
echo "projet de cuisson prêt : $B"
