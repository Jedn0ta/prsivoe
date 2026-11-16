extends Control
## Prší – menu, table, controls, bots and Wi-Fi play.
## The host (or the local game) owns the Rules object; everybody renders from a "view".

const CW := 164.0
const CH := 249.0
const OW := 60.0
const OH := 91.0
const BOT_NAMES := ["Pepa", "Franta", "Jarda"]
const SAVE := "user://prsi.cfg"
const ACC := ["sedmu", "osmu", "devítku", "desítku", "spodka", "svrška", "krále", "eso"]

const TABLE_TEX: Texture2D = preload("res://img/table.jpg")
const BACK: Texture2D = preload("res://img/back.png")
const FONT: Font = preload("res://fonts/DejaVuSerif-Bold.ttf")
const SUIT_TEX := [
	preload("res://img/suit_srdce.png"), preload("res://img/suit_kule.png"),
	preload("res://img/suit_listy.png"), preload("res://img/suit_zaludy.png")]
const SND := {
	"slap": preload("res://snd/slap.wav"), "draw": preload("res://snd/draw.wav"),
	"shuffle": preload("res://snd/shuffle.wav"), "turn": preload("res://snd/turn.wav"),
	"win": preload("res://snd/win.wav"), "lose": preload("res://snd/lose.wav"),
	"bad": preload("res://snd/bad.wav")}

# ---------- game state ----------
var mode := ""            # "", "local", "host", "client"
var rules: Rules
var seats: Array = []     # [{kind:"me"|"bot"|"peer", peer:int, name:String}]
var round_id := 0
var scores := {}          # name -> wins
var lobby_peers := {}     # peer id -> name (host)
var add_bot := true
var view: Dictionary = {}
var shown_round := -1
var my_name := "Hráč"
var sound_on := true
var waiting_suit := false
var selected := -1
var bot_token := 0
var auto := {}            # test hooks

# ---------- nodes ----------
var bg: TextureRect
var table: Control
var opp_layer: Control
var cards_layer: Control
var fx_layer: Control
var ui_layer: Control
var deck_node: CardNode
var deck_under: Array = []
var deck_lbl: Label
var msg_panel: PanelContainer
var msg_lbl: Label
var suit_box: PanelContainer
var suit_icon: TextureRect
var hint_lbl: Label
var shout_lbl: Label
var menu_btn: Button
var hand_nodes := {}      # card -> CardNode
var hand_order: Array = []
var pile_nodes: Array = []
var screens := {}
var menu_score_lbl: Label
var name_edit: LineEdit
var lobby_info: Label
var lobby_players: Label
var lobby_start: Button
var finder_list: VBoxContainer
var finder_status: Label
var ip_edit: LineEdit
var overlay: Control
var players := {}


# =====================================================================
#  SETUP
# =====================================================================
func _ready() -> void:
	randomize()
	_load_cfg()
	_build_theme()
	bg = TextureRect.new()
	bg.texture = TABLE_TEX
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	table = _full(self)
	_build_table()
	screens["menu"] = _build_menu()
	screens["lobby"] = _build_lobby()
	screens["finder"] = _build_finder()
	ui_layer = _full(self)
	for k in SND:
		var p := AudioStreamPlayer.new()
		p.stream = SND[k]
		add_child(p)
		players[k] = p
	Net.tables_changed.connect(_refresh_finder)
	Net.joined_ok.connect(_on_joined)
	Net.join_failed.connect(func(): _finder_msg("Připojení se nepovedlo. Zkontroluj, že jste na stejné Wi-Fi."))
	Net.lost_server.connect(_on_lost_server)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	resized.connect(_relayout)
	_show("menu")
	_cmdline_hooks()


func _full(parent: Control) -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	return c


func _build_theme() -> void:
	var th := Theme.new()
	th.default_font = FONT
	th.default_font_size = 30
	var b := StyleBoxFlat.new()
	b.bg_color = Color("#dcae45")
	b.set_corner_radius_all(22)
	b.border_width_bottom = 6
	b.border_color = Color("#8d6418")
	b.content_margin_left = 30
	b.content_margin_right = 30
	b.content_margin_top = 16
	b.content_margin_bottom = 18
	b.shadow_color = Color(0, 0, 0, 0.45)
	b.shadow_size = 8
	b.shadow_offset = Vector2(0, 4)
	var bh: StyleBoxFlat = b.duplicate()
	bh.bg_color = Color("#efc463")
	var bp: StyleBoxFlat = b.duplicate()
	bp.bg_color = Color("#b98a2c")
	bp.border_width_bottom = 2
	var bd: StyleBoxFlat = b.duplicate()
	bd.bg_color = Color("#5d4e33")
	bd.border_color = Color("#3a3020")
	th.set_stylebox("normal", "Button", b)
	th.set_stylebox("hover", "Button", bh)
	th.set_stylebox("pressed", "Button", bp)
	th.set_stylebox("disabled", "Button", bd)
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		th.set_color(k, "Button", Color("#3a2300"))
	th.set_color("font_disabled_color", "Button", Color("#bfae8c"))
	th.set_font_size("font_size", "Button", 32)
	th.set_color("font_color", "Label", Color("#f6e7c1"))
	th.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.85))
	th.set_constant("outline_size", "Label", 7)
	var le := StyleBoxFlat.new()
	le.bg_color = Color(0.08, 0.05, 0.02, 0.85)
	le.border_color = Color("#c99632")
	le.set_border_width_all(2)
	le.set_corner_radius_all(14)
	le.content_margin_left = 18
	le.content_margin_right = 18
	le.content_margin_top = 12
	le.content_margin_bottom = 12
	th.set_stylebox("normal", "LineEdit", le)
	th.set_stylebox("focus", "LineEdit", le)
	th.set_color("font_color", "LineEdit", Color("#f6e7c1"))
	th.set_font_size("font_size", "LineEdit", 32)
	th.set_color("font_color", "CheckButton", Color("#f6e7c1"))
	th.set_color("font_hover_color", "CheckButton", Color("#ffffff"))
	th.set_color("font_pressed_color", "CheckButton", Color("#f6e7c1"))
	th.set_font_size("font_size", "CheckButton", 30)
	var pn := StyleBoxFlat.new()
	pn.bg_color = Color(0.13, 0.075, 0.035, 0.94)
	pn.border_color = Color("#c99632")
	pn.set_border_width_all(3)
	pn.set_corner_radius_all(28)
	pn.content_margin_left = 36
	pn.content_margin_right = 36
	pn.content_margin_top = 30
	pn.content_margin_bottom = 30
	pn.shadow_color = Color(0, 0, 0, 0.6)
	pn.shadow_size = 24
	th.set_stylebox("panel", "PanelContainer", pn)
	theme = th


