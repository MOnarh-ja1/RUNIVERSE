from pathlib import Path
import re
root=Path(__file__).resolve().parents[1]
p=root/'scripts/online_api.gd'
s=p.read_text('utf-8')
s,n=re.subn(r'(?m)^const REDIRECT\s*:?\s*=.*$', 'var redirect_uri := ""\nvar oauth_buffer := ""',s)
assert n==1,('redirect',n)
s=s.replace('callback_server.listen(PORT, "127.0.0.1")','callback_server.listen(0, "127.0.0.1")')
s=s.replace('var crypto := Crypto.new()', 'redirect_uri = "http://127.0.0.1:%d/callback" % callback_server.get_local_port()\n\tvar crypto := Crypto.new()',1)
s=s.replace('REDIRECT.uri_encode()','redirect_uri.uri_encode()')
s=s.replace('oauth_started_ms = Time.get_ticks_msec()','oauth_started_ms = Time.get_ticks_msec()\n\tpending_client = null\n\toauth_buffer = ""',1)
s=s.replace('pending_client = callback_server.take_connection()', 'pending_client = callback_server.take_connection()\n\t\toauth_buffer = ""')
s=s.replace('if pending_client != null and pending_client.get_available_bytes() > 0:','if pending_client != null:\n\t\tpending_client.poll()\n\tif pending_client != null and pending_client.get_available_bytes() > 0:')
s=s.replace('var message := pending_client.get_utf8_string(mini(pending_client.get_available_bytes(), 8192))','oauth_buffer += pending_client.get_utf8_string(mini(pending_client.get_available_bytes(), 8192))\n\t\tif oauth_buffer.length() > 8192 or not oauth_buffer.contains("\\r\\n"):\n\t\t\treturn\n\t\tvar message := oauth_buffer')
s=s.replace('var answer := "Вход завершён, вернитесь в RUNIVERSE." if ok else "Не удалось подтвердить вход."','var answer := "Google подтвердил вход. Дождись результата в RUNIVERSE." if ok else "Не удалось подтвердить вход."')
s=s.replace('pending_client.disconnect_from_host()\n\t\tpending_client = null','pending_client.disconnect_from_host()\n\t\tpending_client = null\n\t\toauth_buffer = ""')
s=s.replace('if not ok:\n\t\t\tonline_error.emit("Google не вернул действительный код входа")\n\t\telse:\n\t\t\t_exchange_code(String(parameters["code"]))', 'if not ok:\n\t\t\tonline_error.emit("Google не вернул действительный код входа")\n\t\telse:\n\t\t\tonline_error.emit("Google подтвердил вход. Создаём игровую сессию...")\n\t\t\t_exchange_code(String(parameters["code"]))')
a=s.index('func _exchange_code(');b=s.index('func get_profile(',a)
s=s[:a]+'''func _exchange_code(code: String) -> void:
\t_request("POST", "/api/auth/google/code", {"code": code, "code_verifier": code_verifier, "redirect_uri": redirect_uri}, func(reply: Dictionary):
\t\tsession_token = str(reply.get("session_token", ""))
\t\tif session_token.is_empty():
\t\t\tonline_error.emit("Сервер не выдал сессию Google")
\t\telse:
\t\t\tget_profile()
\t)

'''+s[b:]
s=s.replace('var headers := PackedStringArray(["Content-Type: application/json"])','http.timeout = 90.0\n\tvar headers := PackedStringArray(["Content-Type: application/json"])')
s=s.replace('online_error.emit("Ошибка сервера: " + str(status))','online_error.emit("Сервер (%d): %s" % [status, str(obj.get("error", "")) if obj is Dictionary else "нет ответа"])')
s='\n'.join(('\t'*((len(line)-len(line.lstrip(' ')))//4)+line.lstrip(' ') if line.startswith(' ') and (len(line)-len(line.lstrip(' ')))%4==0 else line) for line in s.split('\n'))
assert s.count('func _exchange_code(')==1
p.write_text(s,encoding='utf-8')
(root/'VERSION.txt').write_text('3.4.4-google-fix\n')
print('RUNIVERSE 3.4.4 Google OAuth callback fix applied')
