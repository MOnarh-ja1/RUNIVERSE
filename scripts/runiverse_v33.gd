extends Node3D

# RUNIVERSE 3.3.0 — complete standalone Godot 4.7 runtime game source.
# GLB characters 0–14 are loaded as real meshes in the running world.
# The identical selected ID is used for shop state, save state and spawn.

const VERSION := "3.3.0"
const SAVE_FILE := "user://runiverse_v33_save.json"
const START_COINS := 12750
const LANE_GAP := 2.25
const PLAYER_Z := 3.0
const WORLDS := [
    {"name":"Солнечный город", "price":0, "road":"#263b59", "floor":"#254c57", "accent":"#ffca70", "sky":"#162a49"},
    {"name":"Зелёный лес", "price":3600, "road":"#32483f", "floor":"#356d51", "accent":"#e3bd63", "sky":"#19372e"},
    {"name":"Золотая пустыня", "price":7900, "road":"#7b5940", "floor":"#be8a4b", "accent":"#ffd37a", "sky":"#654e5e"},
    {"name":"Ледяной перевал", "price":14600, "road":"#365677", "floor":"#a9d8ef", "accent":"#f6faff", "sky":"#243c64"},
    {"name":"Космическая трасса", "price":23200, "road":"#283056", "floor":"#424070", "accent":"#7ff9eb", "sky":"#1d193e"}
]

var characters: Array = []
var player_data: Dictionary = {}
var selected: int = 0
var selected_world: int = 0
var mode := "menu"
var coins: int = 12750
var run_coins: int = 0
var distance: float = 0.0
var best: int = 0
var lane: int = 0
var speed: float = 16.0
var t: float = 0.0
var spawn_clock: float = 0.0
var jump_clock: float = 0.0
var slide_clock: float = 0.0
var shield_clock: float = 0.0
var magnets_clock: float = 0.0
var running: bool = false
var paused: bool = false
var sound_on: bool = true
var page_index: int = 0
var selected_filter := "Все"
var world_root: Node3D
var scenery_root: Node3D
var road_ground: MeshInstance3D
var road_track: MeshInstance3D
var player_root: Node3D
var hero_model: Node3D
var arm_left: Node3D
var arm_right: Node3D
var leg_left: Node3D
var leg_right: Node3D
var spawned: Array = []
var lane_marks: Array = []
var scene_cache: Dictionary = {}
var ui_layer: CanvasLayer
var ui: Control
var hud_coins: Label
var hud_dist: Label
var hud_power: Label
var background: TextureRect
var menu_background: Texture2D
var image_cache: Dictionary = {}
var run_score: int = 0
var coin_streak: int = 0
var streak_timer: float = 0.0

func _ready() -> void:
    randomize()
    get_window().title = "RUNIVERSE 3.3 | MgameIO"
    var raw := FileAccess.get_file_as_string("res://data/characters.json")
    var parsed: Variant = JSON.parse_string(raw)
    if parsed is Array:
        characters = parsed
    else:
        push_error("Не загружен каталог героев")
    menu_background = _image_texture("res://assets/bg.jpg")
    _load_save()
    _build_world()
    ui_layer = CanvasLayer.new()
    ui_layer.layer = 12
    add_child(ui_layer)
    ui = Control.new()
    ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    ui_layer.add_child(ui)
    _show_menu()

func _image_texture(path: String) -> Texture2D:
    if image_cache.has(path):
        return image_cache[path]
    var img := Image.load_from_file(path)
    if img == null or img.is_empty():
        return null
    var tex := ImageTexture.create_from_image(img)
    image_cache[path] = tex
    return tex

func _load_save() -> void:
    player_data = {"owned": [0], "worlds": [0], "coins": START_COINS, "selected": 0,
        "world": 0, "best": 0, "sound": true}
    if FileAccess.file_exists(SAVE_FILE):
        var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_FILE))
        if saved is Dictionary:
            for k in saved.keys():
                player_data[k] = saved[k]
    coins = maxi(0, int(player_data.get("coins", START_COINS)))
    selected = clampi(int(player_data.get("selected", 0)), 0, maxi(0, characters.size() - 1))
    selected_world = clampi(int(player_data.get("world", 0)), 0, WORLDS.size() - 1)
    best = maxi(0, int(player_data.get("best", 0)))
    sound_on = bool(player_data.get("sound", true))
    if not _owned(selected):
        selected = 0
    if not _world_owned(selected_world):
        selected_world = 0

func _save() -> void:
    player_data["coins"] = coins
    player_data["selected"] = selected
    player_data["world"] = selected_world
    player_data["best"] = best
    player_data["sound"] = sound_on
    var f := FileAccess.open(SAVE_FILE, FileAccess.WRITE)
    if f != null:
        f.store_string(JSON.stringify(player_data))
        f.close()

func _owned(id: int) -> bool:
    for n in player_data.get("owned", [0]):
        if int(n) == id:
            return true
    return id == 0