func _lbl(text: String, fs: int = 30, col: Color = Color("#f6e7c1"), wrap_w: float = 0.0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if wrap_w > 0.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = wrap_w
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _btn(text: String, cb: Callable, fs: int = 32) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", fs)
	b.pressed.connect(func():
		_sfx("turn")
		cb.call())
	return b


func _screen_panel(min_w: float = 600.0) -> Array:
	var root := _full(self)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cc)
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(min_w, 0)
	cc.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 20)
	pc.add_child(v)
	return [root, v]


# =====================================================================
#  SCREENS
# =====================================================================
func _build_menu() -> Control:
	var a := _screen_panel()
	var v: VBoxContainer = a[1]
	var t := _lbl("PRŠÍ", 104, Color("#f3d48a"))
	t.add_theme_constant_override("outline_size", 14)
	v.add_child(t)
	v.add_child(_lbl("hospodská klasika s mariáškami", 26, Color("#e9d6a8")))
	var icons := HBoxContainer.new()
	icons.alignment = BoxContainer.ALIGNMENT_CENTER
	icons.add_theme_constant_override("separation", 18)
	for tx in SUIT_TEX:
		var r := TextureRect.new()
		r.texture = tx
		r.custom_minimum_size = Vector2(70, 70)
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icons.add_child(r)
	v.add_child(icons)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.add_child(_lbl("Jméno:", 30))
	name_edit = LineEdit.new()
	name_edit.text = my_name
	name_edit.max_length = 12
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text_changed.connect(func(t2: String):
		my_name = t2.strip_edges() if t2.strip_edges() != "" else "Hráč"
		_save_cfg())
	row.add_child(name_edit)
	v.add_child(row)
	v.add_child(_btn("Hrát s Pepou", func(): _start_local(1)))
	v.add_child(_btn("Hrát s Pepou a Frantou", func(): _start_local(2)))
	v.add_child(_btn("Založit stůl na Wi-Fi", _open_host))
	v.add_child(_btn("Připojit se ke stolu", _open_finder))
	var snd := CheckButton.new()
	snd.text = "Zvuky"
	snd.button_pressed = sound_on
	snd.alignment = HORIZONTAL_ALIGNMENT_CENTER
	for st in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		snd.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	snd.toggled.connect(func(on: bool):
		sound_on = on
		_save_cfg())
	v.add_child(snd)
	menu_score_lbl = _lbl("", 24, Color("#d8c393"), 520)
	v.add_child(menu_score_lbl)
	return a[0]


func _build_lobby() -> Control:
	var a := _screen_panel()
	var v: VBoxContainer = a[1]
	v.add_child(_lbl("Tvůj stůl", 56, Color("#f3d48a")))
	lobby_info = _lbl("", 26, Color("#e9d6a8"), 520)
	v.add_child(lobby_info)
	lobby_players = _lbl("", 30)
	v.add_child(lobby_players)
	var cb := CheckButton.new()
	cb.text = "Přisednout si Pepa (počítač)"
	cb.button_pressed = add_bot
	for st in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		cb.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	cb.toggled.connect(func(on: bool):
		add_bot = on
		_refresh_lobby())
	v.add_child(cb)
	lobby_start = _btn("Rozdat karty", _host_start_round)
	v.add_child(lobby_start)
	v.add_child(_btn("Zrušit stůl", _go_menu))
	return a[0]


func _build_finder() -> Control:
	var a := _screen_panel()
	var v: VBoxContainer = a[1]
	v.add_child(_lbl("Stoly na Wi-Fi", 56, Color("#f3d48a")))
	finder_status = _lbl("Hledám stoly ve stejné síti…", 26, Color("#e9d6a8"), 520)
	v.add_child(finder_status)
	finder_list = VBoxContainer.new()
	finder_list.add_theme_constant_override("separation", 12)
	v.add_child(finder_list)
	v.add_child(_lbl("Nenašlo se nic? Zadej IP hostitele:", 24, Color("#d8c393"), 520))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	ip_edit = LineEdit.new()
	ip_edit.placeholder_text = "192.168.1.23"
	ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ip_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER_DECIMAL
	row.add_child(ip_edit)
	row.add_child(_btn("Připojit", func(): _join(ip_edit.text), 28))
	v.add_child(row)
	v.add_child(_btn("Zpět", _go_menu))
	return a[0]


func _show(which: String) -> void:
	for k in screens:
		screens[k].visible = k == which
	table.visible = which == "table"
	if which == "table":
		_relayout()
	if which == "menu":
		_refresh_menu_score()


# =====================================================================
#  TABLE NODES
# =====================================================================
func _build_table() -> void:
	opp_layer = _full(table)
	cards_layer = _full(table)
	fx_layer = _full(table)
	for i in 3:
		var u := CardNode.new().setup(-1, false, Vector2(CW, CH))
		cards_layer.add_child(u)
		deck_under.append(u)
	deck_node = CardNode.new().setup(-1, false, Vector2(CW, CH))
	deck_node.set_interactive(false, true)
	deck_node.tapped.connect(func(_n): _on_deck_tapped())
	cards_layer.add_child(deck_node)
	deck_lbl = _lbl("", 26)
	deck_lbl.size = Vector2(240, 40)
	table.add_child(deck_lbl)

	msg_panel = PanelContainer.new()
	var ms := StyleBoxFlat.new()
	ms.bg_color = Color(0.1, 0.05, 0.02, 0.8)
	ms.border_color = Color("#8a6230")
	ms.set_border_width_all(2)
	ms.set_corner_radius_all(22)
	ms.content_margin_left = 22
	ms.content_margin_right = 22
	ms.content_margin_top = 8
	ms.content_margin_bottom = 8
	msg_panel.add_theme_stylebox_override("panel", ms)
	msg_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	msg_lbl = _lbl("", 26)
	msg_panel.add_child(msg_lbl)
	table.add_child(msg_panel)

	suit_box = PanelContainer.new()
	var ss: StyleBoxFlat = ms.duplicate()
	ss.border_color = Color("#e0b44a")
	ss.set_border_width_all(3)
	suit_box.add_theme_stylebox_override("panel", ss)
	suit_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := HBoxContainer.new()
	sh.add_theme_constant_override("separation", 10)
	sh.add_child(_lbl("Hraje se:", 26))
	suit_icon = TextureRect.new()
	suit_icon.custom_minimum_size = Vector2(46, 46)
	suit_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	suit_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sh.add_child(suit_icon)
	suit_box.add_child(sh)
	table.add_child(suit_box)

	hint_lbl = _lbl("", 26)
	hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_lbl.size = Vector2(700, 70)
	table.add_child(hint_lbl)

	shout_lbl = _lbl("", 64, Color("#ffd76a"))
	shout_lbl.add_theme_color_override("font_outline_color", Color(0.35, 0.12, 0.0))
	shout_lbl.add_theme_constant_override("outline_size", 16)
	shout_lbl.visible = false
	fx_layer.add_child(shout_lbl)

	menu_btn = _btn("Menu", _confirm_leave, 24)
	menu_btn.position = Vector2(14, 14)
	table.add_child(menu_btn)


