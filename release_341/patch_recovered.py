"""Prepare RUNIVERSE 3.4.1 on top of the recovered 3.4.0 classic game.
Only patch the original game; never use the rewritten 3.3.0 sources.
"""
import pathlib,struct,json
root=pathlib.Path(__file__).resolve().parents[1]
model_root=root/'characters_cartoon15/models'
models=list(model_root.glob('*.glb'))
assert len(models)==15, f"Expected 15 models, got {len(models)}"
for p in models:
 b=p.read_bytes();magic,ver,_=struct.unpack_from('<4sII',b)
 assert magic==b'glTF' and ver==2
 n,t=struct.unpack_from('<I4s',b,12);assert t==b'JSON'
 j=json.loads(b[20:20+n]);offset=20+n
 chunks=[]
 while offset<len(b):
  cn,ct=struct.unpack_from('<I4s',b,offset)
  chunks.append((ct,b[offset+8:offset+8+cn]));offset+=8+cn
 hero_index=int(p.name[:2])
 palettes=[
  ('#ef7f26','#e6b18b','#543b34'),('#393043','#d0b3aa','#1d1526'),('#e88bbf','#f4cbaa','#d54ca2'),
  ('#315f9e','#eac5a1','#192944'),('#e9e6db','#f4eedb','#1d2631'),('#80b9d0','#a8d0df','#2b536c'),
  ('#a83d55','#e8bca0','#3d2639'),('#444b65','#e2b99f','#171b2b'),('#dcd9d0','#d7dee4','#4b84a9'),
  ('#5cb564','#9ddc7b','#2f6540'),('#e6e3d6','#f0e9d4','#494655'),('#e97c24','#ffbb65','#903321'),
  ('#7ad5ef','#d9f3ff','#3e7ca6'),('#52b888','#e3c7a8','#2f6257'),('#e1af58','#f4d7bb','#66513c')
 ]
 primary,skin,dark=palettes[hero_index]
 def rgba(hex_value):
  return [int(hex_value[i:i+2],16)/255.0 for i in (1,3,5)]+[1.0]
 def part_color(name):
  a=name.lower()
  if any(v in a for v in ('eye_white','glint','highlight')):return '#ffffff'
  if any(v in a for v in ('pupil','iris','eyebrow','hair','shoe','boot','mask','belt','goggle','visor')):return dark
  if any(v in a for v in ('skin','head','face','hand','nose','ear','wrist')):return skin
  if any(v in a for v in ('tip','buckle','badge','collar','emblem')):return '#f5cf6b'
  if 'eye' in a:return '#202c41'
  return primary
 mats=[]
 mesh_names={x['mesh']:x.get('name','') for x in j.get('nodes',[]) if 'mesh' in x}
 for index,mesh in enumerate(j['meshes']):
  part=mesh_names.get(index,mesh.get('name','body'))
  for primitive in mesh['primitives']:
   has_vertex_color='COLOR_0' in primitive['attributes']
   color=[1,1,1,1] if has_vertex_color else rgba(part_color(part))
   mat={'name':'Fixed_'+part,'pbrMetallicRoughness':{'baseColorFactor':color,'metallicFactor':0,'roughnessFactor':0.7},'doubleSided':True}
   primitive['material']=len(mats)
   mats.append(mat)
 j['materials']=mats
 raw=json.dumps(j,ensure_ascii=False,separators=(',',':')).encode()
 raw+=b' '*((-len(raw))%4)
 out=bytearray(b'glTF'+struct.pack('<II',2,0)+struct.pack('<I4s',len(raw),b'JSON')+raw)
 for ct,data in chunks:out.extend(struct.pack('<I4s',len(data),ct)+data)
 struct.pack_into('<I',out,8,len(out));p.write_bytes(out)
sfile=root/'scripts/game.gd'
s=sfile.read_text(encoding='utf-8')
def replace_once(before,after):
 global s
 assert s.count(before)==1,('expected exactly once',before[:90],s.count(before))
 s=s.replace(before,after)