func _world_owned(id: int) -> bool:
    for n in player_data.get("worlds", [0]):
        if int(n) == id:
            return true
    return id == 0

func _mat(h: String, emission: bool = false) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = Color.html(h)
    m.metallic = 0.12
    m.roughness = 0.56
    if emission:
        m.emission_enabled = true
        m.emission = Color.html(h)
        m.emission_energy_multiplier = 0.38
    return m

func _box(parent: Node3D, where: Vector3, size: Vector3, color: String, shiny: bool = false) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    mi.mesh = mesh
    mi.position = where
    mi.material_override = _mat(color, shiny)
    parent.add_child(mi)
    return mi

func _ball(parent: Node3D, where: Vector3, radius: float, color: String, shiny: bool = false) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var mesh := SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0
    mi.mesh = mesh
    mi.position = where
    mi.material_override = _mat(color, shiny)
    parent.add_child(mi)
    return mi

func _build_world() -> void:
    world_root = Node3D.new()
    add_child(world_root)
    var environment := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color.html("#1a2c49")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color.html("#c1c9e0")
    env.ambient_light_energy = 0.8
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    environment.environment = env
    world_root.add_child(environment)
    var sun := DirectionalLight3D.new()
    sun.light_energy = 1.75
    sun.rotation_degrees = Vector3(-48, 35, -15)
    world_root.add_child(sun)
    var camera := Camera3D.new()
    camera.position = Vector3(0, 5.3, 14.2)
    world_root.add_child(camera)
    camera.look_at(Vector3(0, 1.0, -14), Vector3.UP)
    camera.fov = 69.0
    camera.current = true
    road_ground = _box(world_root, Vector3(0, -0.48, -18), Vector3(250, 0.38, 180), "#244959")
    road_track = _box(world_root, Vector3(0, -0.18, -19), Vector3(8.3, 0.26, 160), "#263c56")
    for side in [-1.0, 1.0]:
        _box(world_root, Vector3(side * 4.25, 0, -19), Vector3(0.22, 0.5, 160), "#ffb960", true)
    for row in range(25):
        for x in [-1.125, 1.125]:
            var dash := _box(world_root, Vector3(x, -0.018, -float(row) * 5.7 + 9.0),
                Vector3(0.09, 0.045, 2.4), "#bad6e7")
            lane_marks.append(dash)
    scenery_root = Node3D.new()
    scenery_root.name = "WorldScenery"
    world_root.add_child(scenery_root)
    player_root = Node3D.new()
    player_root.position = Vector3(0, 0.0, PLAYER_Z)
    world_root.add_child(player_root)
    _spawn_hero(selected)
    _apply_world()
    world_root.visible = false

func _apply_world() -> void:
    var theme: Dictionary = WORLDS[selected_world]
    var env: WorldEnvironment = null
    for n in world_root.get_children():
        if n is WorldEnvironment:
            env = n
            break
    if env != null:
        env.environment.background_color = Color.html(str(theme["sky"]))
    road_ground.material_override = _mat(str(theme["floor"]))
    road_track.material_override = _mat(str(theme["road"]))
    # Distinct procedural scenery for all five purchasable locations.
    for existing in scenery_root.get_children():
        scenery_root.remove_child(existing)
        existing.queue_free()
    for side in [-1.0, 1.0]:
        for i in range(16):
            var pos := Vector3(side * (9.0 + float(i % 3) * 1.75), 0, -float(i) * 8.7 + 8.0)
            var landmark := Node3D.new()
            scenery_root.add_child(landmark)
            landmark.position = pos
            if selected_world == 0: # City
                var high := 3.7 + float((i * 7) % 6)
                _box(landmark, Vector3(0,high*.5-.25,0),Vector3(3.2,high,3.4),"#345c7e")
                _box(landmark, Vector3(0,high*.7,1.74),Vector3(1.0,.25,.08),"#f9ce79",true)
            elif selected_world == 1: # Forest
                _box(landmark,Vector3(0,1.7,0),Vector3(.56,3.4,.56),"#65513d")
                _ball(landmark,Vector3(0,3.8,0),2.15,"#3c9661")
                _ball(landmark,Vector3(-.7,3.0,.25),1.5,"#54b57d")
            elif selected_world == 2: # Desert
                var pyramid := MeshInstance3D.new()
                var pyramid_mesh := CylinderMesh.new()
                pyramid_mesh.top_radius = 0.0
                pyramid_mesh.bottom_radius = 2.3
                pyramid_mesh.height = 4.8 + float(i%3)
                pyramid_mesh.radial_segments = 4
                pyramid.mesh = pyramid_mesh
                pyramid.material_override = _mat("#eebf70")
                pyramid.position.y = pyramid_mesh.height/2.0
                pyramid.rotation.y = PI*.25
                landmark.add_child(pyramid)
            elif selected_world == 3: # Ice
                _box(landmark,Vector3(0,2.7,0),Vector3(1.6,5.4,1.6),"#87e3ef",true)
                _box(landmark,Vector3(1.0,1.55,-.8),Vector3(1.4,3.1,1.4),"#d4f9ff")
            else: # Space
                _box(landmark,Vector3(0,3.0,0),Vector3(2.1,6.0,2.3),"#514d8c")
                for floor in range(3):
                    _box(landmark,Vector3(0,1.5+floor*1.7,1.2),Vector3(1.7,.22,.12),"#66eade",true)

