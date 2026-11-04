extends Node3D



var rig: Node3D
var head_rig: Node3D
var left_leg: Node3D
var right_leg: Node3D
var left_arm: Node3D
var right_arm: Node3D
var scarf: Node3D
var clock: float = 0.0
var outfit: = Color("db5642")
var accent: = Color("ffce67")
var skin: = Color("f1c59e")
var look: = "runner"
var hero_index: = -1

func _mat(c: Color, metal: float = 0.0, glow: bool = false) -> StandardMaterial3D:
	var m: = StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = 0.48
	if glow:
		m.emission_enabled = true
		m.emission = c * 0.36
	return m

func _part(parent: Node3D, tag: String, shape: String, size: Vector3, at: Vector3, c: Color, metal: float = 0.0) -> MeshInstance3D:
	var p: = MeshInstance3D.new()
	p.name = tag
	var mesh: PrimitiveMesh
	match shape:
		"orb":
			var s: = SphereMesh.new()
			s.radius = 0.5
			s.height = 1.0
			s.radial_segments = 16
			s.rings = 8
			mesh = s
		"cone":
			var cone: = CylinderMesh.new()
			cone.top_radius = 0.02
			cone.bottom_radius = 0.5
			cone.height = 1.0
			mesh = cone
		"cylinder":
			var cylinder: = CylinderMesh.new()
			cylinder.top_radius = 0.5
			cylinder.bottom_radius = 0.5
			cylinder.height = 1.0
			mesh = cylinder
		_:
			mesh = BoxMesh.new()
	p.mesh = mesh
	p.material_override = _mat(c, metal)
	p.position = at
	p.scale = size
	parent.add_child(p)
	return p

func apply_character(hero: Dictionary) -> void :
	hero_index = int(hero.get("id", -1))
	look = String(hero.get("look", "runner"))
	outfit = Color(String(hero.get("color", "db5642")))
	accent = Color.from_hsv(fposmod(float(hero_index + 4) * 0.129, 1.0), 0.55, 0.99)
	skin = Color("e8b793")
	if look in ["robot", "droid", "mecha", "cyborg", "astronaut", "racer"]:
		skin = Color("a8cad5")
	if look in ["wolf", "panda", "cat", "dragon", "slime"]:
		skin = outfit.lightened(0.2)
	_rebuild()

func _ready() -> void :
	if rig == null:
		apply_character({"id": -1, "look": "runner", "color": "db5642"})

func _rebuild() -> void :
	for n in get_children():
		remove_child(n)
		n.queue_free()
	rig = Node3D.new()
	rig.name = "AnimatedRig"
	add_child(rig)
	var pants: = outfit.darkened(0.49)
	var boots: = Color("2e3344")
	var hair: = Color("583931") if hero_index % 3 != 0 else Color("302f36")
	if hero_index % 4 == 0:
		hair = Color("e4b261")

	_part(rig, "Tunic", "box", Vector3(0.89, 1.04, 0.54), Vector3(0, 1.51, 0), outfit)
	_part(rig, "ChestDetail", "box", Vector3(0.29, 0.73, 0.565), Vector3(0, 1.55, 0.01), accent)
	_part(rig, "Belt", "box", Vector3(1.01, 0.16, 0.59), Vector3(0, 1.08, 0), pants)
	_part(rig, "Buckle", "box", Vector3(0.22, 0.18, 0.64), Vector3(0, 1.08, 0), Color("ffd878"), 0.5)
	_part(rig, "Backpack", "box", Vector3(0.65, 0.67, 0.32), Vector3(0, 1.46, - 0.44), pants.lightened(0.25))
	_part(rig, "PackStripe", "box", Vector3(0.72, 0.13, 0.4), Vector3(0, 1.73, - 0.42), accent)

	head_rig = Node3D.new()
	head_rig.name = "HeadLookPivot"
	head_rig.position = Vector3(0, 2.18, 0.04)
	rig.add_child(head_rig)
	_part(head_rig, "Face", "orb", Vector3(0.85, 0.95, 0.79), Vector3(0, 0.24, 0.05), skin)
	_part(head_rig, "HairCap", "orb", Vector3(0.9, 0.33, 0.83), Vector3(0, 0.69, - 0.015), hair)
	_part(head_rig, "Tuft", "orb", Vector3(0.35, 0.22, 0.31), Vector3( - 0.2, 0.69, 0.32), hair)
	for x in [ - 0.19, 0.19]:
		_part(head_rig, "Eye", "orb", Vector3(0.12, 0.15, 0.07), Vector3(x, 0.27, 0.445), Color("26344a"))
		_part(head_rig, "Brow", "box", Vector3(0.19, 0.045, 0.04), Vector3(x, 0.43, 0.432), hair)
	_part(head_rig, "Smile", "box", Vector3(0.25, 0.045, 0.055), Vector3(0, 0.06, 0.455), Color("87544d"))
	for is_left in [true, false]:
		var sign_x: = -1.0 if is_left else 1.0
		var leg: = Node3D.new()
		leg.position = Vector3(0.27 * sign_x, 1.02, 0)
		rig.add_child(leg)
		_part(leg, "PantLeg", "box", Vector3(0.37, 0.78, 0.41), Vector3(0, - 0.42, 0), pants)
		_part(leg, "Shoe", "box", Vector3(0.43, 0.25, 0.62), Vector3(0, - 0.85, 0.13), boots)
		_part(leg, "ShoeStripe", "box", Vector3(0.43, 0.06, 0.66), Vector3(0, - 0.95, 0.15), Color("e8eced"))
		if is_left:
			left_leg = leg
		else:
			right_leg = leg
		var arm: = Node3D.new()
		arm.position = Vector3(0.6 * sign_x, 1.97, 0)
		rig.add_child(arm)
		_part(arm, "Sleeve", "box", Vector3(0.35, 0.75, 0.42), Vector3(0, - 0.42, 0), outfit.darkened(0.11))
		_part(arm, "Glove", "orb", Vector3(0.36, 0.35, 0.37), Vector3(0, - 0.88, 0.03), skin)
		_part(arm, "Cuff", "box", Vector3(0.38, 0.13, 0.43), Vector3(0, - 0.77, 0.02), accent)
		if is_left:
			left_arm = arm
		else:
			right_arm = arm
	scarf = Node3D.new()
	rig.add_child(scarf)
	_part(scarf, "Scarf", "box", Vector3(0.93, 0.17, 0.53), Vector3(0, 2.06, - 0.02), accent)
	_part(scarf, "ScarfTail", "box", Vector3(0.16, 0.58, 0.14), Vector3(0.43, 1.77, - 0.24), accent)
	_add_signature_details()

