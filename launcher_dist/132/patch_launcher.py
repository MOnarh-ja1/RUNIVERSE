"""MgameIO Launcher 1.3.2: disable unfinished Google UI, hide empty account statistics."""
from pathlib import Path
a=Path('account_windows.go')
s=a.read_text(encoding='utf-8')
pairs=[
 ('x, cw := baseHeader(hdc, "Мой профиль", "Аккаунт MgameIO — войти, зарегистрироваться или привязать Google")',
  'x, cw := baseHeader(hdc, "Мой профиль", "Аккаунт MgameIO — вход и регистрация по нику")'),
 ('player, token, best, runs, status := a.player, a.token, a.best, a.runs, a.status',
  'player, token, status := a.player, a.token, a.status'),
 ('button(hdc, x+30, 513, 330, 46, "Войти через Google", "google-login", "", false)\n\t\ttextDraw(hdc, "Google откроется в твоём браузере", x+380, 519, cw-414, 33, 13, 450, cMute, 0)',
  'textDraw(hdc, "Привязка Google — В РАЗРАБОТКЕ", x+30, 515, cw-60, 34, 17, 700, cMint, 0)\n\t\ttextDraw(hdc, "Для входа пока используй игровой ник и пароль", x+30, 551, cw-60, 29, 13, 450, cMute, 0)'),
 ('textDraw(hdc, fmt.Sprintf("Личный рекорд: %d м  •  Забегов: %d", best, runs), x+26, 237, cw-55, 34, 17, 650, cMint, 0)',
  'textDraw(hdc, "Данные забегов и рекорды хранятся в игре", x+26, 237, cw-55, 34, 16, 600, cMute, 0)'),
 ('button(hdc, x+299, 475, 300, 47, "Привязать Google", "google-login", "", false)',
  'textDraw(hdc, "Google — В РАЗРАБОТКЕ", x+299, 477, 304, 45, 15, 600, cMint, 0)'),
 ('textDraw(hdc, "Для следующего входа используй ник и пароль или Google.", x+32, 549, cw-65, 42, 13, 450, cMute, 0)',
  'textDraw(hdc, "Привязка Google пока недоступна. Вход — по нику и паролю.", x+32, 549, cw-65, 42, 13, 450, cMute, 0)')
]
for old,new in pairs:
 assert s.count(old)==1, ('missing account anchor',old)
 s=s.replace(old,new,1)
assert 'Личный рекорд:' not in s and 'Забегов:' not in s
assert '"google-login", "", false' not in s
a.write_text(s,encoding='utf-8')
p=Path('ui_windows.go')
s=p.read_text(encoding='utf-8')
old='case "google-login":\n\t\tgo ui.account.signInGoogle()'
assert s.count(old)==1
s=s.replace(old,'case "google-login":\n\t\tui.account.setStatus("Привязка Google — в разработке")',1)
p.write_text(s,encoding='utf-8')
Path('README_RU.md').write_text(
  '# MgameIO Launcher 1.3.2\n\n'
  'Google-привязка в разработке: недоступные кнопки заменены на надпись.\n'
  'Скрыта пустая статистика аккаунта (нулевой рекорд / забеги).\n'
  'Игровые сохранения и рекорды остаются локальными в RUNIVERSE.\n'
  'Вход и регистрация по игровому нику и паролю работают через сервер.\n'
  'Каталог обновлений RUNIVERSE сохранён.\n', encoding='utf-8'
)
print('MgameIO Launcher 1.3.2 patch applied')
