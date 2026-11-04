"""RUNIVERSE 3.4.6: append test-game label; do not change gameplay."""
from pathlib import Path

root=Path(__file__).resolve().parents[1]
game=root/'scripts/game.gd'
s=game.read_text(encoding='utf-8')
needle='_label(m, "RUNIVERSE", Vector2(80, 132), Vector2(760, 125), 88, Color("fff1ce"), false)'
assert s.count(needle)==1, "Main menu RUNIVERSE heading not found"
# Preserve the existing heading size and add a subtler annotation on the same row.
addition='_label(m, "(тестовая игра)", Vector2(700, 185), Vector2(515, 52), 30, Color("fff1ce"), false)'
s=s.replace(needle,needle+'\n\t'+addition,1)
game.write_text(s,encoding='utf-8')

project=root/'project.godot'
p=project.read_text(encoding='utf-8')
assert p.count('config/name="RUNIVERSE"')==1, "Godot application title missing"
p=p.replace('config/name="RUNIVERSE"','config/name="RUNIVERSE (тестовая игра)"',1)
project.write_text(p,encoding='utf-8')
(root/'VERSION.txt').write_text('3.4.6-test-title\n',encoding='utf-8')
print("RUNIVERSE 3.4.6: main menu and application title updated; gameplay untouched")