func _pile_center() -> Vector2:
	return Vector2(size.x * 0.65, size.y * 0.455)


func _deck_center() -> Vector2:
	return Vector2(size.x * 0.29, size.y * 0.455)


func _seat_center(seat: int) -> Vector2:
	var n: int = view.get("n", 2)
	var me: int = view.get("seat", 0)
	var rel := (seat - me + n) % n
	if rel == 0:
		return Vector2(size.x / 2.0, size.y - CH / 2.0 - 60.0)
	var opp := n - 1
	var lst: Array
	if opp == 1:
		lst = [Vector2(size.x / 2.0, size.y * 0.13)]
	elif opp == 2:
		lst = [Vector2(size.x * 0.25, size.y * 0.135), Vector2(size.x * 0.75, size.y * 0.135)]
	else:
		lst = [Vector2(100, size.y * 0.27), Vector2(size.x / 2.0, size.y * 0.12), Vector2(size.x - 100, size.y * 0.27)]
	return lst[rel - 1]


func _relayout() -> void:
	if deck_node == null:
		return
	var dc := _deck_center()
	for i in deck_under.size():
		deck_under[i].position = dc - Vector2(CW, CH) / 2.0 + Vector2(-3.0 * (i + 1), -3.0 * (i + 1))
		deck_under[i].z_index = i
	deck_node.position = dc - Vector2(CW, CH) / 2.0
	deck_node.z_index = 5
	deck_lbl.position = dc + Vector2(-120, CH / 2.0 + 14)
	shout_lbl.size = Vector2(size.x, 120)
	shout_lbl.position = Vector2(0, size.y * 0.30 - 60)
	shout_lbl.pivot_offset = shout_lbl.size / 2.0
	hint_lbl.size = Vector2(size.x - 20, 70)
	hint_lbl.position = Vector2(10, size.y - CH - 150)
	if not view.is_empty():
		_update_opponents()
		_layout_pile(false)
		_layout_hand(false)
		_update_indicators()


# =====================================================================
#  STARTING GAMES
# =====================================================================
func _start_local(bots: int) -> void:
	Net.leave()
	mode = "local"
	seats = [{"kind": "me", "peer": 1, "name": my_name}]
	for i in bots:
		seats.append({"kind": "bot", "peer": 0, "name": BOT_NAMES[i]})
	scores = {}
	var cfg := ConfigFile.new()
	cfg.load(SAVE)
	for s in seats:
		scores[s["name"] if s["kind"] != "me" else "Ty"] = int(cfg.get_value("score", s["name"] if s["kind"] != "me" else "Ty", 0))
	rules = Rules.new()
	_new_round(randi() % seats.size())


func _new_round(start: int) -> void:
	round_id += 1
	bot_token += 1
	var names: Array = []
	for s in seats:
		names.append(s["name"])
	rules.new_game(names, start)
	_clear_overlay()
	_show("table")
	_push_views()


func _push_views() -> void:
	for i in seats.size():
		var s: Dictionary = seats[i]
		if s["kind"] == "me":
			var v := rules.view_for(i)
			v["round"] = round_id
			apply_view(v)
		elif s["kind"] == "peer":
			var v2 := rules.view_for(i)
			v2["round"] = round_id
			s_view.rpc_id(s["peer"], v2)
	if rules.winner >= 0:
		_on_round_won()
		return
	if seats[rules.cur]["kind"] == "bot":
		var tok := bot_token
		var delay := 0.9 + randf() * 0.6
		if auto.has("fast"):
			delay = 0.02
		get_tree().create_timer(delay).timeout.connect(func(): _bot_turn(tok))


func _bot_turn(tok: int) -> void:
	if tok != bot_token or rules == null or rules.winner >= 0:
		return
	var p := rules.cur
	if seats[p]["kind"] != "bot":
		return
	var m := rules.ai_move(p)
	if m.has("pass"):
		rules.pass_turn(p)
	else:
		rules.play(p, m["card"], m["suit"])
	_push_views()


func _act_play(seat: int, card: int, suit: int) -> void:
	if rules == null:
		return
	if rules.play(seat, card, suit):
		_push_views()
	else:
		_resend(seat)


func _act_pass(seat: int) -> void:
	if rules == null:
		return
	if rules.pass_turn(seat):
		_push_views()
	else:
		_resend(seat)


func _resend(seat: int) -> void:
	var v := rules.view_for(seat)
	v["round"] = round_id
	if seats[seat]["kind"] == "me":
		apply_view(v)
	elif seats[seat]["kind"] == "peer":
		s_view.rpc_id(seats[seat]["peer"], v)


func _score_key(i: int) -> String:
	if mode == "local" and seats[i]["kind"] == "me":
		return "Ty"
	return seats[i]["name"]


func _on_round_won() -> void:
	bot_token += 1
	var w := rules.winner
	var key := _score_key(w)
	scores[key] = int(scores.get(key, 0)) + 1
	if mode == "local":
		var cfg := ConfigFile.new()
		cfg.load(SAVE)
		cfg.set_value("score", key, scores[key])
		cfg.save(SAVE)
	var names: Array = []
	var sc: Array = []
	for i in seats.size():
		names.append(_score_key(i))
		sc.append(int(scores.get(_score_key(i), 0)))
	var info := {"winner": w, "names": names, "scores": sc, "round": round_id}
	for s in seats:
		if s["kind"] == "peer":
			s_end.rpc_id(s["peer"], info)
	var rid := round_id
	get_tree().create_timer(0.05 if auto.has("fast") else 1.3).timeout.connect(func():
		if rid == round_id:
			_show_end(info, true))
	if auto.has("games"):
		auto["played"] = int(auto.get("played", 0)) + 1
		print("AUTO_GAME_END winner=", seats[w]["name"], " played=", auto["played"])
		if auto["played"] >= int(auto["games"]):
			print("AUTO_DONE scores=", scores)
			get_tree().create_timer(0.3).timeout.connect(func(): get_tree().quit())
		else:
			get_tree().create_timer(0.1).timeout.connect(func():
				if mode == "local" or mode == "host":
					_new_round((w + 1) % seats.size()))


