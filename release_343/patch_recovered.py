"""Patch RUNIVERSE 3.4.2 recovered original to 3.4.3 online profiles."""
from pathlib import Path
import json
root=Path(__file__).resolve().parents[1]
a=root/"scripts/online_api.gd"
s=a.read_text(encoding="utf8").replace(" -> void :", " -> void:").replace(": =", ":=").replace("online_mode:=", "online_mode :=")
def once(old,new):
 global s
 if s.count(old)==0 and ":=" in old:
  alternative=old.replace(":=", ": =")
  if s.count(alternative)==1:old=alternative
 assert s.count(old)==1, ("online_api anchor",old[:90],s.count(old))
 s=s.replace(old,new,1)
once("signal online_error(message: String)","signal online_error(message: String)\nsignal config_loaded(google_available: bool)")
once("extends Node",'''extends Node
const CONFIG_URL := "https://raw.githubusercontent.com/MOnarh-ja1/RUNIVERSE/main/online/public_config.json"''')
once("func start_google_sign_in() -> void:",'''func refresh_runtime_config() -> void:
\tvar http := HTTPRequest.new()
\tadd_child(http)
\thttp.timeout = 15.0
\thttp.request_completed.connect(func(result: int, status: int, _headers: PackedStringArray, body: PackedByteArray):
\t\thttp.queue_free()
\t\tif result != HTTPRequest.RESULT_SUCCESS or status != 200:
\t\t\tconfig_loaded.emit(not google_client_id.is_empty())
\t\t\treturn
\t\tvar decoded: Variant = JSON.parse_string(body.get_string_from_utf8())
\t\tif not decoded is Dictionary:
\t\t\tconfig_loaded.emit(not google_client_id.is_empty())
\t\t\treturn
\t\tvar base: String = str(decoded.get("api_base", ""))
\t\tif base.begins_with("https://"):
\t\t\tapi_base = base.rstrip("/")
\t\tvar client_id: String = str(decoded.get("google_client_id", ""))
\t\tif client_id.ends_with(".apps.googleusercontent.com"):
\t\t\tgoogle_client_id = client_id
\t\tconfig_loaded.emit(not google_client_id.is_empty())
\t)
\tvar err := http.request(CONFIG_URL)
\tif err != OK:
\t\thttp.queue_free()
\t\tconfig_loaded.emit(not google_client_id.is_empty())

func password_access(nickname: String, password: String, register: bool) -> void:
\tif nickname.strip_edges().is_empty() or password.is_empty():
\t\tonline_error.emit("Введи игровой ник и пароль")
\t\treturn
\tvar endpoint := "/api/register" if register else "/api/login"
\t_request("POST", endpoint, {"nickname": nickname.strip_edges(), "password": password}, func(data: Dictionary):
\t\tsession_token = str(data.get("session_token", ""))
\t\tif session_token.is_empty():
\t\t\tonline_error.emit("Сервер не выдал сессию")
\t\telse:
\t\t\tget_profile()
\t)

func sign_out() -> void:
\tif not session_token.is_empty():
\t\t_request("POST", "/api/logout", {}, func(_obj: Dictionary): pass)
\tsession_token = ""

func start_google_sign_in() -> void:''')
once('online_error.emit("Настройте Google OAuth и HTTPS сервер")','refresh_runtime_config()\n\t\tonline_error.emit("Google-вход пока не настроен. Нужен Client ID Google Cloud.")')
a.write_text(s,encoding="utf8")

a=root/"scripts/game.gd"
s=a.read_text(encoding="utf8").replace(" -> void :", " -> void:").replace(": =", ":=").replace("online_mode:=", "online_mode :=")
def replace(old,new):
 global s
 if s.count(old)!=1:
  print("RECOVERED_GAME_MATCH_DEBUG",old[:100],repr([line for line in s.splitlines() if any(k in line for k in ("online_mode","online_api","_build_online_screen","online_profile","_open_top"))][:65]))
 assert s.count(old)==1,("game anchor",old[:90],s.count(old))
 s=s.replace(old,new,1)