func _walk_meshes(n: Node) -> Array:
    var result: Array = []
    if n is MeshInstance3D:
        result.append(n)
    for child in n.get_children():
        result.append_array(_walk_meshes(child))
    return result

func _load_character_scene(id: int) -> Node3D:
    var model_path := "res://assets/models/%02d_%s.glb" % [id, ["runner","alpha","ninja","elf","knight","witch","pirate","astro","cyborg","pilot","samurai","valkyrie","hunter","assassin","scientist"][id]]
    if scene_cache.has(id):
        return (scene_cache[id] as PackedScene).instantiate()
    var document := GLTFDocument.new()
    var state := GLTFState.new()
    var err := document.append_from_file(model_path, state)
    if err != OK:
        push_error("Ошибка загрузки GLB героя %d: %d" % [id, err])
        return null
    var model := document.generate_scene(state)
    if model == null:
        return null
    var scene := PackedScene.new()
    if scene.pack(model) == OK:
        scene_cache[id] = scene
    return model

func _spawn_hero(id: int) -> void:
    if hero_model != null:
        player_root.remove_child(hero_model)
        hero_model.queue_free()
    hero_model = Node3D.new()
    hero_model.name = "PlayableHero_%d" % id
    player_root.add_child(hero_model)
    hero_model.rotation.y = PI
    arm_left = null
    arm_right = null
    leg_left = null
    leg_right = null
    if id < 15:
        var loaded := _load_character_scene(id)
        if loaded != null:
            hero_model.add_child(loaded)
            _create_limb_animation_rig(loaded)
        else:
            _placeholder_hero(hero_model, id)
    else:
        _placeholder_hero(hero_model, id)

func _create_limb_animation_rig(model: Node3D) -> void:
    # GLBs contain actual body, face, clothes and individually named arms/legs.
    # Group their mesh parts under hip/shoulder pivots to animate them in-game.
    var pivots: Dictionary = {}
    for kind in ["arm", "leg"]:
        for side in [-1, 1]:
            var pivot := Node3D.new()
            pivot.name = "%s_%s" % [kind, "left" if side < 0 else "right"]
            if kind == "arm":
                pivot.position = Vector3(side * 0.43, 1.54, 0.0)
            else:
                pivot.position = Vector3(side * 0.19, 0.85, 0.0)
            model.add_child(pivot)
            pivots["%s_%d" % [kind, side]] = pivot
    for mesh_node in _walk_meshes(model):
        var label := mesh_node.name.to_lower()
        var kind := ""
        if ("upper-arm" in label or "forearm" in label or "elbow" in label or "hand_" in label or "pauldron" in label):
            kind = "arm"
        elif ("upper-leg" in label or "lower-leg" in label or "knee" in label or "oversized-boot" in label or "sole_" in label):
            kind = "leg"
        if kind == "":
            continue
        var mi: MeshInstance3D = mesh_node
        var center := mi.global_transform * mi.mesh.get_aabb().get_center()
        var side: int = -1 if center.x < 0 else 1
        mi.reparent(pivots["%s_%d" % [kind, side]], true)
    arm_left = pivots["arm_-1"]
    arm_right = pivots["arm_1"]
    leg_left = pivots["leg_-1"]
    leg_right = pivots["leg_1"]

func _placeholder_hero(parent: Node3D, id: int) -> void:
    var c := str(characters[id].get("color", "4d9fdb"))
    var tint := "#" + c
    var body := Node3D.new()
    parent.add_child(body)
    _box(body, Vector3(0, 1.30, 0), Vector3(0.7, 0.85, 0.48), tint)
    _ball(body, Vector3(0, 2.08, 0), 0.37, "#f6c4a0")
    _box(body, Vector3(0, 2.42, 0), Vector3(0.76, 0.18, 0.60), tint)
    for s in [-1.0, 1.0]:
        var arm := Node3D.new()
        arm.position = Vector3(s * .47, 1.63, 0)
        body.add_child(arm)
        _box(arm, Vector3(0,-.25,.1), Vector3(.21,.58,.24), tint)
        var leg := Node3D.new()
        leg.position = Vector3(s * .20,.78,0)
        body.add_child(leg)
        _box(leg,Vector3(0,-.28,.04),Vector3(.23,.57,.27),"#29324b")
        if s < 0:
            arm_left = arm
            leg_left = leg
        else:
            arm_right = arm
            leg_right = leg
    for x in [-.135,.135]:
        _ball(body,Vector3(x,2.13,.342),.061,"#1b304c")

