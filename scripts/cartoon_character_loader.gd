# Godot 4 - cartoon-character asset loader for editable project.
# This does not alter the compiled original RUNIVERSE 3.2 FIXED EXE.
extends Node
class_name CartoonCharacterLoader

const CHARACTER_IDS := [
  "runner", "neon", "kitsune", "captain", "panda",
  "robo7", "pirate", "ninja", "astro", "dino",
  "skelly", "phoenix", "ice", "techno", "catboy"
]
const ROOT := "res://characters_cartoon15/"

static func get_model_path(character_id: int) -> String:
  if character_id < 0 or character_id >= CHARACTER_IDS.size():
    return ""
  return ROOT + "models/%02d_%s.glb" % [character_id, CHARACTER_IDS[character_id]]

static func get_shop_image_path(character_id: int) -> String:
  if character_id < 0 or character_id >= CHARACTER_IDS.size():
    return ""
  return ROOT + "shop/%02d_%s.png" % [character_id, CHARACTER_IDS[character_id]]

static func spawn_model(parent: Node3D, character_id: int) -> Node3D:
  var path := get_model_path(character_id)
  if path.is_empty() or not ResourceLoader.exists(path):
    return null
  var resource := load(path) as PackedScene
  if resource == null:
    return null
  var hero := resource.instantiate() as Node3D
  if hero != null:
    parent.add_child(hero)
  return hero

static func set_shop_image(target: TextureRect, character_id: int) -> void:
  var path := get_shop_image_path(character_id)
  if ResourceLoader.exists(path):
    target.texture = load(path) as Texture2D
