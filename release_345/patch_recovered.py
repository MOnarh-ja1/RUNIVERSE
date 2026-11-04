"""RUNIVERSE 3.4.5: Google linking in development, hide unsynced account stats."""
from pathlib import Path
import re
root=Path(__file__).resolve().parents[1]
p=root/'scripts/game.gd'
s=p.read_text(encoding='utf8')
def once(old,new):
 global s
 assert s.count(old)==1, (old[:100],s.count(old))
 s=s.replace(old,new,1)
once('"ПРИВЯЗАТЬ GOOGLE"','"GOOGLE — В РАЗРАБОТКЕ"')
pattern=r'(?m)^(\s*online_login_button\s*=\s*_action_button\(screen,\s*"GOOGLE — В РАЗРАБОТКЕ"[^\n]*\))$'
s,n=re.subn(pattern,lambda m:m.group(1)+'\n\tonline_login_button.disabled = true',s)
assert n==1,('google button',n)
lines=s.splitlines(keepends=True)
guest_count=0
profile_count=0
for i,line in enumerate(lines):
 if 'online_profile.text' in line and ('Личный рекорд' in line or 'Забегов:' in line):
  prefix=line[:len(line)-len(line.lstrip(' \t'))]
  if 'Гость' in line:
   lines[i]=prefix+'online_profile.text = "Гость"\n'
   guest_count+=1
  else:
   lines[i]=prefix+'online_profile.text = str(player.get("display_name", "Игрок"))\n'
   profile_count+=1
assert guest_count==2,('guest profile',guest_count)
assert profile_count==1,('account profile',profile_count)
s=''.join(lines)
start=s.index('func _open_profile()')
end=s.index('func _open_online()',start)
s=s[:start]+'''func _open_profile() -> void:
\tonline_mode = "profile"
\tonline_title.text = "👤 МОЙ ПРОФИЛЬ"
\tonline_profile.visible = true
\tonline_rows.visible = false
\tonline_login_button.visible = true
\tonline_refresh_button.visible = false
\t_online_inputs_visible(true)
\tonline_profile.text = "Гость"
\t_show("online")
\tonline_status.text = "Привязка Google — в разработке. Вход по нику и паролю доступен."
\tif online_api != null and not online_api.session_token.is_empty():
\t\tonline_api.get_profile()

'''+s[end:]
start=s.index('func _online_config_loaded(')
end=s.index('func _login_google()',start)
s=s[:start]+'''func _online_config_loaded(_google_available: bool) -> void:
\tif online_mode == "profile" and online_api.session_token.is_empty():
\t\tonline_status.text = "Привязка Google — в разработке. Вход по нику и паролю доступен."

'''+s[end:]
start=s.index('func _login_google()')
end=s.index('func _online_error(',start)
s=s[:start]+'''func _login_google() -> void:
\tonline_status.text = "Привязка Google — в разработке"

'''+s[end:]
once('"Аккаунт подключён"','"Аккаунт подключён. Google-привязка в разработке. Прогресс пока локальный."')
assert 'start_google_sign_in()' not in s
assert 'Личный рекорд:' not in s[s.index('func _open_profile()'):]
p.write_text(s,encoding='utf8')
(root/'VERSION.txt').write_text('3.4.5-google-wip-and-clean-profile\n',encoding='utf8')
print('RUNIVERSE 3.4.5 patch applied')