func _add_signature_details() -> void :

	match look:
		"knight", "samurai", "gladiator", "valkyrie", "mecha", "viking":
			_part(head_rig, "Helmet", "orb", Vector3(1.02, 0.55, 0.94), Vector3(0, 0.68, 0), accent, 0.6)
			_part(head_rig, "Crest", "cone", Vector3(0.32, 0.62, 0.35), Vector3(0, 1.07, - 0.01), outfit)
			for x in [ - 0.79, 0.79]:
				_part(rig, "ShoulderPad", "orb", Vector3(0.51, 0.37, 0.62), Vector3(x, 1.92, - 0.01), accent, 0.5)
		"witch", "ice_mage", "fire_mage", "shaman", "demon", "druid":
			_part(head_rig, "HatBase", "cylinder", Vector3(1.41, 0.13, 1.41), Vector3(0, 0.75, - 0.05), outfit.darkened(0.22))
			_part(head_rig, "TallHat", "cone", Vector3(0.85, 0.9, 0.85), Vector3(0, 1.22, - 0.07), outfit)
			_part(rig, "MagicGem", "orb", Vector3(0.25, 0.26, 0.25), Vector3(0, 1.62, 0.32), accent, 0.6)
		"astronaut", "racer", "pilot", "aviator":
			_part(head_rig, "Helmet", "orb", Vector3(1.13, 1.21, 1.01), Vector3(0, 0.29, 0), Color("f0f1e9"), 0.45)
			_part(head_rig, "Visor", "box", Vector3(0.79, 0.35, 0.08), Vector3(0, 0.34, 0.56), Color("276c93"), 0.5)
		"robot", "droid", "cyborg":
			_part(head_rig, "Screen", "box", Vector3(0.8, 0.41, 0.12), Vector3(0, 0.34, 0.45), Color("263849"), 0.5)
			for x in [ - 0.18, 0.18]:
				_part(head_rig, "EyeLED", "orb", Vector3(0.14, 0.15, 0.09), Vector3(x, 0.34, 0.53), Color("5cf3ff"))
			_part(head_rig, "Antenna", "cylinder", Vector3(0.08, 0.4, 0.08), Vector3(0, 1.03, 0), accent)
		"pirate", "captain", "cowboy", "explorer", "archaeologist":
			_part(head_rig, "HatBrim", "cylinder", Vector3(1.42, 0.13, 1.22), Vector3(0, 0.79, 0), Color("5a3f30"))
			_part(head_rig, "HatCrown", "cylinder", Vector3(0.86, 0.58, 0.76), Vector3(0, 1.06, 0), Color("765035"))
		"elf", "fairy", "angel":
			for x in [ - 0.53, 0.53]:
				_part(head_rig, "PointEar", "cone", Vector3(0.27, 0.44, 0.25), Vector3(x, 0.42, 0.03), skin)
			for x in [ - 0.65, 0.65]:
				var wing: = _part(rig, "Wing", "orb", Vector3(0.9, 1.5, 0.2), Vector3(x, 1.68, - 0.55), accent.lightened(0.2))
				wing.rotation.z = x * 0.48
		"ninja", "assassin", "hunter", "desert", "monk", "parkour":
			_part(head_rig, "Mask", "box", Vector3(0.82, 0.3, 0.18), Vector3(0, 0.08, 0.42), outfit.darkened(0.4))
			_part(head_rig, "Hood", "orb", Vector3(1.0, 0.45, 0.88), Vector3(0, 0.67, - 0.1), outfit)
		"wolf", "cat", "kitsune", "panda":
			for x in [ - 0.38, 0.38]:
				_part(head_rig, "AnimalEar", "cone", Vector3(0.37, 0.57, 0.32), Vector3(x, 0.96, - 0.02), skin)
			_part(rig, "Tail", "orb", Vector3(0.35, 0.66, 0.32), Vector3(0.3, 1.07, - 0.58), skin)
		"dragon":
			for x in [ - 0.45, 0.45]:
				_part(head_rig, "Horn", "cone", Vector3(0.33, 0.56, 0.31), Vector3(x, 1.02, - 0.04), accent)
			for x in [ - 0.63, 0.63]:
				_part(rig, "DragonWing", "box", Vector3(0.85, 0.96, 0.09), Vector3(x, 1.59, - 0.45), outfit.lightened(0.25))
		"slime":
			_part(head_rig, "SlimeCap", "orb", Vector3(1.18, 0.8, 1.08), Vector3(0, 0.55, - 0.04), Color("9fea74"))
		"scientist", "engineer":
			_part(head_rig, "Goggles", "box", Vector3(0.92, 0.17, 0.17), Vector3(0, 0.52, 0.43), Color("86dfff"), 0.45)
			_part(rig, "JacketStripe", "box", Vector3(0.86, 0.18, 0.09), Vector3(0, 1.4, 0.3), Color("e3ece8"))
		"cyber", "pilot":
			_part(head_rig, "TechVisor", "box", Vector3(0.84, 0.22, 0.12), Vector3(0, 0.4, 0.45), Color("4cf6ef"), 0.5)
		"vampire":
			_part(rig, "Cape", "box", Vector3(1.24, 1.42, 0.14), Vector3(0, 1.38, - 0.39), Color("58385c"))
		_:
			pass

	var emblem_color: = Color.from_hsv(fposmod(float(hero_index + 23) * 0.067, 1.0), 0.75, 0.99)
	_part(rig, "SignatureBadge", "orb", Vector3(0.18 + float(hero_index % 3) * 0.03, 0.18, 0.11), Vector3( - 0.19, 1.68, 0.3), emblem_color, 0.45)