func _style(pad: int = 15, fill: String = "#182a40", border: String = "#4b6985", radius: int = 13) -> StyleBoxFlat:
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color.html(fill)
    sb.border_color = Color.html(border)
    sb.set_border_width_all(2)
    sb.set_corner_radius_all(radius)
    sb.content_margin_left = pad
    sb.content_margin_right = pad
    sb.content_margin_top = pad
    sb.content_margin_bottom = pad
    return sb

func _node_rect(n: Control, x: float, y: float, w: float, h: float) -> void:
    n.set_anchors_preset(Control.PRESET_TOP_LEFT)
    n.position = Vector2(x, y)
    n.size = Vector2(w, h)

func _label(parent: Node, label: String, x: float, y: float, w: float, h: float,
    font_size: int = 20, color: String = "#f3f6ff", center: bool = false) -> Label:
    var l := Label.new()
    parent.add_child(l)
    _node_rect(l,x,y,w,h)
    l.text = label
    l.add_theme_font_size_override("font_size", font_size)
    l.add_theme_color_override("font_color", Color.html(color))
    l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if center else HORIZONTAL_ALIGNMENT_LEFT
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return l

func _panel(parent: Node, x: float, y: float, w: float, h: float,
    fill: String = "#162439", border: String = "#476987", radius: int = 16) -> Panel:
    var p := Panel.new()
    parent.add_child(p)
    _node_rect(p,x,y,w,h)
    p.add_theme_stylebox_override("panel", _style(0,fill,border,radius))
    p.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return p

func _button(parent: Node, caption: String, x: float, y: float, w: float, h: float,
    callback: Callable, alt: bool = false, font_size: int = 20) -> Button:
    var b := Button.new()
    parent.add_child(b)
    _node_rect(b,x,y,w,h)
    b.text = caption
    b.add_theme_font_size_override("font_size", font_size)
    b.add_theme_color_override("font_color", Color.html("#fff4d4"))
    b.add_theme_stylebox_override("normal", _style(6,"#24675e" if alt else "#604036", "#90eccb" if alt else "#ffc66b"))
    b.add_theme_stylebox_override("hover", _style(6,"#369080" if alt else "#885143","#ccf9db" if alt else "#ffe9a9"))
    b.add_theme_stylebox_override("pressed", _style(6,"#215047" if alt else "#45302b","#96b8aa"))
    b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
    b.pressed.connect(callback)
    return b

func _bg() -> void:
    ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
    background = TextureRect.new()
    background.texture = menu_background
    background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    background.stretch_mode = TextureRect.STRETCH_SCALE
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    ui.add_child(background)
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var dark := ColorRect.new()
    dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    dark.color = Color(0.015, 0.028, 0.056, 0.32)
    dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui.add_child(dark)

func _clear_ui() -> void:
    for n in ui.get_children():
        ui.remove_child(n)
        n.queue_free()
    hud_coins = null
    hud_dist = null
    hud_power = null

func _header(subtitle: String, back: bool = true) -> void:
    _label(ui,"RUNIVERSE",425,12,430,88,67,"#ffdb89",true)
    _label(ui,subtitle,350,93,580,34,21,"#e9f8ff",true)
    _panel(ui,1015,25,235,55,"#3c2831","#f4bd6c")
    _label(ui,"🪙  %s" % _money(coins),1035,31,194,44,24,"#ffe9b0",true)
    if back:
        _button(ui,"← Назад",32,26,175,52,func(): _show_menu())

func _money(n: int) -> String:
    var s := str(n)
    var out := ""
    var j := 0
    for i in range(s.length() - 1,-1,-1):
        if j > 0 and j % 3 == 0:
            out = " " + out
        out = s.substr(i,1) + out
        j += 1
    return out

func _show_menu() -> void:
    mode = "menu"
    running = false
    paused = false
    world_root.visible = false
    _clear_ui()
    _bg()
    _header("MgameIO · 3D ENDLESS RUNNER  ·  версия " + VERSION, false)
    _panel(ui,106,171,650,454,"#112039","#6e6884")
    var entries = [
        ["▶   Одиночная игра", "play"],
        ["★   Магазин персонажей", "shop"],
        ["◈   Выбрать мир", "worlds"],
        ["⚙   Настройки", "settings"]
    ]
    for i in range(entries.size()):
        var item: Array = entries[i]
        var action: String = item[1]
        _button(ui,str(item[0]),140,211 + i * 94,580,70,func(): _menu_action(action), i==0,25)
    _label(ui,"Рекорд: %d м" % best,161,594,260,30,17,"#b6c9e0")
    _label(ui,"Выбран: " + _hero_name(selected),433,594,278,30,16,"#d4e6ff")
    _panel(ui,805,171,370,454,"#142237","#b18c77")
    _portrait(ui,selected,842,192,295,306)
    _label(ui,_hero_name(selected),827,501,326,40,29,"#ffe19d",true)
    _label(ui,str(characters[selected].get("perk", "")),840,542,300,53,15,"#d5e7f6",true)
    _label(ui,"MgameIO",520,651,240,36,21,"#d3d5db",true)
    _button(ui,"Выход",1094,647,154,42,func(): get_tree().quit(),false,17)