# =====================================================================
#  WI-FI
# =====================================================================
func _open_host() -> void:
	mode = "host"
	var err := Net.host(my_name)
	if err != OK:
		mode = ""
		_toast("Stůl se nepodařilo založit (chyba %d)." % err)
		return
	lobby_peers = {}
	scores = {}
	_refresh_lobby()
	_show("lobby")


func _refresh_lobby() -> void:
	var ips := Net.local_ips()
	lobby_info.text = "Stůl „%s“ je vidět na Wi-Fi.\nIP: %s" % [my_name, ", ".join(ips) if not ips.is_empty() else "není Wi-Fi?"]
	var lines: Array = ["• " + my_name + " (ty)"]
	for id in lobby_peers:
		lines.append("• " + lobby_peers[id])
	if add_bot:
		lines.append("• Pepa (počítač)")
	if lobby_peers.is_empty():
		lines.append("\nČekám na druhého hráče…")
	lobby_players.text = "\n".join(lines)
	lobby_start.disabled = lobby_peers.is_empty() and not add_bot
	var info := {"table": my_name, "players": lines}
	for id in lobby_peers:
		s_lobby.rpc_id(id, info)


func _host_start_round() -> void:
	if mode != "host":
		return
	seats = [{"kind": "me", "peer": 1, "name": my_name}]
	var used := {my_name: true}
	for id in lobby_peers:
		var nm: String = lobby_peers[id]
		while used.has(nm):
			nm += "*"
		used[nm] = true
		seats.append({"kind": "peer", "peer": id, "name": nm})
	if add_bot and seats.size() < 4:
		seats.append({"kind": "bot", "peer": 0, "name": "Pepa"})
	if seats.size() < 2:
		return
	for s in seats:
		if not scores.has(s["name"]):
			scores[s["name"]] = 0
	rules = Rules.new()
	_new_round(randi() % seats.size())


func _on_peer_connected(_id: int) -> void:
	pass  # wait for c_hello


func _on_peer_disconnected(id: int) -> void:
	if mode != "host":
		return
	if lobby_peers.has(id):
		var nm: String = lobby_peers[id]
		lobby_peers.erase(id)
		if rules == null or not table.visible:
			_refresh_lobby()
			return
		for i in seats.size():
			if seats[i]["kind"] == "peer" and seats[i]["peer"] == id:
				seats[i]["kind"] = "bot"
				_toast("%s odešel – hraje za něj počítač." % nm)
				if rules.winner < 0 and rules.cur == i:
					var tok := bot_token
					get_tree().create_timer(0.8).timeout.connect(func(): _bot_turn(tok))


func _open_finder() -> void:
	Net.leave()
	mode = ""
	Net.start_discovery()
	_finder_msg("Hledám stoly ve stejné síti…")
	_refresh_finder()
	_show("finder")


func _refresh_finder() -> void:
	if finder_list == null:
		return
	for c in finder_list.get_children():
		c.queue_free()
	for ip in Net.found:
		var nm: String = Net.found[ip]["name"]
		finder_list.add_child(_btn("Stůl „%s“  (%s)" % [nm, ip], func(): _join(ip), 28))
	if Net.found.is_empty() and mode != "client":
		_finder_msg("Hledám stoly ve stejné síti…")


func _finder_msg(t: String) -> void:
	if finder_status:
		finder_status.text = t


func _join(ip: String) -> void:
	if ip.strip_edges() == "":
		return
	mode = "client"
	Net.stop_discovery()
	_finder_msg("Připojuji se k %s…" % ip)
	if Net.join(ip) != OK:
		mode = ""
		_finder_msg("Nepodařilo se připojit.")


func _on_joined() -> void:
	_finder_msg("Připojeno! Čekáme, až hostitel rozdá karty…")
	for c in finder_list.get_children():
		c.queue_free()
	c_hello.rpc_id(1, my_name)


func _on_lost_server() -> void:
	if mode == "client":
		mode = ""
		_clear_table()
		_show("menu")
		_toast("Spojení se stolem se přerušilo.")


@rpc("any_peer", "call_remote", "reliable")
func c_hello(nm: String) -> void:
	if mode != "host":
		return
	var id := multiplayer.get_remote_sender_id()
	nm = nm.strip_edges().substr(0, 12)
	if nm == "":
		nm = "Host"
	if table.visible and rules != null:
		s_kick.rpc_id(id, "Hra už běží, počkej na další stůl.")
		return
	lobby_peers[id] = nm
	_sfx("turn")
	_refresh_lobby()


@rpc("authority", "call_remote", "reliable")
func s_lobby(info: Dictionary) -> void:
	if mode != "client":
		return
	_finder_msg("Stůl „%s“\n%s\n\nČekáme, až hostitel rozdá…" % [info.get("table", "?"), "\n".join(info.get("players", []))])


@rpc("authority", "call_remote", "reliable")
func s_kick(reason: String) -> void:
	Net.leave()
	mode = ""
	_show("menu")
	_toast(reason)


@rpc("authority", "call_remote", "reliable")
func s_view(v: Dictionary) -> void:
	if mode != "client":
		return
	if not table.visible:
		_show("table")
	apply_view(v)


@rpc("authority", "call_remote", "reliable")
func s_end(info: Dictionary) -> void:
	if mode != "client":
		return
	var rid: int = info.get("round", 0)
	get_tree().create_timer(0.05 if auto.has("fast") else 1.3).timeout.connect(func():
		if int(view.get("round", -1)) == rid:
			_show_end(info, false))
	if auto.has("games"):
		auto["played"] = int(auto.get("played", 0)) + 1
		print("AUTO_CLIENT_END winner=", info["names"][info["winner"]], " played=", auto["played"])


@rpc("any_peer", "call_remote", "reliable")
func c_play(card: int, suit: int) -> void:
	if mode != "host":
		return
	var s := _seat_of_peer(multiplayer.get_remote_sender_id())
	if s >= 0:
		_act_play(s, card, suit)


@rpc("any_peer", "call_remote", "reliable")
func c_pass() -> void:
	if mode != "host":
		return
	var s := _seat_of_peer(multiplayer.get_remote_sender_id())
	if s >= 0:
		_act_pass(s)


func _seat_of_peer(id: int) -> int:
	for i in seats.size():
		if seats[i]["kind"] == "peer" and seats[i]["peer"] == id:
			return i
	return -1


# =====================================================================
#  MY ACTIONS
# =====================================================================
func _my_turn() -> bool:
	return not view.is_empty() and view["cur"] == view["seat"] and view["winner"] < 0


func _can_play_view(c: int) -> bool:
	var d: Array = view["discard"]
	return Rules.can_play_on(c, d.back(), view["top_suit"], view["penalty"], view["ace_stop"])


