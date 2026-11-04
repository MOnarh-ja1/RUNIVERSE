"""MgameIO Dark Account 1.4.1: permanently move prominent account card to upper left."""
from pathlib import Path

p=Path("/tmp/mgameio-launcher")
core=p/"core.go"
src=core.read_text(encoding="utf-8")
assert 'const launcherVersion = "1.4.0"' in src
core.write_text(src.replace('const launcherVersion = "1.4.0"','const launcherVersion = "1.4.1"',1),encoding="utf-8")

ui=p/"ui_windows.go"
s=ui.read_text(encoding="utf-8")
paint=s.index('func paint(hdc uintptr) {')
begin=s.index('\tfill(hdc, 0, 0, 252, h, cSide)',paint)
end=s.index('\tnav := []struct{ title, icon string }',begin)
s=s[:begin]+'''
\t// Always-visible upper-left account card, fully clickable on every page.
\tfill(hdc, 0, 0, 252, h, cSide)
\tactiveProfile := ui.page == 5
\tprofileCol := cText
\tcardBg := rgb(23, 42, 55)
\tif activeProfile {
\t\tprofileCol = cMint
\t\tcardBg = rgb(25, 65, 63)
\t}
\trounded(hdc, 10, 9, 232, 118, 18, cardBg)
\trounded(hdc, 24, 23, 57, 57, 26, rgb(42, 148, 131))
\ticon(hdc, "profile", 40, 39, rgb(244, 255, 250))
\ttextDraw(hdc, "МОЙ ПРОФИЛЬ", 93, 25, 136, 34, 17, 780, profileCol, 0)
\tui.account.mu.RLock()
\tprofileName := strings.TrimSpace(ui.account.player.DisplayName)
\tprofileLoggedIn := ui.account.token != ""
\tui.account.mu.RUnlock()
\tif !profileLoggedIn || profileName == "" {
\t\tprofileName = "Войти / Регистрация"
\t}
\ttextDraw(hdc, profileName, 93, 60, 136, 25, 12, 650, cMint, 0)
\tif profileLoggedIn {
\t\ttextDraw(hdc, "Аккаунт MgameIO", 25, 92, 196, 24, 11, 500, cMute, 0)
\t} else {
\t\ttextDraw(hdc, "Нажми, чтобы войти", 25, 92, 196, 24, 11, 500, cMute, 0)
\t}
\taddRegion(10, 9, 232, 118, "profile-nav", "")
\ttextDraw(hdc, "НАВИГАЦИЯ", 30, 145, 176, 22, 11, 700, rgb(102, 128, 151), 0)
'''+s[end:]
assert s.count('y := 166 + i*58')==1
s=s.replace('y := 166 + i*58','y := 179 + i*58',1)
assert s.count('case "profile-nav":')==1, "Clicking upper-left profile must navigate"
ui.write_text(s,encoding="utf-8")
(p/"README_RU.md").write_text(
 "# MgameIO Dark Account 1.4.1\n\n"
 "Мой профиль — крупная кликабельная карточка в самом левом верхнем углу на ВСЕХ вкладках.\n"
 "После входа показывает игровой ник, без входа — «Войти / Регистрация».\n"
 "Клик открывает полноценный профиль: регистрация, вход, изменение ника и пароля, выход.\n"
 "Google — в разработке; Google OAuth не запускается.\n"
 "Каталог RUNIVERSE (тестовая игра) 3.4.6, обновление и библиотека сохранены.\n"
 "Данные установки в %LOCALAPPDATA%\\MgameIO\\DarkLauncher.\n"
 "Исходный присланный Dark 1.3 EXE недоступен для побайтового редактирования; это собранная версия на основе прежнего лаунчера.\n",
 encoding="utf-8"
)
print("MgameIO Dark 1.4.1: account pinned to upper-left and clickable.")