func _menu_action(which: String) -> void:
    if which == "play":
        _start_run()
    elif which == "shop":
        page_index = int(selected / 10)
        _show_shop()
    elif which == "worlds":
        _show_worlds()
    elif which == "settings":
        _show_settings()

func _portrait(parent: Node, id: int, x: float, y: float, w: float, h: float) -> void:
    var image := TextureRect.new()
    parent.add_child(image)
    _node_rect(image,x,y,w,h)
    image.texture = _image_texture("res://assets/portraits/%02d.jpg" % id)
    image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    image.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _hero_name(id: int) -> String:
    return str(characters[id].get("name", "Герой")) if id < characters.size() else "Герой"

func _hero_price(id: int) -> int:
    var price := int(characters[id].get("price",0))
    if selected < characters.size() and str(characters[selected].get("bonus_key","")) == "shop_discount":
        price = int(round(float(price)*(1.0-float(characters[selected].get("bonus_value",0.0)))))
    return maxi(0, price)

func _show_shop() -> void:
    mode = "shop"
    world_root.visible = false
    _clear_ui()
    _bg()
    _header("МАГАЗИН ПЕРСОНАЖЕЙ  ·  ПЕРВЫЕ 15 В НОВОМ 3D-СТИЛЕ")
    var cats = ["Все", "Бегуны", "Воины", "Маги", "Будущее", "Маскоты"]
    for k in range(cats.size()):
        var cat: String = cats[k]
        _button(ui,cat,48 + k * 199,139,185,43,func(): _set_filter(cat),cat == selected_filter,17)
    var allowed: Array = []
    for i in range(characters.size()):
        if selected_filter == "Все" or str(characters[i].get("category", "")) == selected_filter:
            allowed.append(i)
    var pages: int = maxi(1,ceili(float(allowed.size()) / 10.0))
    page_index = clampi(page_index,0,pages-1)
    var start := page_index * 10
    for row in range(2):
        for col in range(5):
            var pos := start + row * 5 + col
            if pos >= allowed.size():
                break
            var hero_id: int = allowed[pos]
            var x := 36 + col * 244
            var y := 195 + row * 217
            var is_selected := selected == hero_id
            _panel(ui,x,y,229,204,"#26364c" if is_selected else "#162739",
                "#84ffd3" if is_selected else "#916b4e",10)
            _portrait(ui,hero_id,x+8,y+7,83,126)
            _label(ui,_hero_name(hero_id),x+99,y+8,123,35,15,"#ffe6ae")
            var perk := str(characters[hero_id].get("perk",""))
            _label(ui,perk,x+99,y+40,118,61,13,"#bbd2ed")
            var state := "ВЫБРАН" if is_selected else ("Выбрать" if _owned(hero_id) else "🪙 " + _money(_hero_price(hero_id)))
            _button(ui,state,x+9,y+147,210,45,func(): _choose_hero(hero_id), _owned(hero_id),15)
    _button(ui,"←",379,642,88,50,func(): _move_page(-1))
    _label(ui,"Страница %d / %d" % [page_index + 1,pages],473,642,333,50,20,"#ffffff",true)
    _button(ui,"→",811,642,88,50,func(): _move_page(1))

func _set_filter(category: String) -> void:
    selected_filter = category
    page_index = 0
    _show_shop()

func _move_page(direction: int) -> void:
    page_index += direction
    _show_shop()

func _choose_hero(id: int) -> void:
    if not _owned(id):
        var price := _hero_price(id)
        if coins < price:
            _message("Недостаточно монет", "Нужно ещё %s монет." % _money(price - coins), func(): _show_shop())
            return
        coins -= price
        player_data["owned"].append(id)
    selected = id
    _save()
    # This is the fix: shop selection immediately changes the real 3D run model.
    _spawn_hero(selected)
    _show_shop()

func _show_worlds() -> void:
    mode = "worlds"
    world_root.visible = false
    _clear_ui()
    _bg()
    _header("ОТКРЫВАЙ НОВЫЕ МИРЫ ЗА МОНЕТЫ")
    for i in range(WORLDS.size()):
        var w: Dictionary = WORLDS[i]
        var x := 60 + i * 244
        _panel(ui,x,199,228,354,str(w["road"]),"#e6bf82")
        _label(ui,str(w["name"]),x+11,229,208,67,21,"#fff3ce",true)
        _label(ui,"МИР %d" % [i+1],x+12,312,202,41,17,"#b7d8e5",true)
        var caption := "Выбран" if selected_world == i else ("Выбрать" if _world_owned(i) else "🪙 " + _money(int(w["price"])))
        _button(ui,caption,x+13,469,202,59,func(): _choose_world(i),_world_owned(i),17)
    _label(ui,"Новые миры отличаются окружением и атмосферой. Прогресс забегов общий.",85,580,1100,55,19,"#b3d4e9",true)