func _send_play(card: int, suit: int) -> void:
	selected = -1
	if hand_nodes.has(card):
		var nd: CardNode = hand_nodes[card]
		nd.z_index = 150
		nd.move_to(_pile_center() - Vector2(CW, CH) / 2.0, 0.0, 0.18, 1.0)
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(25)
	if mode == "client":
		c_play.rpc_id(1, card, suit)
	else:
		_act_play(view["seat"], card, suit)


func _send_pass() -> void:
	selected = -1
	if mode == "client":
		c_pass.rpc_id(1)
	else:
		_act_pass(view["seat"])


func _try_play(card: int) -> void:
	if not _my_turn() or waiting_suit:
		_reject(card, "Teď nejsi na tahu.")
		return
	if not _can_play_view(card):
		_reject(card, "Tuhle kartu teď dát nejde.")
		return
	if Rules.rank_of(card) == Rules.RQ:
		_ask_suit(card)
	else:
		_send_play(card, -1)


func _reject(card: int, why: String) -> void:
	_sfx("bad")
	_set_msg(why)
	_layout_hand(true)
	if hand_nodes.has(card):
		var nd: CardNode = hand_nodes[card]
		get_tree().create_timer(0.26).timeout.connect(func():
			if is_instance_valid(nd):
				nd.shake())


func _on_card_dropped(nd: CardNode, pos: Vector2, vel: Vector2, travel: Vector2) -> void:
	var pc := _pile_center()
	var pile_rect := Rect2(pc - Vector2(CW, CH) * 0.95, Vector2(CW, CH) * 1.9)
	var flick := vel.y < -550.0 and travel.y < -40.0
	var lifted := travel.y < -150.0
	if pile_rect.has_point(pos) or flick or lifted:
		_try_play(nd.card)
	else:
		_layout_hand(true)


func _on_card_tapped(nd: CardNode) -> void:
	if selected == nd.card:
		_try_play(nd.card)
		return
	selected = nd.card
	_sfx("draw")
	_layout_hand(true)


func _on_deck_tapped() -> void:
	if not _my_turn() or waiting_suit:
		return
	_send_pass()


func _ask_suit(card: int) -> void:
	waiting_suit = true
	var a := _overlay_panel(560)
	var v: VBoxContainer = a[1]
	v.add_child(_lbl("Svršek!", 54, Color("#f3d48a")))
	v.add_child(_lbl("Na jakou barvu měníš?", 30))
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 16)
	g.add_theme_constant_override("v_separation", 16)
	for s in 4:
		var b := Button.new()
		b.text = Rules.SUIT_NAMES[s]
		b.icon = SUIT_TEX[s]
		b.expand_icon = true
		b.custom_minimum_size = Vector2(240, 110)
		b.add_theme_constant_override("icon_max_width", 64)
		b.add_theme_font_size_override("font_size", 30)
		b.pressed.connect(func():
			waiting_suit = false
			_clear_overlay()
			_send_play(card, s))
		g.add_child(b)
	v.add_child(g)
	v.add_child(_btn("Zpět", func():
		waiting_suit = false
		_clear_overlay()
		_layout_hand(true), 28))


# =====================================================================
#  RENDERING A VIEW
# =====================================================================
func apply_view(v: Dictionary) -> void:
	var prev := view
	view = v
	var ev: Dictionary = v.get("ev", {})
	var new_round: bool = int(v.get("round", 0)) != shown_round
	if deck_node.position == Vector2.ZERO:
		_relayout()
	if new_round:
		shown_round = int(v.get("round", 0))
		_clear_overlay()
		waiting_suit = false
		selected = -1
		_sfx("shuffle")
		prev = {}
	_update_opponents()
	_update_pile(prev, v, new_round)
	_update_hand(prev, v, new_round)
	_update_indicators()
	_announce(prev, v, new_round)
	if not new_round and ev.get("type", "") == "pass" and ev.get("kind", "") == "draw" and ev["seat"] != v["seat"]:
		_fly_backs(ev["seat"], int(ev.get("count", 1)))
	if auto.has("autoplay") and _my_turn():
		var rid: int = int(v.get("round", 0))
		var cur_turn: Dictionary = v.get("ev", {})
		get_tree().create_timer(0.03).timeout.connect(func():
			if _my_turn() and int(view.get("round", 0)) == rid and view.get("ev", {}) == cur_turn:
				_auto_move())


func _auto_move() -> void:
	var hand: Array = view["hand"]
	for c in hand:
		if _can_play_view(c):
			var suit := -1
			if Rules.rank_of(c) == Rules.RQ:
				suit = Rules.suit_of(hand[0])
			_send_play(c, suit)
			return
	_send_pass()


func _clear_table() -> void:
	for c in hand_nodes.values():
		c.queue_free()
	hand_nodes.clear()
	hand_order.clear()
	for p in pile_nodes:
		p.queue_free()
	pile_nodes.clear()
	for c in opp_layer.get_children():
		c.queue_free()
	view = {}
	shown_round = -1


func _pile_offset(c: int, k: int) -> Array:
	var r := deg_to_rad(float((c * 37 + k * 13) % 25 - 12))
	var off := Vector2(float((c * 7 + k * 5) % 13 - 6), float((c * 11 + k * 3) % 11 - 5))
	return [off, r]


func _update_pile(prev: Dictionary, v: Dictionary, new_round: bool) -> void:
	var disc: Array = v["discard"]
	var top_card: int = disc.back()
	var prev_top := -1
	if not prev.is_empty():
		prev_top = (prev["discard"] as Array).back()
	if new_round or pile_nodes.is_empty():
		for p in pile_nodes:
			p.queue_free()
		pile_nodes.clear()
		for i in disc.size():
			var nd := CardNode.new().setup(disc[i], true, Vector2(CW, CH))
			cards_layer.add_child(nd)
			pile_nodes.append(nd)
		_layout_pile(false)
		if new_round and not pile_nodes.is_empty():
			var t: CardNode = pile_nodes.back()
			var target := t.position
			t.position = _deck_center() - Vector2(CW, CH) / 2.0
			t.move_to(target, t.rotation, 0.4, 1.0, 0.5)
		return
	if top_card == prev_top:
		return
	var ev: Dictionary = v.get("ev", {})
	var nd: CardNode = CardNode.new().setup(top_card, true, Vector2(CW, CH))
	cards_layer.add_child(nd)
	if hand_nodes.has(top_card):
		var hn: CardNode = hand_nodes[top_card]
		nd.position = hn.position
		nd.rotation = hn.rotation
		nd.scale = hn.scale
		hand_nodes.erase(top_card)
		hand_order.erase(top_card)
		hn.queue_free()
	else:
		nd.position = _seat_center(int(ev.get("seat", 0))) - Vector2(CW, CH) / 2.0
		nd.scale = Vector2(0.45, 0.45)
		nd.rotation = randf_range(-0.6, 0.6)
	pile_nodes.append(nd)
	while pile_nodes.size() > 6:
		pile_nodes.pop_front().queue_free()
	_layout_pile(true)
	_sfx("slap")