func animate(delta: float, is_running: bool, is_sliding: bool, jumping: bool, speed_level: float, turn: float) -> void :
	clock += delta * (12.0 + speed_level * 4.6 if is_running else 2.0)
	var smooth: = minf(1.0, delta * 12.0)
	var stride: = 0.79 if is_running else 0.05
	if jumping:
		stride = 0.14
	if is_sliding:
		stride = 0.05
	var wave: = sin(clock)
	left_leg.rotation.x = lerpf(left_leg.rotation.x, wave * stride + (1.3 if is_sliding else 0.0), smooth)
	right_leg.rotation.x = lerpf(right_leg.rotation.x, - wave * stride + (1.3 if is_sliding else 0.0), smooth)
	left_arm.rotation.x = lerpf(left_arm.rotation.x, - wave * stride * 0.88 + ( - 0.55 if jumping else 0.0), smooth)
	right_arm.rotation.x = lerpf(right_arm.rotation.x, wave * stride * 0.88 + ( - 0.55 if jumping else 0.0), smooth)
	rig.scale.y = lerpf(rig.scale.y, 0.67 if is_sliding else 1.0, minf(1.0, delta * 17.0))
	rig.position.y = lerpf(rig.position.y, 0.24 if is_sliding else (0.06 * absf(wave) if is_running and not jumping else 0.0), smooth)
	rig.rotation.x = lerpf(rig.rotation.x, - 0.7 if is_sliding else (0.12 if is_running else 0.0), smooth)
	rig.rotation.z = lerpf(rig.rotation.z, - turn * 0.29 + wave * 0.025, smooth)
	head_rig.rotation.y = lerpf(head_rig.rotation.y, turn * 1.2, minf(1.0, delta * 10.0))
	scarf.rotation.x = sin(clock * 0.6) * 0.12
