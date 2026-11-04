# Example HTTP client for Godot 4, NOT currently integrated into the classic EXE.
extends Node
class_name RUNIVERSEOnlineAPI
signal leaderboard_loaded(rows: Array)
signal profile_loaded(profile: Dictionary)
signal online_error(message: String)
@export var api_base: String = "https://YOUR-SERVER.example.com"
var session_token := ""

func get_profile() -> void:
    _request("GET", "/api/profile", {}, func(json): profile_loaded.emit(json))

func get_leaderboard() -> void:
    _request("GET", "/api/leaderboard", {}, func(json): leaderboard_loaded.emit(json.get("top", [])))

func submit_run(distance: int, coins: int, duration_ms: int) -> void:
    _request("POST", "/api/scores", {"distance": distance, "coins": coins, "duration_ms": duration_ms}, func(_json): get_profile())

func login_with_google_id_token(id_token: String) -> void:
    # A desktop OAuth browser/PKCE implementation must obtain id_token first.
    _request("POST", "/api/auth/google", {"id_token": id_token}, func(json):
        session_token = str(json.get("session_token", ""))
        profile_loaded.emit(json)
    )

func _request(method: String, endpoint: String, payload: Dictionary, done: Callable) -> void:
    var http := HTTPRequest.new()
    add_child(http)
    var headers := PackedStringArray(["Content-Type: application/json"])
    if not session_token.is_empty():
        headers.append("Authorization: Bearer " + session_token)
    http.request_completed.connect(func(result, status, _headers, body):
        http.queue_free()
        var json = JSON.parse_string(body.get_string_from_utf8())
        if result != HTTPRequest.RESULT_SUCCESS or status < 200 or status >= 300 or typeof(json) != TYPE_DICTIONARY:
            online_error.emit("Network or API error: " + str(status))
        else:
            done.call(json)
    )
    var data := "" if payload.is_empty() else JSON.stringify(payload)
    var action := HTTPClient.METHOD_GET if method == "GET" else HTTPClient.METHOD_POST
    var error := http.request(api_base + endpoint, headers, action, data)
    if error != OK:
        http.queue_free()
        online_error.emit("Failed to start request: " + str(error))
