"""RUNIVERSE 3.4.2: correct GLB Z-up/Y-up orientation and limb pivots."""
from pathlib import Path
p=Path(__file__).resolve().parents[1]/"scripts/character.gd"
s=p.read_text(encoding="utf-8")
changes=[
 ("rig.add_child(cartoon_body)", "rig.add_child(cartoon_body)\n\t# GLB was authored Z-up; rotate to Godot Y-up.\n\tcartoon_body.rotation.x = -PI / 2.0"),
 ("Vector3(0.50 * sign_x, 1.62, 0.0)", "Vector3(0.50 * sign_x, 0.0, 1.62)"),
 ("Vector3(0.22 * sign_x, 0.91, 0.0)", "Vector3(0.22 * sign_x, 0.0, 0.91)")
]
for old,new in changes:
 if s.count(old)!=1:
  raise SystemExit("Expected one occurrence of %r, got %d"%(old,s.count(old)))
 s=s.replace(old,new)
p.write_text(s,encoding="utf-8")
(p.parent.parent/"VERSION.txt").write_text("3.4.2-preview\n",encoding="utf-8")
print("RUNIVERSE 3.4.2: GLB upright and pivots corrected")