func _layout_pile(anim: bool) -> void:
	var base := _pile_center() - Vector2(CW, CH) / 2.0
	for i in pile_nodes.size():
		var nd: CardNode = pile_nodes[i]
		var o := _pile_offset(nd.card, i)
		nd.z_index = 10 + i
		if anim and i == pile_nodes.size() - 1:
			nd.move_to(base + o[0], o[1], 0.3, 1.0)
		else:
			nd.position = base + o[0]
			nd.rotation = o[1]
			nd.scale = Vector2.ONE


func _update_hand(_prev: Dictionary, v: Dictionary, new_round: bool) -> void:
	var hand: Array = v["hand"].duplicate()
	hand.sort()
	if new_round:
		for c in hand_nodes.values():
			c.queue_free()
		hand_nodes.clear()
	for c in hand_nodes.keys():
		if not hand.has(c):
			hand_nodes[c].queue_free()
			hand_nodes.erase(c)
	var k := 0
	var new_cards := false
	for c in hand:
		if not hand_nodes.has(c):
			var nd := CardNode.new().setup(c, true, Vector2(CW, CH))
			nd.position = _deck_center() - Vector2(CW, CH) / 2.0
			nd.scale = Vector2(0.9, 0.9)
			nd.set_interactive(true, true)
			nd.dropped.connect(_on_card_dropped)
			nd.tapped.connect(_on_card_tapped)
			nd.set_meta("delay", (0.6 if new_round else 0.0) + k * 0.09)
			cards_layer.add_child(nd)
			hand_nodes[c] = nd
			k += 1
			new_cards = true
	hand_order = hand
	if new_cards and not new_round:
		_sfx("draw")
	if not hand.has(selected):
		selected = -1
	_layout_hand(true)


func _layout_hand(anim: bool) -> void:
	var n := hand_order.size()
	if n == 0:
		return
	var maxw := size.x - 30.0
	var step: float = CW * 0.66 if n == 1 else minf(CW * 0.66, (maxw - CW) / float(n - 1))
	var total := CW + step * (n - 1)
	var x0 := (size.x - total) / 2.0
	var base_y := size.y - CH - 50.0
	var spread := minf(0.22, 0.035 * n)
	var my := _my_turn() and not waiting_suit
	for i in n:
		var c: int = hand_order[i]
		var nd: CardNode = hand_nodes[c]
		if nd.is_dragging():
			continue
		var t := 0.0 if n == 1 else (float(i) - (n - 1) / 2.0) / ((n - 1) / 2.0)
		var pos := Vector2(x0 + step * i, base_y + t * t * 26.0)
		var rot := t * spread
		if c == selected:
			pos.y -= 46.0
		nd.z_index = 50 + i
		var ok := my and _can_play_view(c)
		nd.set_glow(ok)
		nd.modulate = Color(1, 1, 1) if (not my or ok) else Color(0.62, 0.62, 0.62)
		var d: float = nd.get_meta("delay", 0.0)
		nd.set_meta("delay", 0.0)
		if anim:
			nd.move_to(pos, rot, 0.28, 1.0, d)
		else:
			nd.position = pos
			nd.rotation = rot
			nd.scale = Vector2.ONE


func _update_opponents() -> void:
	for c in opp_layer.get_children():
		c.queue_free()
	var n: int = view.get("n", 0)
	var me: int = view.get("seat", 0)
	for s in n:
		if s == me:
			continue
		var cen := _seat_center(s)
		var cnt: int = view["counts"][s]
		var shown := mini(cnt, 8 if n <= 3 else 5)
		var gap := 22.0
		var w := OW + gap * maxf(shown - 1, 0)
		for i in shown:
			var b := TextureRect.new()
			b.texture = BACK
			b.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			b.stretch_mode = TextureRect.STRETCH_SCALE
			b.size = Vector2(OW, OH)
			b.pivot_offset = Vector2(OW / 2.0, OH)
			var t := 0.0 if shown == 1 else (float(i) - (shown - 1) / 2.0) / ((shown - 1) / 2.0)
			b.rotation = t * 0.28
			b.position = Vector2(cen.x - w / 2.0 + gap * i, cen.y - OH / 2.0 + 18.0 + absf(t) * 6.0)
			b.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.material = CardNode._mat
			opp_layer.add_child(b)
		var tag := PanelContainer.new()
		var st := StyleBoxFlat.new()
		var active: bool = view["cur"] == s and view["winner"] < 0
		st.bg_color = Color("#dcae45") if active else Color(0.1, 0.05, 0.02, 0.82)
		st.border_color = Color("#ffe39a") if active else Color("#8a6230")
		st.set_border_width_all(2)
		st.set_corner_radius_all(16)
		st.content_margin_left = 14
		st.content_margin_right = 14
		st.content_margin_top = 4
		st.content_margin_bottom = 4
		if active:
			st.shadow_color = Color(1, 0.8, 0.3, 0.6)
			st.shadow_size = 12
		tag.add_theme_stylebox_override("panel", st)
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l := _lbl("%s · %d" % [view["names"][s], cnt], 24, Color("#2a1500") if active else Color("#f6e7c1"))
		if active:
			l.add_theme_constant_override("outline_size", 0)
		tag.add_child(l)
		opp_layer.add_child(tag)
		tag.reset_size()
		tag.position = Vector2(cen.x - tag.size.x / 2.0, cen.y - OH / 2.0 - 34.0)


func _fly_backs(seat: int, count: int) -> void:
	var target := _seat_center(seat) - Vector2(CW, CH) / 2.0
	for i in mini(count, 4):
		var b := CardNode.new().setup(-1, false, Vector2(CW, CH))
		b.position = _deck_center() - Vector2(CW, CH) / 2.0
		b.z_index = 120
		fx_layer.add_child(b)
		var tw := b.move_to(target, randf_range(-0.4, 0.4), 0.35, 0.4, i * 0.08)
		tw.chain().tween_callback(b.queue_free)
	_sfx("draw")


