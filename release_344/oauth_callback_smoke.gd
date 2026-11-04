extends SceneTree

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var online: Node = load("res://scripts/online_api.gd").new()
    root.add_child(online)
    var errors := []
    online.online_error.connect(func(msg: String): errors.append(msg))
    online.callback_server = TCPServer.new()
    if online.callback_server.listen(0, "127.0.0.1") != OK:
        push_error("OAuth loopback listener failed")
        quit(1)
        return
    var port: int = online.callback_server.get_local_port()
    online.oauth_state = "expected-state"
    online.oauth_started_ms = Time.get_ticks_msec()
    online.set_process(true)
    var sock := StreamPeerTCP.new()
    if sock.connect_to_host("127.0.0.1", port) != OK:
        push_error("OAuth callback connection failed")
        quit(1)
        return
    for i in range(120):
        sock.poll()
        if sock.get_status() == StreamPeerTCP.STATUS_CONNECTED:
            break
        await process_frame
    if sock.get_status() != StreamPeerTCP.STATUS_CONNECTED:
        push_error("OAuth callback TCP timeout")
        quit(1)
        return
    sock.put_data("GET /callback?code=example&state=wrong-state HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n".to_utf8_buffer())
    for i in range(150):
        await process_frame
        if errors.size() > 0:
            break
    if errors.is_empty() or not ("код входа" in errors[0]):
        push_error("Forged OAuth state not detected: " + str(errors))
        quit(1)
        return
    print("GOOGLE LOOPBACK SMOKE PASSED: callback read and OAuth state checked")
    quit(0)