func _choose_world(id: int) -> void:
    if not _world_owned(id):
        var price := int(WORLDS[id]["price"])
        if coins < price:
            _message("Недостаточно монет", "Нужно ещё %s монет." % _money(price - coins), func(): _show_worlds())
            return
        coins -= price
        player_data["worlds"].append(id)
    selected_world = id
    _save()
    _apply_world()
    _show_worlds()

func _show_settings() -> void:
    mode = "settings"
    world_root.visible = false
    _clear_ui()
    _bg()
    _header("НАСТРОЙКИ ИГРЫ")
    _panel(ui,306,176,673,413)
    _label(ui,"RUNIVERSE " + VERSION,370,212,550,48,31,"#ffe5b6",true)
    _button(ui,"Звуковые эффекты: " + ("ВКЛ" if sound_on else "ВЫКЛ"),390,299,500,63,func(): _toggle_sound(),true,21)
    _label(ui,"Управление: A / D — полосы, W / ПРОБЕЛ — прыжок, S — подкат.",358,402,585,67,18,"#c8deed",true)
    _label(ui,"ESC во время игры — пауза. Сохранения записываются автоматически.",365,489,580,58,17,"#bdcfdf",true)

func _toggle_sound() -> void:
    sound_on = not sound_on
    _save()
    _show_settings()

func _message(title: String, message: String, go_back: Callable) -> void:
    _clear_ui()
    _bg()
    _panel(ui,306,165,670,400)
    _label(ui,title,348,212,590,62,34,"#ffcf91",true)
    _label(ui,message,350,308,585,76,23,"#e6ecf7",true)
    _button(ui,"Хорошо",464,455,355,68,go_back,true,23)

func _start_run() -> void:
    if characters.size() == 0:
        return
    running = true
    paused = false
    mode = "run"
    run_coins = 0
    run_score = 0
    coin_streak = 0
    streak_timer = 0
    distance = 0
    speed = 16.0
    spawn_clock = 0.2
    lane = 0
    t = 0
    jump_clock = 0
    slide_clock = 0
    shield_clock = 0
    magnets_clock = 0
    for o in spawned:
        if is_instance_valid(o["node"]):
            o["node"].queue_free()
    spawned.clear()
    _apply_world()
    _spawn_hero(selected)
    player_root.position = Vector3(0,0,PLAYER_Z)
    world_root.visible = true
    _clear_ui()
    _panel(ui,16,12,367,108,"#15243c","#5f7d9c")
    hud_coins = _label(ui,"Монеты: 0",32,18,310,43,22,"#ffe09a")
    hud_dist = _label(ui,"0 м",32,66,310,43,22,"#e2f6ff")
    _label(ui,_hero_name(selected),482,21,320,50,26,"#f0dcb9",true)
    hud_power = _label(ui,str(characters[selected].get("perk","")),386,68,503,37,15,"#9fe6d8",true)
    _button(ui,"Ⅱ Пауза",1062,23,190,60,func(): _toggle_pause())

func _toggle_pause() -> void:
    if not running:
        return
    paused = not paused
    if paused:
        _panel(ui,399,163,483,377,"#0a1f34","#ffcd80")
        _label(ui,"ПАУЗА",425,197,435,80,38,"#ffd89a",true)
        _button(ui,"Продолжить",456,302,369,70,func(): _resume(),true,24)
        _button(ui,"Главное меню",456,403,369,67,func(): _pause_exit(),false,22)
    else:
        _render_running_ui()

func _resume() -> void:
    paused = false
    _render_running_ui()

func _pause_exit() -> void:
    _save()
    _show_menu()

func _render_running_ui() -> void:
    _clear_ui()
    _panel(ui,16,12,367,108,"#15243c","#5f7d9c")
    hud_coins = _label(ui,"Монеты: %d" % run_coins,32,18,310,43,22,"#ffe09a")
    hud_dist = _label(ui,"%d м" % int(distance),32,66,310,43,22,"#e2f6ff")
    _label(ui,_hero_name(selected),482,21,320,50,26,"#f0dcb9",true)
    hud_power = _label(ui,str(characters[selected].get("perk","")),386,68,503,37,15,"#9fe6d8",true)
    _button(ui,"Ⅱ Пауза",1062,23,190,60,func(): _toggle_pause())