func _update_indicators() -> void:
	if view.is_empty():
		return
	var d: Array = view["discard"]
	var top_card: int = d.back()
	var ts: int = view["top_suit"]
	var changed: bool = Rules.rank_of(top_card) == Rules.RQ or Rules.suit_of(top_card) != ts
	suit_box.visible = changed
	if changed:
		suit_icon.texture = SUIT_TEX[ts]
		suit_box.reset_size()
		var pc := _pile_center()
		suit_box.position = Vector2(pc.x - suit_box.size.x / 2.0, pc.y + CH / 2.0 + 18.0)
	var pen: int = view["penalty"]
	if pen > 0:
		deck_lbl.text = "Lízni %d!" % pen
		deck_lbl.add_theme_color_override("font_color", Color("#ff8a7a"))
	elif view["ace_stop"]:
		deck_lbl.text = "Stůj!"
		deck_lbl.add_theme_color_override("font_color", Color("#ff8a7a"))
	else:
		deck_lbl.text = "Balík · %d" % int(view["deck"])
		deck_lbl.add_theme_color_override("font_color", Color("#f6e7c1"))
	var my := _my_turn()
	var has_move := false
	for c in view["hand"]:
		if _can_play_view(c):
			has_move = true
	deck_node.set_glow(my and not has_move)
	if view["winner"] >= 0:
		hint_lbl.text = ""
	elif my:
		hint_lbl.add_theme_color_override("font_color", Color("#ffd76a"))
		if view["ace_stop"]:
			hint_lbl.text = "Eso! Dej eso, nebo ťukni na balík (stojíš)" if has_move else "Eso – stojíš. Ťukni na balík."
		elif pen > 0:
			hint_lbl.text = "Sedma! Přebij sedmou, nebo ťukni na balík (bereš %d)" % pen if has_move else "Sedma – ťukni na balík, bereš %d." % pen
		elif has_move:
			hint_lbl.text = "Tvůj tah – táhni kartu na stůl nebo ji švihni nahoru"
		else:
			hint_lbl.text = "Nemáš co dát – ťukni na balík"
	else:
		hint_lbl.add_theme_color_override("font_color", Color("#e9d6a8"))
		hint_lbl.text = "Hraje %s…" % view["names"][view["cur"]]


func _who(seat: int) -> String:
	return view["names"][seat]


func _announce(prev: Dictionary, v: Dictionary, new_round: bool) -> void:
	var ev: Dictionary = v.get("ev", {})
	var me: int = v["seat"]
	var t: String = ev.get("type", "")
	if new_round:
		_set_msg("Rozdáno! Začínáš ty." if v["cur"] == me else "Rozdáno! Začíná %s." % _who(v["cur"]))
		var tc: int = (v["discard"] as Array).back()
		if v["penalty"] > 0:
			_shout("Sedma na stole!")
		elif v["ace_stop"]:
			_shout("Eso na stole!")
		elif Rules.rank_of(tc) == Rules.RQ:
			pass
		return
	if prev.is_empty():
		return
	if ev == prev.get("ev", {}):
		return
	var s: int = ev.get("seat", -1)
	var mine := s == me
	if t == "play":
		var c: int = ev["card"]
		var r := Rules.rank_of(c)
		var desc := "%s %s" % [ACC[r], Rules.SUIT_NAMES[Rules.suit_of(c)].to_lower()]
		_set_msg(("Dal jsi " + desc) if mine else ("%s dal %s" % [_who(s), desc]))
		if ev.get("win", false):
			_shout("Prší!" if not mine else "Prší! Vyhrál jsi!")
		elif r == Rules.R7:
			_shout("Sedma! Bere se %d" % int(ev.get("penalty", 2)))
		elif r == Rules.RA:
			_shout("Eso – stůj!")
		elif r == Rules.RQ:
			_shout("Svršek – na %s!" % Rules.SUIT_NAMES[int(ev["suit"])].to_lower())
		elif int(ev.get("left", 9)) == 1:
			_shout(("Poslední karta!") if mine else ("%s má poslední!" % _who(s)))
	elif t == "pass":
		var k: String = ev.get("kind", "")
		if k == "stand":
			_set_msg("Stojíš." if mine else "%s stojí." % _who(s))
		elif ev.get("forced", false):
			_set_msg(("Bereš %d." % int(ev["count"])) if mine else ("%s bere %d." % [_who(s), int(ev["count"])]))
		else:
			_set_msg("Líznul sis." if mine else "%s si líznul." % _who(s))
	if v["cur"] == me and v["winner"] < 0 and prev.get("cur", -1) != me:
		_sfx("turn")


func _set_msg(t: String) -> void:
	msg_lbl.text = t
	msg_panel.reset_size()
	msg_panel.position = Vector2(size.x / 2.0 - msg_panel.size.x / 2.0, size.y * 0.235)
	msg_panel.modulate = Color(1, 1, 1, 0)
	create_tween().tween_property(msg_panel, "modulate", Color.WHITE, 0.2)


