"""MgameIO Dark Account 1.4.0: use the original online profile and Dark Launcher data."""
from pathlib import Path
p=Path("/tmp/mgameio-launcher")
core=p/"core.go"
s=core.read_text(encoding="utf-8")
def replace_once(old,new):
 global s
 assert s.count(old)==1, ("core anchor",old[:90],s.count(old))
 s=s.replace(old,new,1)
replace_once('const launcherVersion = "1.3.0"','const launcherVersion = "1.4.0"')
for old,new in [
 ('filepath.Join(s, "MgameIO", "Launcher")','filepath.Join(s, "MgameIO", "DarkLauncher")'),
 ('filepath.Join(d, "MgameIO", "Launcher")','filepath.Join(d, "MgameIO", "DarkLauncher")'),
 ('filepath.Join(os.TempDir(), "MgameIO", "Launcher")','filepath.Join(os.TempDir(), "MgameIO", "DarkLauncher")')
]:
 replace_once(old,new)
start=s.index('func bundledCatalog() []Game {')
end=s.index('\nconst maxDownloadBytes', start)
s=s[:start]+'''func bundledCatalog() []Game {
    return []Game{{
        ID: "runiverse", Title: "RUNIVERSE (тестовая игра)", Version: "3.4.6",
        Description: "Тестовая игра MgameIO. Привязка Google в разработке.",
        URL: "https://github.com/MOnarh-ja1/RUNIVERSE/releases/download/v3.4.6/RUNIVERSE_346.exe",
        SHA256: "d4e20c1e6c5480627e6e8f65f3346b7c38f4bb3aab469ac0174668b0538b1f1c",
    }}
}
''' + s[end:]
core.write_text(s,encoding="utf-8")
u=p/"ui_windows.go"
s=u.read_text(encoding="utf-8")
for old,new in [
 ("MgameIO — Game Launcher","MgameIO Dark — Game Launcher"),
 ("MgameIO Launcher %s starting","MgameIO Dark Launcher %s starting"),
 ("MgameIO · GAME LAUNCHER","MgameIO Dark · GAME LAUNCHER"),
 ('"МЕНЮ", 32, 132','"MgameIO DARK", 32, 132'),
 ('{"Главная", "home"}, {"Игры", "games"}','{"Главная", "home"}, {"Каталог игр", "games"}'),
 ('baseHeader(hdc, "Игры", "Каталог игр MgameIO и загрузка по прямой ссылке.")',
  'baseHeader(hdc, "Каталог игр", "Каталог MgameIO — скачивай игры и обновления.")'),
 ('"Начни здесь", sx+19, y+22','"СКОРО РЕЛИЗ", sx+19, y+22'),
 ('"Добавь каталог или прямую ссылку на игру — и она появится в библиотеке."',
  '"Новая игра MgameIO в разработке. Обновляй каталог, чтобы не пропустить релиз."'),
 ("%LOCALAPPDATA%\\\\MgameIO\\\\Launcher\\\\launcher.log","%LOCALAPPDATA%\\\\MgameIO\\\\DarkLauncher\\\\launcher.log")
]:
 assert old in s, ("UI anchor",old)
 s=s.replace(old,new,1)
u.write_text(s,encoding="utf-8")
a=p/"account_windows.go"
s=a.read_text(encoding="utf-8")
s=s.replace("Онлайн-сервер ещё не настроен. Доступен локальный запуск игр.",
            "Войди по нику и паролю или зарегистрируй аккаунт MgameIO.")
assert '"google-login", "", false' not in s, "Google actions should already be disabled by 1.3.2 patch"
assert '"Регистрация"' in s or 'РЕГИСТРАЦИЯ' in s
a.write_text(s,encoding="utf-8")
t=p/"core_test.go"
s=t.read_text(encoding="utf-8")
assert s.count('Version: "3.4.1"')>=1
s=s.replace('Version: "3.4.1", URL: "https://example.org/3.4.1.exe"',
            'Version: "3.4.7", URL: "https://example.org/3.4.7.exe"')
s=s.replace('c[0].Version != "3.4.1"','c[0].Version != "3.4.7"')
s=s.replace('c[0].Version != "3.4.0"','c[0].Version != "3.4.6"')
s=s.replace('s.catalog[0].Version = "3.4"','s.catalog[0].Version = "3.4.7"')
t.write_text(s,encoding="utf-8")
t=p/"online_updates_108_test.go"
s=t.read_text(encoding="utf-8")
old='if games[0].LocalBundle == "" {'
assert old in s
s=s.replace(old,'if games[0].SHA256 != bundledCatalog()[0].SHA256 {')
t.write_text(s,encoding="utf-8")
t=p/"version_upgrade_107_test.go"
s=t.read_text(encoding="utf-8")
s=s.replace('g[0].Version != "3.4.0"','g[0].Version != "3.4.6"')
t.write_text(s,encoding="utf-8")
(p/"README_RU.md").write_text(
 "# MgameIO Dark Account 1.4.0\n"
 "Профиль точно по логике старого MgameIO Launcher: вход/регистрация по нику и паролю, "
 "смена ника и пароля, выход, общие серверные аккаунты.\n\n"
 "Привязка Google в разработке. Пустая статистика профиля скрыта.\n\n"
 "Вкладки: Главная, Каталог игр, Библиотека, Настройки, Мой профиль.\n"
 "RUNIVERSE (тестовая игра) v3.4.6. Онлайн-обновления с GitHub и SHA-256.\n"
 "Данные установки: %LOCALAPPDATA%\\\\MgameIO\\\\DarkLauncher.\n"
 "Исходный EXE Dark 1.3 не изменялся: сборка создана на базе исходников прежнего лаунчера "
 "с его полным профилем и тёмным интерфейсом.\n",
 encoding="utf-8"
)
print("Applied MgameIO Dark Account 1.4.0 profile and catalog patch.")