func _process(delta: float) -> void:
    if not running or paused:
        return
    delta = minf(delta,0.05)
    t += delta
    distance += delta * speed * 2.0
    speed = minf(32.0,16.0 + distance / 360.0)
    var perk: Dictionary = characters[selected]
    var bonus_key := str(perk.get("bonus_key",""))
    var bonus_value := float(perk.get("bonus_value",0.0))
    if bonus_key == "speed_mul":
        speed *= 1.0 + bonus_value
    streak_timer = maxf(0.0, streak_timer - delta)
    if streak_timer == 0:
        coin_streak = 0
    var earned_points := 4.0 * delta * speed
    if bonus_key in ["score_mul", "combo_mult"]:
        earned_points *= 1.0 + bonus_value * (minf(1.0, float(coin_streak)/3.0) if bonus_key == "combo_mult" else 1.0)
    run_score += int(round(earned_points))
    var target_x: float = float(lane) * LANE_GAP
    player_root.position.x = lerpf(player_root.position.x,target_x,minf(1.0,delta*13.5 * (1.0 + bonus_value if bonus_key == "lane_agility" else 1.0)))
    if jump_clock > 0:
        jump_clock = maxf(0.0,jump_clock-delta)
        var jump_time := 0.75 * (1.0 + bonus_value * 0.4 if bonus_key == "jump_mul" else 1.0)
        var jump_height := 1.95 * (1.0 + bonus_value if bonus_key == "jump_mul" else 1.0)
        player_root.position.y = jump_height * sin((1.0 - jump_clock / jump_time) * PI)
    else:
        player_root.position.y = 0.0
    slide_clock = maxf(0.0, slide_clock - delta)
    shield_clock = maxf(0.0, shield_clock - delta)
    magnets_clock = maxf(0.0, magnets_clock - delta)
    var squash := 0.60 if slide_clock > 0 else 1.0
    hero_model.scale.y = lerpf(hero_model.scale.y,squash,minf(1.0,delta*16.0))
    hero_model.position.y = 0.03 + (0.07 * absf(sin(t*13.5)) if slide_clock <= 0 else 0.0)
    hero_model.rotation.x = -0.15 if jump_clock > 0 else (0.3 if slide_clock > 0 else 0.0)
    var swing := sin(t * 13.5) * 0.54
    if arm_left != null:
        arm_left.rotation.x = -swing
    if arm_right != null:
        arm_right.rotation.x = swing
    if leg_left != null:
        leg_left.rotation.x = swing
    if leg_right != null:
        leg_right.rotation.x = -swing
    for dash in lane_marks:
        dash.position.z += delta * speed
        if dash.position.z > 13:
            dash.position.z -= 142.5
    spawn_clock -= delta
    if spawn_clock <= 0:
        _spawn_group()
        spawn_clock = randf_range(0.8,1.25) * maxf(.62,16.0/speed)
    _update_objects(delta)
    if hud_coins != null and is_instance_valid(hud_coins):
        hud_coins.text = "Монеты: %d" % run_coins
    if hud_dist != null and is_instance_valid(hud_dist):
        hud_dist.text = "%d м" % int(distance)
    if hud_power != null and is_instance_valid(hud_power):
        hud_power.text = "Щит %.1f" % shield_clock if shield_clock > 0 else str(perk.get("perk",""))

func _spawn_group() -> void:
    var chosen := randi_range(-1,1)
    var ob := randi_range(0,2)
    var item := Node3D.new()
    item.position = Vector3(float(chosen)*LANE_GAP,0,-75)
    world_root.add_child(item)
    var shade := str(WORLDS[selected_world]["accent"])
    if ob == 0:
        # Short block: jump over or dodge.
        _box(item,Vector3(0,.50,0),Vector3(1.38,1.0,1.0),"#db724f")
        _box(item,Vector3(0,1.04,0),Vector3(1.55,.16,1.12),shade)
    elif ob == 1:
        # Beam: slide underneath or dodge.
        _box(item,Vector3(-.9,1.16,0),Vector3(.19,2.3,.26),"#686ba0")
        _box(item,Vector3(.9,1.16,0),Vector3(.19,2.3,.26),"#686ba0")
        _box(item,Vector3(0,1.98,0),Vector3(1.9,.45,.37),shade)
    else:
        # Tall pillar: change lane.
        _box(item,Vector3(0,1.30,0),Vector3(1.48,2.6,1.12),"#a15c79")
        _box(item,Vector3(0,2.6,0),Vector3(1.66,.2,1.3),shade)
    spawned.append({"node":item,"type":"hazard","ob":ob,"lane":chosen,"hit":false})
    var coinlane := chosen + (1 if chosen < 1 else -1)
    for i in range(3):
        var coin := Node3D.new()
        coin.position = Vector3(float(coinlane)*LANE_GAP,1.2,-84.0-float(i)*3.2)
        world_root.add_child(coin)
        _ball(coin,Vector3.ZERO,.37,"#ffc640",true)
        _ball(coin,Vector3(0,0,.24),.16,"#fff19b",true)
        spawned.append({"node":coin,"type":"coin","lane":coinlane,"hit":false})
    if randi_range(0,12) == 0:
        var power := Node3D.new()
        power.position = Vector3(float(coinlane)*LANE_GAP,1.2,-98)
        world_root.add_child(power)
        _ball(power,Vector3.ZERO,.56,"#42dce0",true)
        spawned.append({"node":power,"type":"shield","lane":coinlane,"hit":false})

