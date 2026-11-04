extends Control

const GAME_SCENE: = "res://main.tscn"
var bar: ProgressBar
var status: Label
var number: Label
var overlay: CanvasLayer
var elapsed: = 0.0
var loading: = false
var finishing: = false
var game: Node
var target: = 3.0

func _ready() -> void :
	_build_screen()
	await get_tree().process_frame
	await get_tree().process_frame
	var result: = ResourceLoader.load_threaded_request(GAME_SCENE)
	if result != OK:
		_fail("Не удалось начать загрузку игры.")
		return
	loading = true

func _label(text: String, size: int, pos: Vector2, extent: Vector2, color: Color) -> Label:
	var label: = Label.new()
	label.text = text
	label.position = pos
	label.size = extent
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _build_screen() -> void :
	overlay = CanvasLayer.new()
	overlay.layer = 100
	add_child(overlay)
	var bg: = ColorRect.new()
	bg.color = Color("09131f")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(bg)

	for i in range(7):
		var stripe: = ColorRect.new()
		stripe.color = Color(0.07, 0.2, 0.26, 0.34)
		stripe.position = Vector2(100 + i * 250, 0)
		stripe.size = Vector2(2, 941)
		stripe.rotation = 0.34
		bg.add_child(stripe)
	var logo: = TextureRect.new()
	logo.position = Vector2(746, 200)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.texture = load("res://assets/icon.svg")
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.size = Vector2(180, 180)
	bg.add_child(logo)
	bg.add_child(_label("RUNIVERSE", 76, Vector2(300, 405), Vector2(1072, 100), Color.WHITE))
	bg.add_child(_label("ПЯТЬ МИРОВ. ТВОЙ ПУТЬ.", 23, Vector2(300, 511), Vector2(1072, 44), Color("7bc7ce")))
	bar = ProgressBar.new()
	bar.position = Vector2(536, 635)
	bar.size = Vector2(600, 13)
	bar.show_percentage = false
	var track: = StyleBoxFlat.new()
	track.bg_color = Color("173443")
	track.set_corner_radius_all(7)
	bar.add_theme_stylebox_override("background", track)
	var fill: = StyleBoxFlat.new()
	fill.bg_color = Color("52e5ba")
	fill.set_corner_radius_all(7)
	bar.add_theme_stylebox_override("fill", fill)
	bg.add_child(bar)
	status = _label("Загружаем игру…", 23, Vector2(400, 670), Vector2(872, 44), Color("c7dde4"))
	bg.add_child(status)
	number = _label("0%", 19, Vector2(700, 720), Vector2(272, 32), Color("72a4b2"))
	bg.add_child(number)
	bg.add_child(_label("", 21, Vector2(250, 840), Vector2(1172, 40), Color("7294a2")))

func _process(delta: float) -> void :
	elapsed += delta
	if bar != null:
		bar.value = move_toward(bar.value, target, delta * 110.0)
		number.text = "%d%%" % int(bar.value)
	if loading:
		var progress: Array = []
		var state: = ResourceLoader.load_threaded_get_status(GAME_SCENE, progress)
		if not progress.is_empty():
			target = 5.0 + float(progress[0]) * 33.0
		if state == ResourceLoader.THREAD_LOAD_FAILED or state == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			loading = false
			_fail("Не удалось загрузить сцену игры.")
		elif state == ResourceLoader.THREAD_LOAD_LOADED:
			loading = false
			var packed: = ResourceLoader.load_threaded_get(GAME_SCENE) as PackedScene
			if packed == null or not packed.can_instantiate():
				_fail("Повреждена сцена игры.")
				return
			game = packed.instantiate()
			game.initialization_progress.connect(_progress)
			game.initialization_failed.connect(_fail)
			game.initialization_finished.connect(_complete)
			add_child(game)
	if elapsed > 60.0 and not finishing:
		_fail("Загрузка занимает слишком много времени. Перезапустите игру.")

func _progress(value: float, message: String) -> void :
	target = value
	status.text = message

func _complete() -> void :
	finishing = true
	target = 100.0
	status.text = "Всё готово. Вперёд!"
	await get_tree().create_timer(maxf(0.5, 1.5 - elapsed)).timeout
	if "--verify-startup" in OS.get_cmdline_user_args():
		if game.initialized and game.characters.size() == 50 and game.screens.has("menu") and game.portraits.size() == 50 and game.shop_texture.get_width() == 1672:
			print("RUNIVERSE STARTUP PASSED: boot, 50 heroes, exported menu/shop textures, menu")
			get_tree().quit(0)
		else:
			push_error("RUNIVERSE STARTUP FAILED")
			get_tree().quit(1)
		return
	var tween: = create_tween()
	tween.tween_property(overlay.get_child(0), "modulate:a", 0.0, 0.35)
	await tween.finished
	overlay.queue_free()
	set_process(false)

func _fail(message: String) -> void :
	finishing = true
	loading = false
	status.text = message
	status.add_theme_color_override("font_color", Color("ffa78a"))
	number.text = "Закройте окно и попробуйте запустить игру снова."
	number.position.x = 300
	number.size.x = 1072
	push_error(message)
	set_process(false)
	if "--verify-startup" in OS.get_cmdline_user_args():
		get_tree().quit(1)