func _shout(t: String) -> void:
	shout_lbl.text = t
	shout_lbl.visible = true
	shout_lbl.scale = Vector2(0.3, 0.3)
	shout_lbl.modulate = Color.WHITE
	var tw := create_tween()
	tw.tween_property(shout_lbl, "scale", Vector2(1.15, 1.15), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(shout_lbl, "scale", Vector2.ONE, 0.12)
	tw.tween_interval(0.8)
	tw.tween_property(shout_lbl, "modulate", Color(1, 1, 1, 0), 0.35)
	tw.tween_callback(func(): shout_lbl.visible = false)


# =====================================================================
#  OVERLAYS
# =====================================================================
func _overlay_panel(min_w: float) -> Array:
	_clear_overlay()
	overlay = _full(ui_layer)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(cc)
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(min_w, 0)
	cc.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	pc.add_child(v)
	pc.scale = Vector2(0.85, 0.85)
	pc.modulate = Color(1, 1, 1, 0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(pc, "modulate", Color.WHITE, 0.18)
	tw.tween_property(pc, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pc.resized.connect(func(): pc.pivot_offset = pc.size / 2.0)
	return [overlay, v]


func _clear_overlay() -> void:
	if overlay and is_instance_valid(overlay):
		overlay.queue_free()
	overlay = null


func _show_end(info: Dictionary, controls: bool) -> void:
	var w: int = info["winner"]
	var me: int = view.get("seat", -1)
	var won := w == me
	_sfx("win" if won else "lose")
	var a := _overlay_panel(580)
	var v: VBoxContainer = a[1]
	v.add_child(_lbl("Prší! Vyhrál jsi!" if won else "Vyhrál %s" % info["names"][w], 50, Color("#f3d48a")))
	v.add_child(_lbl("Hospoda tleská, další runda na tebe čeká." if won else "Nevadí, dej si pivo a odvetu.", 26, Color("#e9d6a8"), 500))
	var lines: Array = []
	for i in (info["names"] as Array).size():
		lines.append("%s:  %d" % [info["names"][i], int(info["scores"][i])])
	v.add_child(_lbl("Skóre\n" + "\n".join(lines), 30))
	if controls:
		v.add_child(_btn("Další runda", func(): _new_round((w + 1) % seats.size())))
	else:
		v.add_child(_lbl("Čekáme, až hostitel rozdá další rundu…", 24, Color("#d8c393"), 500))
	v.add_child(_btn("Do menu", _go_menu, 28))
	if mode == "local" or mode == "host":
		v.add_child(_lbl("Karty: foto Countakeshi, Wikimedia Commons, CC BY-SA 4.0", 16, Color(1, 1, 1, 0.55), 500))


func _confirm_leave() -> void:
	var a := _overlay_panel(520)
	var v: VBoxContainer = a[1]
	v.add_child(_lbl("Odejít od stolu?", 44, Color("#f3d48a")))
	if mode == "host":
		v.add_child(_lbl("Ostatním hráčům se hra ukončí.", 24, Color("#e9d6a8"), 440))
	v.add_child(_btn("Ano, do menu", _go_menu))
	v.add_child(_btn("Hrát dál", _clear_overlay))


func _toast(t: String) -> void:
	var l := _lbl(t, 26)
	var p := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.1, 0.05, 0.02, 0.92)
	st.border_color = Color("#c99632")
	st.set_border_width_all(2)
	st.set_corner_radius_all(18)
	st.content_margin_left = 20
	st.content_margin_right = 20
	st.content_margin_top = 10
	st.content_margin_bottom = 10
	p.add_theme_stylebox_override("panel", st)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(minf(size.x - 80, 600), 0)
	p.add_child(l)
	add_child(p)
	p.reset_size()
	p.position = Vector2(size.x / 2.0 - p.size.x / 2.0, size.y * 0.06)
	var tw := create_tween()
	tw.tween_interval(2.6)
	tw.tween_property(p, "modulate", Color(1, 1, 1, 0), 0.4)
	tw.tween_callback(p.queue_free)


func _go_menu() -> void:
	bot_token += 1
	Net.stop_discovery()
	Net.leave()
	mode = ""
	rules = null
	waiting_suit = false
	_clear_overlay()
	_clear_table()
	_show("menu")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if overlay and is_instance_valid(overlay):
			if waiting_suit:
				waiting_suit = false
				_layout_hand(true)
			_clear_overlay()
		elif table.visible:
			_confirm_leave()
		elif not screens["menu"].visible:
			_go_menu()
		else:
			get_tree().quit()


# =====================================================================
#  MISC
# =====================================================================
func _sfx(k: String) -> void:
	if sound_on and players.has(k):
		players[k].play()


func _load_cfg() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE) == OK:
		my_name = str(cfg.get_value("player", "name", my_name))
		sound_on = bool(cfg.get_value("player", "sound", true))


func _save_cfg() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE)
	cfg.set_value("player", "name", my_name)
	cfg.set_value("player", "sound", sound_on)
	cfg.save(SAVE)


func _refresh_menu_score() -> void:
	if menu_score_lbl == null:
		return
	var cfg := ConfigFile.new()
	if cfg.load(SAVE) != OK or not cfg.has_section("score"):
		menu_score_lbl.text = "Skóre zatím prázdné – rozdej si!"
		return
	var parts: Array = []
	for k in cfg.get_section_keys("score"):
		parts.append("%s %d" % [k, int(cfg.get_value("score", k, 0))])
	menu_score_lbl.text = "Skóre:  " + "  ·  ".join(parts)


func _cmdline_hooks() -> void:
	# Test hooks: --autolocal=2 --autohost --autojoin=IP --games=N --fast --autoplay --name=X --shot=path
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=")
		auto[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if auto.is_empty():
		return
	if auto.has("name"):
		my_name = auto["name"]
	if auto.has("autolocal"):
		_start_local(int(auto["autolocal"]))
	elif auto.has("autohost"):
		add_bot = auto.has("bot")
		_open_host()
		multiplayer.peer_connected.connect(func(_id):
			get_tree().create_timer(0.8).timeout.connect(func():
				if not table.visible and not lobby_peers.is_empty():
					_host_start_round()))
	elif auto.has("autojoin"):
		_open_finder()
		if auto["autojoin"] == "discover":
			Net.tables_changed.connect(func():
				if mode == "" and not Net.found.is_empty():
					print("AUTO_FOUND ", Net.found)
					_join(Net.found.keys()[0]))
		else:
			_join(auto["autojoin"])
	if auto.has("inputtest"):
		_input_test(auto["inputtest"])
	if auto.has("shot"):
		get_tree().create_timer(float(auto.get("shotdelay", "3"))).timeout.connect(func():
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(auto["shot"])
			print("SHOT_SAVED")
			if not auto.has("games"):
				get_tree().quit())


# ---------- input self-test (drag / swipe / tap) ----------
func _input_test(kind: String) -> void:
	for i in 400:
		await get_tree().create_timer(0.05).timeout
		if _my_turn() and not waiting_suit:
			var c := -1
			for k in hand_order:
				if _can_play_view(k) and Rules.rank_of(k) != Rules.RQ:
					c = k
			if c >= 0:
				await get_tree().create_timer(0.8).timeout
				var nd: CardNode = hand_nodes[c]
				var a := nd.position + nd.size / 2.0
				var b := _pile_center() if kind == "drag" else (a + Vector2(130, -25) if kind == "side" else a + Vector2(0, -170))
				var before: int = (view["hand"] as Array).size()
				if kind == "tap":
					await _tap(a)
					await get_tree().create_timer(0.4).timeout
					await _tap(a + Vector2(0, -46))
				else:
					await _mouse(a, true)
					var steps := 10 if kind == "drag" else 3
					for j in steps:
						await _move(a.lerp(b, float(j + 1) / steps))
					await _mouse(b, false)
				await get_tree().create_timer(1.0).timeout
				var ok := not (view["hand"] as Array).has(c) and (view["hand"] as Array).size() == before - 1 or (view["discard"] as Array).has(c)
				if kind == "side":
					ok = (view["hand"] as Array).has(c)
				print("INPUTTEST ", kind, " card=", Rules.card_name(c), " -> ", "OK" if ok else "FAIL")
				get_tree().quit()
				return
			_send_pass()
	print("INPUTTEST ", kind, " no turn")
	get_tree().quit()


func _mouse(p: Vector2, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	p = get_viewport().get_final_transform() * p
	e.position = p
	e.global_position = p
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	Input.parse_input_event(e)
	await get_tree().process_frame
	await get_tree().process_frame


func _move(p: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	p = get_viewport().get_final_transform() * p
	e.position = p
	e.global_position = p
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(e)
	await get_tree().create_timer(0.016).timeout


func _tap(p: Vector2) -> void:
	await _mouse(p, true)
	await _mouse(p, false)