replace_once('var online_profile: Label\n','var online_profile: Label\nvar online_title: Label\nvar online_login_button: Button\nvar online_refresh_button: Button\nvar online_mode := "top"\n')
replace_once('''\t_action_button(m, "НАСТРОЙКИ", Rect2(88, 568, 520, 78), Callable(self, "_open_settings"), false, 27)
\t_action_button(m, "🌐 ПРОФИЛЬ / ТОП", Rect2(665, 568, 470, 78), Callable(self, "_open_online"), false, 27)
\t_action_button(m, "ВЫХОД", Rect2(88, 668, 520, 78), Callable(get_tree(), "quit"), false, 27)
\tmenu_wallet_label = _balance(m)''','''\t_action_button(m, "НАСТРОЙКИ", Rect2(88, 568, 520, 78), Callable(self, "_open_settings"), false, 27)
\t_action_button(m, "🏆 ТОПЫ", Rect2(88, 668, 520, 78), Callable(self, "_open_top"), false, 27)
\t_action_button(m, "ВЫХОД", Rect2(88, 768, 520, 70), Callable(get_tree(), "quit"), false, 27)
\t_action_button(m, "👤 ПРОФИЛЬ", Rect2(1306, 44, 308, 65), Callable(self, "_open_profile"), true, 24)
\tmenu_wallet_label = _label(m, "", Vector2(1320, 129), Vector2(282, 55), 26, Color("ffdb84"))''')
replace_once('menu_record_label = _label(m, "", Vector2(88, 795), Vector2(600, 46), 24, Color("efcd8e"), false)','menu_record_label = _label(m, "", Vector2(645, 815), Vector2(333, 46), 22, Color("efcd8e"), false)')
replace_once('''\t_label(screen, "ПРОФИЛЬ И МИРОВОЙ ТОП", Vector2(262, 104), Vector2(1126, 72), 47)
\tonline_status = _label(screen, "Подключение не настроено", Vector2(265, 189), Vector2(1110, 66), 25)
\tonline_profile = _label(screen, "", Vector2(264, 281), Vector2(1090, 70), 26)
\tonline_rows = _label(screen, "", Vector2(265, 361), Vector2(1100, 330), 27, Color("e1f1fd"), false)
\tonline_rows.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
\t_action_button(screen, "ВОЙТИ ЧЕРЕЗ GOOGLE", Rect2(253, 716, 470, 82), Callable(self, "_login_google"), true, 24)
\t_action_button(screen, "ОБНОВИТЬ ТОП", Rect2(748, 716, 314, 82), Callable(self, "_refresh_online"), false, 24)
\t_action_button(screen, "НАЗАД", Rect2(1085, 716, 320, 82), Callable(self, "_leave"), false, 24)

func _open_online() -> void:
\t_show("online")
\t_refresh_online()
''','''\tonline_title = _label(screen, "МИРОВОЙ ТОП", Vector2(262, 104), Vector2(1126, 72), 47)
\tonline_status = _label(screen, "", Vector2(265, 189), Vector2(1110, 66), 25)
\tonline_profile = _label(screen, "", Vector2(264, 281), Vector2(1090, 70), 26)
\tonline_rows = _label(screen, "", Vector2(265, 361), Vector2(1100, 330), 27, Color("e1f1fd"), false)
\tonline_rows.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
\tonline_login_button = _action_button(screen, "ПРИВЯЗАТЬ GOOGLE", Rect2(253, 716, 470, 82), Callable(self, "_login_google"), true, 24)
\tonline_refresh_button = _action_button(screen, "ОБНОВИТЬ ТОП", Rect2(748, 716, 314, 82), Callable(self, "_refresh_online"), false, 24)
\t_action_button(screen, "НАЗАД", Rect2(1085, 716, 320, 82), Callable(self, "_leave"), false, 24)

func _open_top() -> void:
\tonline_mode = "top"
\tonline_title.text = "🏆 МИРОВОЙ ТОП"
\tonline_profile.visible = false
\tonline_rows.visible = true
\tonline_login_button.visible = false
\tonline_refresh_button.visible = true
\t_show("online")
\t_refresh_online()

func _open_profile() -> void:
\tonline_mode = "profile"
\tonline_title.text = "👤 МОЙ ПРОФИЛЬ"
\tonline_profile.visible = true
\tonline_rows.visible = false
\tonline_login_button.visible = true
\tonline_refresh_button.visible = false
\tonline_profile.text = "Гость  •  Личный рекорд: %d м" % high_score
\t_show("online")
\tif online_api != null and not online_api.session_token.is_empty():
\t\tonline_api.get_profile()
\telif online_api == null or online_api.api_base.is_empty() or online_api.google_client_id.is_empty():
\t\tonline_status.text = "Вход Google станет доступен после подключения онлайн-сервера"
\telse:
\t\tonline_status.text = "Нажми «Привязать Google», чтобы войти в свой аккаунт"

func _open_online() -> void:
\t_open_top()
''')
sfile.write_text(s,encoding='utf-8')
(root/'VERSION.txt').write_text('3.4.1-preview\n')
print('PATCH 3.4.1 OK: 15 materials, top-left menu and profile-right')