func _update_objects(delta: float) -> void:
    for i in range(spawned.size()-1,-1,-1):
        var it: Dictionary = spawned[i]
        var n: Node3D = it["node"]
        if not is_instance_valid(n):
            spawned.remove_at(i)
            continue
        n.position.z += speed * delta
        if str(it["type"]) != "hazard":
            n.rotation.y += 3.5 * delta
        if n.position.z > 13:
            n.queue_free()
            spawned.remove_at(i)
            continue
        if bool(it["hit"]) or absf(n.position.z-PLAYER_Z)>0.90:
            continue
        var lane_match := int(it["lane"])==lane
        if str(it["type"]) == "coin":
            var magnet := str(characters[selected].get("bonus_key",""))=="magnet_radius"
            if lane_match or (magnet and abs(int(it["lane"])-lane)<=1):
                _pick_coin()
                it["hit"] = true
                n.queue_free()
                spawned.remove_at(i)
        elif str(it["type"]) == "shield":
            if lane_match:
                shield_clock = 6.0 * (1.0+float(characters[selected].get("bonus_value",0.0)) if str(characters[selected].get("bonus_key","")) == "shield_duration" else 1.0)
                it["hit"] = true
                n.queue_free()
                spawned.remove_at(i)
        elif lane_match:
            var obstacle: int = int(it["ob"])
            var evaded := (obstacle==0 and jump_clock>0 and player_root.position.y>0.75) or (obstacle==1 and slide_clock>0)
            if not evaded:
                if str(characters[selected].get("bonus_key","")) == "dodge_chance" and randf() < float(characters[selected].get("bonus_value",0.0)):
                    it["hit"] = true
                    continue
                it["hit"] = true
                if shield_clock>0:
                    shield_clock=0
                else:
                    _game_over()
                    return

func _pick_coin() -> void:
    var perk: Dictionary = characters[selected]
    var amount := 100
    var key := str(perk.get("bonus_key",""))
    var b := float(perk.get("bonus_value",0.0))
    if key == "coin_mul":
        amount = int(round(100.0*(1.0+b)))
    elif key == "double_coin" and randf()<b:
        amount *= 2
    elif key == "coin_flat":
        amount += int(b)
    if key == "air_coins" and jump_clock > 0:
        amount = int(round(float(amount) * (1.0 + b)))
    if key == "streak_coins" and coin_streak > 2:
        amount = int(round(float(amount) * (1.0 + b)))
    coin_streak += 1
    streak_timer = 4.0
    run_coins += amount
    run_score += 20 * coin_streak

func _game_over() -> void:
    running = false
    paused = false
    coins += run_coins
    best = maxi(best,int(distance))
    _save()
    mode = "game_over"
    world_root.visible = false
    _clear_ui()
    _bg()
    _header("ЗАБЕГ ЗАВЕРШЁН")
    _panel(ui,307,190,665,388,"#15233a","#d19d62")
    _label(ui,"НОВЫЙ РЕЗУЛЬТАТ",353,213,570,70,35,"#ffdd99",true)
    _label(ui,"Дистанция: %d м" % int(distance),357,313,575,45,24,"#f0f5ff",true)
    _label(ui,"Монеты: +%s" % _money(run_coins),357,355,575,43,24,"#ffe09b",true)
    _label(ui,"Очки: %s" % _money(run_score),357,398,575,40,20,"#c8efef",true)
    _label(ui,"Лучший забег: %d м" % best,357,437,575,34,19,"#bcddf1",true)
    _button(ui,"Повторить",359,505,280,60,func(): _start_run(),true,20)
    _button(ui,"Главное меню",659,505,278,60,func(): _show_menu(),false,20)

func _input(event: InputEvent) -> void:
    var e := event as InputEventKey
    if e == null or not e.pressed or e.echo:
        return
    var key: int = e.keycode
    if mode == "run" and key == KEY_ESCAPE:
        _toggle_pause()
        get_viewport().set_input_as_handled()
        return
    if not running or paused:
        return
    if key == KEY_LEFT or key == KEY_A:
        lane = maxi(-1,lane-1)
    elif key == KEY_RIGHT or key == KEY_D:
        lane = mini(1,lane+1)
    elif key == KEY_UP or key == KEY_W or key == KEY_SPACE:
        if jump_clock <= 0 and slide_clock <= 0:
            var perk := characters[selected]
            var boost := float(perk.get("bonus_value",0.0)) if str(perk.get("bonus_key","")) == "jump_mul" else 0.0
            jump_clock = 0.75 * (1.0 + boost*0.4)
    elif key == KEY_DOWN or key == KEY_S:
        if jump_clock <= 0:
            slide_clock = 0.72 * (1.0 + float(characters[selected].get("bonus_value",0.0)) if str(characters[selected].get("bonus_key","")) == "slide_duration" else 1.0)