replace('var online_mode := "top"','''var online_mode := "top"
var online_nick_input: LineEdit
var online_password_input: LineEdit
var online_signin_button: Button
var online_signup_button: Button
var online_logout_button: Button''')
replace('online_api.online_error.connect(_online_error)','''online_api.online_error.connect(_online_error)
\tonline_api.config_loaded.connect(_online_config_loaded)
\tonline_api.refresh_runtime_config()''')
replace('\t_action_button(screen, "НАЗАД", Rect2(1085, 716, 320, 82), Callable(self, "_leave"), false, 24)','''\tonline_nick_input = LineEdit.new()
\tonline_nick_input.placeholder_text = "Игровой ник"
\tonline_nick_input.position = Vector2(270, 385)
\tonline_nick_input.size = Vector2(490, 55)
\tonline_nick_input.add_theme_font_size_override("font_size", 23)
\tscreen.add_child(online_nick_input)
\tonline_password_input = LineEdit.new()
\tonline_password_input.placeholder_text = "Пароль (от 8 символов)"
\tonline_password_input.secret = true
\tonline_password_input.position = Vector2(270, 454)
\tonline_password_input.size = Vector2(490, 55)
\tonline_password_input.add_theme_font_size_override("font_size", 23)
\tscreen.add_child(online_password_input)
\tonline_signin_button = _action_button(screen, "ВОЙТИ", Rect2(785, 385, 290, 56), Callable(self, "_online_sign_in"), false, 21)
\tonline_signup_button = _action_button(screen, "РЕГИСТРАЦИЯ", Rect2(785, 454, 290, 56), Callable(self, "_online_sign_up"), true, 21)
\tonline_logout_button = _action_button(screen, "ВЫЙТИ ИЗ АККАУНТА", Rect2(270, 552, 360, 57), Callable(self, "_online_sign_out"), false, 20)
\t_action_button(screen, "НАЗАД", Rect2(1085, 716, 320, 82), Callable(self, "_leave"), false, 24)''')
replace('\tonline_refresh_button.visible = true\n\t_show("online")','\tonline_refresh_button.visible = true\n\t_online_inputs_visible(false)\n\t_show("online")')
replace('\tonline_refresh_button.visible = false\n\tonline_profile.text =','\tonline_refresh_button.visible = false\n\t_online_inputs_visible(true)\n\tonline_profile.text =')
replace('online_status.text = "Вход Google станет доступен после подключения онлайн-сервера"','online_status.text = "Войди по игровому нику и паролю. Для Google нужен OAuth Client ID"')
replace('online_status.text = "Нажми «Привязать Google», чтобы войти в свой аккаунт"','online_status.text = "Выбери: войти по нику, зарегистрироваться или через Google"')
replace('func _login_google() -> void:', '''func _online_inputs_visible(is_profile: bool) -> void:
\tvar is_guest: bool = online_api == null or online_api.session_token.is_empty()
\tonline_nick_input.visible = is_profile and is_guest
\tonline_password_input.visible = is_profile and is_guest
\tonline_signin_button.visible = is_profile and is_guest
\tonline_signup_button.visible = is_profile and is_guest
\tonline_logout_button.visible = is_profile and not is_guest

func _online_sign_in() -> void:
\tonline_status.text = "Входим в аккаунт..."
\tonline_api.password_access(online_nick_input.text, online_password_input.text, false)

func _online_sign_up() -> void:
\tonline_status.text = "Создаём аккаунт..."
\tonline_api.password_access(online_nick_input.text, online_password_input.text, true)

func _online_sign_out() -> void:
\tonline_api.sign_out()
\tonline_password_input.text = ""
\t_online_inputs_visible(true)
\tonline_profile.text = "Гость • Личный рекорд: %d м" % high_score
\tonline_status.text = "Ты вышел из аккаунта"

func _online_config_loaded(google_available: bool) -> void:
\tif online_mode == "profile" and online_api.session_token.is_empty():
\t\tonline_status.text = "Google-вход готов. Открой браузер кнопкой ниже" if google_available else "Вход по нику работает. Для Google нужен OAuth Client ID"

func _login_google() -> void:''')
replace('online_profile.text = "%s  •  Личный рекорд: %d м" % [str(player.get("display_name", "Игрок")), int(profile.get("best_distance", 0))]', '''online_profile.text = "%s  •  Личный рекорд: %d м" % [str(player.get("display_name", "Игрок")), int(profile.get("best_distance", 0))]
\t_online_inputs_visible(true)
\tonline_password_input.text = ""
\tonline_status.text = "Аккаунт подключён"''')
a.write_text(s,encoding="utf8")
(root/"online_config.json").write_text(json.dumps({"api_base":"https://runiverse-accounts-api.onrender.com","google_client_id":""},ensure_ascii=False,indent=2)+"\n",encoding="utf8")
(root/"VERSION.txt").write_text("3.4.3-preview\n",encoding="utf8")
print("PATCHED RUNIVERSE 3.4.3: shared HTTPS, live Google config, nickname login and registration.")
