extends SceneTree

func _initialize() -> void:
    call_deferred("_check")

func _check() -> void:
    var game := (load("res://main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    await game.initialization_finished
    var avatar: Node3D = game.get("avatar")
    var characters: Array = game.get("characters")
    for i in range(15):
        avatar.apply_character(characters[i])
        if not avatar.uses_cartoon:
            push_error("MODEL %d missing" % i)
            quit(1)
            return
        var body: Node3D = avatar.cartoon_body
        if absf(body.rotation.x + PI / 2.0) > 0.001:
            push_error("MODEL %d is not Y-up" % i)
            quit(1)
            return
        for side in ["L", "R"]:
            var arm: Node3D = avatar.cartoon_limbs["arm_" + side]
            var leg: Node3D = avatar.cartoon_limbs["leg_" + side]
            if absf(arm.position.z - 1.62) > 0.001 or absf(leg.position.z - 0.91) > 0.001:
                push_error("MODEL %d limb pivots are not Z-up" % i)
                quit(1)
                return
        avatar.animate(0.016, true, false, false, 1.0, 0.0)
    print("ORIENTATION TEST PASSED: all 15 GLBs upright, pivots and running")
    quit(0)
