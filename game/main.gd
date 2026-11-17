extends Control
## Pub Prší at the bar – up to 10 players, several decks, open cards, several cards at once.
## The host (or the local game) owns the Rules object; everybody renders from a "view".

const CW := 150.0          # card in my hand
const CH := 228.0
const TW := 112.0          # cards on the bar (deck, pile, my open cards)
const TH := 170.0
const OW := 50.0           # opponents' open cards
const OH := 76.0
const BOT_NAMES := ["Pepa", "Franta", "Jarda", "Mirek", "Zdeněk", "Vašek", "Láďa", "Karel", "Bohouš"]
const SAVE := "user://prsi.cfg"
const RELEASE_API := "https://api.github.com/repos/Jedn0ta/prsivoe/releases/tags/latest"
const APK_URL := "https://github.com/Jedn0ta/prsivoe/releases/download/latest/prsi.apk"
const ACC := ["sedmu", "osmu", "devítku", "desítku", "spodka", "svrška", "krále", "eso"]
const ACC_PL := ["sedmy", "osmy", "devítky", "desítky", "spodky", "svršky", "krále", "esa"]
const SLOT := {
	"L1": Vector2(0.20, 0.165), "L2": Vector2(0.20, 0.305), "L3": Vector2(0.20, 0.545), "L4": Vector2(0.20, 0.655),
	"T": Vector2(0.5, 0.075),
	"R1": Vector2(0.80, 0.165), "R2": Vector2(0.80, 0.305), "R3": Vector2(0.80, 0.545), "R4": Vector2(0.80, 0.655)}
const LAYOUT := {
	1: ["T"], 2: ["L1", "R1"], 3: ["L2", "T", "R2"], 4: ["L3", "L1", "R1", "R3"],
	5: ["L3", "L1", "T", "R1", "R3"], 6: ["L3", "L2", "L1", "R1", "R2", "R3"],
	7: ["L3", "L2", "L1", "T", "R1", "R2", "R3"], 8: ["L4", "L3", "L2", "L1", "R1", "R2", "R3", "R4"],
	9: ["L4", "L3", "L2", "L1", "T", "R1", "R2", "R3", "R4"]}

const BAR_TEX: Texture2D = preload("res://img/bar.jpg")
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
var scores := {}
var lobby_peers := {}     # peer id -> name (host)
var seat_total := 4
var deck_count := 5
var next_dealer := -1
var pending_dealer := -1
var view: Dictionary = {}
var shown_round := -1
var anim_seq := -1
var my_name := "Hráč"
var sound_on := true
var waiting_suit := false
var sel: Array = []
var bot_token := 0
var auto := {}

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
var play_btn: Button
var shout_lbl: Label
var menu_btn: Button
var hand_nodes := {}      # card -> CardNode (my hand AND my open cards)
var hand_order: Array = []
var open_order: Array = []
var pile_nodes: Array = []
var screens := {}
var menu_score_lbl: Label
var name_edit: LineEdit
var setup_info: Label
var lobby_info: Label
var lobby_players: Label
var lobby_start: Button
var lobby_seats_val: Label
var lobby_decks_val: Label
var setup_players_val: Label
var setup_decks_val: Label
var finder_list: VBoxContainer
var finder_status: Label
var ip_edit: LineEdit
var overlay: Control
var players := {}
var update_btn: Button
var version_lbl: Label


# =====================================================================
#  SETUP
# =====================================================================
func _ready() -> void:
	randomize()
	_load_cfg()
	_build_theme()
	bg = TextureRect.new()
	bg.texture = BAR_TEX
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	table = _full(self)
	_build_table()
	screens["menu"] = _build_menu()
	screens["setup"] = _build_setup()
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
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	resized.connect(_relayout)
	_show("menu")
	_cmdline_hooks()
	_check_update()


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
	pn.bg_color = Color(0.13, 0.075, 0.035, 0.95)
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


## A "– value +" row. get_v/set_v keep the value inside limits.
func _stepper(parent: Control, title: String, get_v: Callable, set_v: Callable, sub: String = "") -> Label:
	parent.add_child(_lbl(title, 32))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 26)
	var val := _lbl(str(get_v.call()), 64, Color("#ffd76a"))
	val.custom_minimum_size = Vector2(120, 0)
	var minus := _btn("–", func():
		set_v.call(get_v.call() - 1)
		val.text = str(get_v.call()), 44)
	var plus := _btn("+", func():
		set_v.call(get_v.call() + 1)
		val.text = str(get_v.call()), 44)
	minus.custom_minimum_size = Vector2(100, 90)
	plus.custom_minimum_size = Vector2(100, 90)
	row.add_child(minus)
	row.add_child(val)
	row.add_child(plus)
	parent.add_child(row)
	if sub != "":
		parent.add_child(_lbl(sub, 22, Color("#c9b58a")))
	return val


func _screen_panel(min_w: float = 600.0) -> Array:
	var root := _full(self)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
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
	v.add_theme_constant_override("separation", 18)
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
	v.add_child(_lbl("hospodská klasika u baru", 26, Color("#e9d6a8")))
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
	update_btn = _btn("Stáhnout novou verzi", func(): OS.shell_open(APK_URL), 28)
	update_btn.visible = false
	v.add_child(update_btn)
	v.add_child(_btn("Hrát s počítačem", func(): _show("setup")))
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
	version_lbl = _lbl("verze " + _app_version(), 18, Color(1, 1, 1, 0.5))
	v.add_child(version_lbl)
	return a[0]


func _fix_decks() -> void:
	deck_count = clampi(deck_count, Rules.min_decks(seat_total), 5)


func _build_setup() -> Control:
	var a := _screen_panel()
	var v: VBoxContainer = a[1]
	v.add_child(_lbl("K baru", 56, Color("#f3d48a")))
	setup_players_val = _stepper(v, "Hráčů u baru", func(): return seat_total, func(x: int):
		seat_total = clampi(x, 2, 10)
		_fix_decks()
		_refresh_setup(), "ty + počítač: Pepa, Franta, Jarda…")
	setup_decks_val = _stepper(v, "Balíčků karet", func(): return deck_count, func(x: int):
		deck_count = x
		_fix_decks()
		_refresh_setup())
	setup_info = _lbl("", 24, Color("#d8c393"), 520)
	v.add_child(setup_info)
	v.add_child(_btn("Sednout k baru", _start_local))
	v.add_child(_btn("Zpět", _go_menu, 28))
	_refresh_setup()
	return a[0]


func _refresh_setup() -> void:
	if setup_info == null:
		return
	setup_players_val.text = str(seat_total)
	setup_decks_val.text = str(deck_count)
	setup_info.text = "%d karet v balíku · max. %d karet na hráče" % [deck_count * 32, Rules.max_per_player(seat_total, deck_count)]
	_save_cfg()


func _build_lobby() -> Control:
	var a := _screen_panel()
	var v: VBoxContainer = a[1]
	v.add_child(_lbl("Tvůj bar na Wi-Fi", 48, Color("#f3d48a")))
	lobby_info = _lbl("", 24, Color("#e9d6a8"), 520)
	v.add_child(lobby_info)
	lobby_players = _lbl("", 26, Color("#f6e7c1"), 520)
	v.add_child(lobby_players)
	lobby_seats_val = _stepper(v, "Míst u baru", func(): return seat_total, func(x: int):
		seat_total = clampi(x, maxi(2, 1 + lobby_peers.size()), 10)
		_fix_decks()
		_refresh_lobby())
	lobby_decks_val = _stepper(v, "Balíčků karet", func(): return deck_count, func(x: int):
		deck_count = x
		_fix_decks()
		_refresh_lobby())
	lobby_start = _btn("Začít hrát", _host_start_game)
	v.add_child(lobby_start)
	v.add_child(_btn("Zrušit stůl", _go_menu, 28))
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
	if which == "setup":
		_fix_decks()
		_refresh_setup()


# =====================================================================
#  TABLE NODES & LAYOUT
# =====================================================================
func _build_table() -> void:
	opp_layer = _full(table)
	cards_layer = _full(table)
	fx_layer = _full(table)
	for i in 4:
		var u := CardNode.new().setup(-1, false, Vector2(TW, TH))
		cards_layer.add_child(u)
		deck_under.append(u)
	deck_node = CardNode.new().setup(-1, false, Vector2(TW, TH))
	deck_node.set_interactive(false, true)
	deck_node.tapped.connect(func(_n): _on_deck_tapped())
	cards_layer.add_child(deck_node)
	deck_lbl = _lbl("", 24)
	deck_lbl.size = Vector2(220, 40)
	table.add_child(deck_lbl)

	msg_panel = PanelContainer.new()
	var ms := StyleBoxFlat.new()
	ms.bg_color = Color(0.1, 0.05, 0.02, 0.82)
	ms.border_color = Color("#8a6230")
	ms.set_border_width_all(2)
	ms.set_corner_radius_all(22)
	ms.content_margin_left = 20
	ms.content_margin_right = 20
	ms.content_margin_top = 6
	ms.content_margin_bottom = 6
	msg_panel.add_theme_stylebox_override("panel", ms)
	msg_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	msg_lbl = _lbl("", 22)
	msg_panel.add_child(msg_lbl)
	table.add_child(msg_panel)

	suit_box = PanelContainer.new()
	var ss: StyleBoxFlat = ms.duplicate()
	ss.border_color = Color("#e0b44a")
	ss.set_border_width_all(3)
	suit_box.add_theme_stylebox_override("panel", ss)
	suit_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := HBoxContainer.new()
	sh.add_theme_constant_override("separation", 8)
	sh.add_child(_lbl("Hraje se:", 22))
	suit_icon = TextureRect.new()
	suit_icon.custom_minimum_size = Vector2(40, 40)
	suit_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	suit_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sh.add_child(suit_icon)
	suit_box.add_child(sh)
	table.add_child(suit_box)

	hint_lbl = _lbl("", 24)
	hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	table.add_child(hint_lbl)
	play_btn = _btn("Vyložit", _on_play_btn, 30)
	play_btn.visible = false
	table.add_child(play_btn)

	shout_lbl = _lbl("", 50, Color("#ffd76a"))
	shout_lbl.add_theme_color_override("font_outline_color", Color(0.35, 0.12, 0.0))
	shout_lbl.add_theme_constant_override("outline_size", 16)
	shout_lbl.visible = false
	fx_layer.add_child(shout_lbl)

	menu_btn = _btn("Menu", _confirm_leave, 22)
	menu_btn.position = Vector2(12, 10)
	table.add_child(menu_btn)


## Hand card scale: full size on tall phones (S21), smaller on 16:9 screens.
func _hs() -> float:
	return clampf((size.y / maxf(size.x, 1.0) - 1.6) / 0.62, 0.72, 1.0)


## Maps a reference y fraction (tuned for 20:9 screens) into the space above my open cards.
func _map_y(f: float) -> float:
	var top := size.y * 0.075
	var bottom := _my_open_y() - TH / 2.0 - 70.0
	return top + (f - 0.075) / (0.655 - 0.075) * (bottom - top)


func _pile_center() -> Vector2:
	return Vector2(size.x * 0.62, _map_y(0.455))


func _deck_center() -> Vector2:
	return Vector2(size.x * 0.40, _map_y(0.455))


func _my_open_y() -> float:
	return size.y - CH * _hs() - 50.0 - 30.0 * _hs() - TH / 2.0


func _seat_center(seat: int) -> Vector2:
	var n: int = view.get("n", 2)
	var me: int = view.get("seat", 0)
	var rel := (seat - me + n) % n
	if rel == 0:
		return Vector2(size.x / 2.0, _my_open_y())
	var key: String = LAYOUT[n - 1][rel - 1]
	var f: Vector2 = SLOT[key]
	return Vector2(f.x * size.x, _map_y(f.y))


func _seat_side(seat: int) -> String:
	var n: int = view.get("n", 2)
	var me: int = view.get("seat", 0)
	var rel := (seat - me + n) % n
	if rel == 0:
		return "B"
	return (LAYOUT[n - 1][rel - 1] as String).substr(0, 1)


func _relayout() -> void:
	if deck_node == null:
		return
	var dc := _deck_center()
	for i in deck_under.size():
		deck_under[i].position = dc - Vector2(TW, TH) / 2.0 + Vector2(-2.0 * (i + 1), -2.5 * (i + 1))
		deck_under[i].z_index = i
	deck_node.position = dc - Vector2(TW, TH) / 2.0
	deck_node.z_index = 6
	deck_lbl.position = dc + Vector2(-110, TH / 2.0 - 44)
	deck_lbl.z_index = 20
	shout_lbl.size = Vector2(size.x, 120)
	shout_lbl.position = Vector2(0, _deck_center().y - 60)
	shout_lbl.pivot_offset = shout_lbl.size / 2.0
	var y0 := dc.y + TH / 2.0 + 50.0
	var y1 := _my_open_y() - TH / 2.0 - 8.0
	hint_lbl.size = Vector2(size.x * 0.56, maxf(y1 - y0, 60.0))
	hint_lbl.position = Vector2(size.x * 0.22, y0)
	if not view.is_empty():
		_update_opponents()
		_layout_pile(false)
		_layout_hand(false)
		_update_indicators()
		_update_play_btn()


# =====================================================================
#  STARTING GAMES (local + host)
# =====================================================================
func _start_local() -> void:
	Net.leave()
	mode = "local"
	_fix_decks()
	seats = [{"kind": "me", "peer": 1, "name": my_name}]
	for i in seat_total - 1:
		seats.append({"kind": "bot", "peer": 0, "name": BOT_NAMES[i]})
	scores = {}
	var cfg := ConfigFile.new()
	cfg.load(SAVE)
	for i in seats.size():
		scores[_score_key(i)] = int(cfg.get_value("score", _score_key(i), 0))
	rules = Rules.new()
	next_dealer = -1
	_show("table")
	_begin_round()


func _limits() -> Dictionary:
	return {"n": seats.size(), "decks": deck_count, "max": Rules.max_per_player(seats.size(), deck_count)}


func _begin_round() -> void:
	bot_token += 1
	_clear_overlay()
	var d := next_dealer if next_dealer >= 0 and next_dealer < seats.size() else randi() % seats.size()
	pending_dealer = d
	var s: Dictionary = seats[d]
	var txt := "Rozdává %s…" % s["name"]
	for o in seats:
		if o["kind"] == "peer" and o != s:
			s_info.rpc_id(o["peer"], txt)
	if s["kind"] == "me":
		if auto.has("autoplay"):
			_deal(d, 4 + randi() % 3, 2 + randi() % 2)
		else:
			_show_deal_dialog(_limits(), func(h: int, o: int): _deal(d, h, o))
	elif s["kind"] == "peer":
		_info_wait(txt)
		s_deal_ask.rpc_id(s["peer"], _limits())
	else:
		_info_wait(txt)
		var tok := bot_token
		get_tree().create_timer(0.05 if auto.has("fast") else 1.2).timeout.connect(func():
			if tok == bot_token:
				var c := _bot_deal_choice()
				_deal(d, c[0], c[1]))


func _bot_deal_choice() -> Array:
	var tmp := Rules.new()
	tmp.n = seats.size()
	tmp.decks = deck_count
	tmp.rng.randomize()
	return tmp.ai_deal_choice()


func _deal(d: int, h: int, o: int) -> void:
	if rules == null or d != pending_dealer:
		return
	pending_dealer = -1
	round_id += 1
	bot_token += 1
	var names: Array = []
	for s in seats:
		names.append(s["name"])
	rules.new_game(names, d, h, o, deck_count)
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
		var delay := 0.8 + randf() * 0.6
		if auto.has("fast"):
			delay = 0.01
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
		rules.play(p, m["cards"], m["suit"])
	_push_views()


func _act_play(seat: int, cards: Array, suit: int) -> void:
	if rules == null:
		return
	if rules.play(seat, cards, suit):
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
	next_dealer = rules.loser
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
	var info := {"winner": w, "loser": rules.loser, "names": names, "scores": sc, "round": round_id,
		"dealer_name": seats[rules.loser]["name"]}
	for s in seats:
		if s["kind"] == "peer":
			s_end.rpc_id(s["peer"], info)
	var rid := round_id
	get_tree().create_timer(0.05 if auto.has("fast") else 1.4).timeout.connect(func():
		if rid == round_id and pending_dealer < 0:
			_show_end(info, true))
	if auto.has("games"):
		auto["played"] = int(auto.get("played", 0)) + 1
		print("AUTO_GAME_END winner=", seats[w]["name"], " loser=", seats[rules.loser]["name"], " n=", seats.size(), " played=", auto["played"])
		if auto["played"] >= int(auto["games"]):
			print("AUTO_DONE scores=", scores)
			get_tree().create_timer(0.5).timeout.connect(func(): get_tree().quit())
		else:
			get_tree().create_timer(0.1).timeout.connect(func():
				if mode == "local" or mode == "host":
					_begin_round())


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
	rules = null
	seat_total = maxi(seat_total, 2)
	_fix_decks()
	_refresh_lobby()
	_show("lobby")


func _refresh_lobby() -> void:
	if mode != "host":
		return
	seat_total = clampi(seat_total, maxi(2, 1 + lobby_peers.size()), 10)
	_fix_decks()
	lobby_seats_val.text = str(seat_total)
	lobby_decks_val.text = str(deck_count)
	var ips := Net.local_ips()
	lobby_info.text = "Stůl „%s“ je vidět na Wi-Fi.\nIP: %s" % [my_name, ", ".join(ips) if not ips.is_empty() else "není Wi-Fi?"]
	var lines: Array = ["• " + my_name + " (ty)"]
	for id in lobby_peers:
		lines.append("• " + lobby_peers[id])
	var bots := seat_total - 1 - lobby_peers.size()
	if bots > 0:
		lines.append("• + %d× počítač" % bots)
	if lobby_peers.is_empty():
		lines.append("Čekám na další hráče…")
	lobby_players.text = "\n".join(lines)
	var info := {"table": my_name, "players": lines}
	for id in lobby_peers:
		s_lobby.rpc_id(id, info)


func _host_start_game() -> void:
	if mode != "host":
		return
	_fix_decks()
	seats = [{"kind": "me", "peer": 1, "name": my_name}]
	var used := {my_name: true}
	for id in lobby_peers:
		var nm: String = lobby_peers[id]
		while used.has(nm):
			nm += "*"
		used[nm] = true
		seats.append({"kind": "peer", "peer": id, "name": nm})
	var bi := 0
	while seats.size() < seat_total and bi < 40:
		var bn: String = BOT_NAMES[bi % BOT_NAMES.size()]
		if bi >= BOT_NAMES.size():
			bn += str(bi / BOT_NAMES.size() + 1)
		bi += 1
		if used.has(bn):
			continue
		used[bn] = true
		seats.append({"kind": "bot", "peer": 0, "name": bn})
	for i in seats.size():
		scores[seats[i]["name"]] = int(scores.get(seats[i]["name"], 0))
	rules = Rules.new()
	next_dealer = -1
	_show("table")
	_begin_round()


func _on_peer_disconnected(id: int) -> void:
	if mode != "host":
		return
	if not lobby_peers.has(id):
		return
	var nm: String = lobby_peers[id]
	lobby_peers.erase(id)
	if rules == null:
		_refresh_lobby()
		return
	for i in seats.size():
		if seats[i]["kind"] == "peer" and seats[i]["peer"] == id:
			seats[i]["kind"] = "bot"
			_toast("%s odešel – hraje za něj počítač." % nm)
			if pending_dealer == i:
				var c := _bot_deal_choice()
				_deal(i, c[0], c[1])
			elif rules.winner < 0 and rules.cur == i:
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
	if mode == "client":
		return
	for ip in Net.found:
		var nm: String = Net.found[ip]["name"]
		finder_list.add_child(_btn("Bar „%s“  (%s)" % [nm, ip], func(): _join(ip), 28))
	if Net.found.is_empty():
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
	_refresh_finder()
	if Net.join(ip) != OK:
		mode = ""
		_finder_msg("Nepodařilo se připojit.")


func _on_joined() -> void:
	_finder_msg("Připojeno! Čekáme, až hostitel začne…")
	c_hello.rpc_id(1, my_name)


func _on_lost_server() -> void:
	if mode == "client":
		mode = ""
		_clear_overlay()
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
	if rules != null:
		s_kick.rpc_id(id, "Hra už běží, počkej na další stůl.")
		return
	if lobby_peers.size() >= 9:
		s_kick.rpc_id(id, "Bar je plný.")
		return
	lobby_peers[id] = nm
	_sfx("turn")
	_refresh_lobby()
	if auto.has("autohost") and lobby_peers.size() >= int(auto.get("wait", "1")):
		get_tree().create_timer(0.6).timeout.connect(func():
			if rules == null:
				_host_start_game())


@rpc("authority", "call_remote", "reliable")
func s_lobby(info: Dictionary) -> void:
	if mode != "client":
		return
	_finder_msg("Bar „%s“\n%s\n\nČekáme, až hostitel začne…" % [info.get("table", "?"), "\n".join(info.get("players", []))])


@rpc("authority", "call_remote", "reliable")
func s_kick(reason: String) -> void:
	Net.leave()
	mode = ""
	_show("menu")
	_toast(reason)


@rpc("authority", "call_remote", "reliable")
func s_info(t: String) -> void:
	if mode != "client":
		return
	if table.visible:
		_info_wait(t)
	else:
		_finder_msg(t)


@rpc("authority", "call_remote", "reliable")
func s_deal_ask(lim: Dictionary) -> void:
	if mode != "client":
		return
	_show("table")
	if auto.has("autoplay"):
		c_deal.rpc_id(1, 4 + randi() % 3, 2 + randi() % 2)
		return
	_show_deal_dialog(lim, func(h: int, o: int): c_deal.rpc_id(1, h, o))


@rpc("any_peer", "call_remote", "reliable")
func c_deal(h: int, o: int) -> void:
	if mode != "host":
		return
	var s := _seat_of_peer(multiplayer.get_remote_sender_id())
	if s >= 0 and s == pending_dealer:
		_deal(s, h, o)


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
	get_tree().create_timer(0.05 if auto.has("fast") else 1.4).timeout.connect(func():
		if int(view.get("round", -1)) == rid:
			_show_end(info, false))
	if auto.has("games"):
		auto["played"] = int(auto.get("played", 0)) + 1
		print("AUTO_CLIENT_END winner=", info["names"][info["winner"]], " played=", auto["played"])


@rpc("any_peer", "call_remote", "reliable")
func c_play(cards: Array, suit: int) -> void:
	if mode != "host":
		return
	var s := _seat_of_peer(multiplayer.get_remote_sender_id())
	if s >= 0:
		_act_play(s, cards, suit)


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


func _my_open() -> Array:
	return view["opens"][view["seat"]] if not view.is_empty() else []


func _can_play_view(c: int) -> bool:
	var d: Array = view["discard"]
	return Rules.can_play_on(c, d.back(), view["top_suit"], view["penalty"], view["ace_stop"])


func _group_ok(cards: Array) -> Array:
	var d: Array = view["discard"]
	return Rules.order_group(cards, d.back(), view["top_suit"], view["penalty"], view["ace_stop"])


func _send_play(cards: Array, suit: int) -> void:
	sel = []
	var i := 0
	for c in cards:
		if hand_nodes.has(c):
			var nd: CardNode = hand_nodes[c]
			nd.z_index = 150 + i
			nd.move_to(_pile_center() - Vector2(CW, CH) / 2.0, 0.0, 0.18, TW / CW, i * 0.05)
			i += 1
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(25)
	if mode == "client":
		c_play.rpc_id(1, cards, suit)
	else:
		_act_play(view["seat"], cards, suit)


func _send_pass() -> void:
	sel = []
	if mode == "client":
		c_pass.rpc_id(1)
	else:
		_act_pass(view["seat"])


func _try_play(cards: Array) -> void:
	if not _my_turn() or waiting_suit:
		_reject(cards, "Teď nejsi na tahu.")
		return
	var group := _group_ok(cards)
	if group.is_empty():
		_reject(cards, "Tohle teď dát nejde." if cards.size() == 1 else "Tyhle karty teď dát nejdou.")
		return
	if Rules.rank_of(group[0]) == Rules.RQ:
		_ask_suit(group)
	else:
		_send_play(group, -1)


func _reject(cards: Array, why: String) -> void:
	_sfx("bad")
	_set_msg(why)
	_layout_hand(true)
	for c in cards:
		if hand_nodes.has(c):
			var nd: CardNode = hand_nodes[c]
			get_tree().create_timer(0.26).timeout.connect(func():
				if is_instance_valid(nd):
					nd.shake())


func _on_card_dropped(nd: CardNode, pos: Vector2, vel: Vector2, travel: Vector2) -> void:
	var pc := _pile_center()
	var pile_rect := Rect2(pc - Vector2(TW, TH) * 1.1, Vector2(TW, TH) * 2.2)
	var flick := vel.y < -550.0 and travel.y < -40.0
	var lifted := travel.y < -150.0
	if pile_rect.has_point(pos) or flick or lifted:
		var group: Array = sel.duplicate() if sel.has(nd.card) else [nd.card]
		_try_play(group)
	else:
		_layout_hand(true)


func _on_card_tapped(nd: CardNode) -> void:
	var c := nd.card
	if sel.has(c):
		sel.erase(c)
	elif not sel.is_empty() and Rules.rank_of(sel[0]) != Rules.rank_of(c):
		sel = [c]
	else:
		sel.append(c)
	_sfx("draw")
	_layout_hand(true)
	_update_play_btn()


func _on_play_btn() -> void:
	if not sel.is_empty():
		_try_play(sel.duplicate())


func _update_play_btn() -> void:
	if play_btn == null:
		return
	var show := not sel.is_empty() and _my_turn() and not waiting_suit
	play_btn.visible = show
	hint_lbl.visible = not show
	if show:
		var r := Rules.rank_of(sel[0])
		play_btn.text = ("Vyložit %s" % ACC[r]) if sel.size() == 1 else ("Vyložit %d× %s" % [sel.size(), ACC_PL[r]])
		play_btn.disabled = _group_ok(sel).is_empty()
		play_btn.reset_size()
		var y0 := _deck_center().y + TH / 2.0 + 50.0
		var y1 := _my_open_y() - TH / 2.0 - 8.0
		play_btn.position = Vector2(size.x / 2.0 - play_btn.size.x / 2.0, (y0 + y1) / 2.0 - play_btn.size.y / 2.0)


func _on_deck_tapped() -> void:
	if not _my_turn() or waiting_suit:
		return
	_send_pass()


func _ask_suit(group: Array) -> void:
	waiting_suit = true
	_update_play_btn()
	var a := _overlay_panel(560)
	var v: VBoxContainer = a[1]
	v.add_child(_lbl("Svršek!" if group.size() == 1 else "%d svršci!" % group.size(), 54, Color("#f3d48a")))
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
			_send_play(group, s))
		g.add_child(b)
	v.add_child(g)
	v.add_child(_btn("Zpět", func():
		waiting_suit = false
		_clear_overlay()
		_layout_hand(true)
		_update_play_btn(), 28))


func _show_deal_dialog(lim: Dictionary, done: Callable) -> void:
	var n: int = lim["n"]
	var decks: int = lim["decks"]
	var mx: int = lim["max"]
	var st := {"h": mini(5, mx - 2), "o": 2}
	var a := _overlay_panel(600)
	var v: VBoxContainer = a[1]
	v.add_child(_lbl("Rozdáváš ty", 56, Color("#f3d48a")))
	var dn := "balíček" if decks == 1 else ("balíčky" if decks < 5 else "balíčků")
	v.add_child(_lbl("%d hráčů · %d %s (%d karet)" % [n, decks, dn, decks * 32], 26, Color("#e9d6a8")))
	var info := _lbl("", 24, Color("#e9d6a8"), 520)
	var vals := {}
	var refresh := func():
		st["h"] = clampi(st["h"], Rules.MIN_HAND, mx - Rules.MIN_OPEN)
		st["o"] = clampi(st["o"], Rules.MIN_OPEN, mx - st["h"])
		if vals.has("h"):
			vals["h"].text = str(st["h"])
		if vals.has("o"):
			vals["o"].text = str(st["o"])
		var dealt: int = n * (st["h"] + st["o"])
		info.text = "Rozdá se %d karet · v balíku zbude %d\nmax. %d karet na hráče" % [dealt, decks * 32 - dealt - 1, mx]
	vals["h"] = _stepper(v, "Do ruky", func(): return st["h"], func(x: int):
		st["h"] = x
		refresh.call(), "minimálně 4")
	vals["o"] = _stepper(v, "Otevřeně na stůl", func(): return st["o"], func(x: int):
		st["o"] = x
		refresh.call(), "minimálně 2")
	v.add_child(info)
	refresh.call()
	v.add_child(_btn("Rozdat karty", func():
		_clear_overlay()
		done.call(st["h"], st["o"])))


# =====================================================================
#  RENDERING A VIEW
# =====================================================================
func apply_view(v: Dictionary) -> void:
	var prev := view
	view = v
	if deck_node.position == Vector2.ZERO:
		_relayout()
	var ev: Dictionary = v.get("ev", {})
	var new_round: bool = int(v.get("round", 0)) != shown_round
	if new_round:
		shown_round = int(v.get("round", 0))
		_clear_overlay()
		waiting_suit = false
		sel = []
		_sfx("shuffle")
		prev = {}
	_update_opponents()
	_update_pile(v, new_round)
	_update_hand(v, new_round)
	_update_indicators()
	_announce(prev, v, new_round)
	if not new_round and int(ev.get("seq", -1)) != int(prev.get("ev", {}).get("seq", -2)):
		if ev.get("type", "") == "pass" and ev.get("kind", "") == "draw" and ev["seat"] != v["seat"]:
			_fly_backs(ev["seat"], int(ev.get("count", 1)))
	_update_play_btn()
	if auto.has("autoplay") and _my_turn():
		var rid: int = int(v.get("round", 0))
		var sq: int = int(ev.get("seq", 0))
		get_tree().create_timer(0.03).timeout.connect(func():
			if _my_turn() and int(view.get("round", 0)) == rid and int(view["ev"].get("seq", 0)) == sq:
				_auto_move())


func _auto_move() -> void:
	var mine: Array = (view["hand"] as Array) + _my_open()
	for c in mine:
		if _can_play_view(c):
			var group: Array = [c]
			for k in mine:
				if k != c and Rules.rank_of(k) == Rules.rank_of(c):
					group.append(k)
			_send_play(group, Rules.suit_of(mine[0]) if Rules.rank_of(c) == Rules.RQ else -1)
			return
	_send_pass()


func _clear_table() -> void:
	for c in hand_nodes.values():
		c.queue_free()
	hand_nodes.clear()
	hand_order.clear()
	open_order.clear()
	for p in pile_nodes:
		p.queue_free()
	pile_nodes.clear()
	for c in opp_layer.get_children():
		c.queue_free()
	view = {}
	shown_round = -1
	anim_seq = -1
	sel = []
	if play_btn:
		play_btn.visible = false


func _pile_offset(c: int, k: int) -> Array:
	var r := deg_to_rad(float((c * 37 + k * 13) % 25 - 12))
	var off := Vector2(float((c * 7 + k * 5) % 13 - 6), float((c * 11 + k * 3) % 11 - 5))
	return [off, r]


func _update_pile(v: Dictionary, new_round: bool) -> void:
	var disc: Array = v["discard"]
	var ev: Dictionary = v.get("ev", {})
	var sq: int = int(ev.get("seq", 0))
	if new_round or pile_nodes.is_empty():
		for p in pile_nodes:
			p.queue_free()
		pile_nodes.clear()
		for i in disc.size():
			var nd := CardNode.new().setup(disc[i], true, Vector2(TW, TH))
			cards_layer.add_child(nd)
			pile_nodes.append(nd)
		_layout_pile(false)
		anim_seq = sq
		if new_round and not pile_nodes.is_empty():
			var t: CardNode = pile_nodes.back()
			var target := t.position
			t.position = _deck_center() - Vector2(TW, TH) / 2.0
			t.move_to(target, t.rotation, 0.4, 1.0, 0.6)
		return
	if sq == anim_seq or ev.get("type", "") != "play":
		anim_seq = sq
		return
	anim_seq = sq
	var src := _seat_center(int(ev.get("seat", 0)))
	var k := 0
	for c in ev.get("cards", []):
		var nd: CardNode = CardNode.new().setup(c, true, Vector2(TW, TH))
		cards_layer.add_child(nd)
		if hand_nodes.has(c):
			var hn: CardNode = hand_nodes[c]
			nd.scale = Vector2.ONE * (hn.scale.x * CW / TW)
			nd.position = hn.position + (Vector2(CW, CH) - Vector2(TW, TH)) / 2.0
			nd.rotation = hn.rotation
			hand_nodes.erase(c)
			hand_order.erase(c)
			open_order.erase(c)
			hn.queue_free()
		else:
			nd.position = src - Vector2(TW, TH) / 2.0
			nd.scale = Vector2(0.5, 0.5)
			nd.rotation = randf_range(-0.6, 0.6)
		nd.set_meta("delay", k * 0.09)
		pile_nodes.append(nd)
		k += 1
	while pile_nodes.size() > 8:
		pile_nodes.pop_front().queue_free()
	_layout_pile(true, k)
	_sfx("slap")


func _layout_pile(anim: bool, fresh: int = 1) -> void:
	var base := _pile_center() - Vector2(TW, TH) / 2.0
	for i in pile_nodes.size():
		var nd: CardNode = pile_nodes[i]
		var o := _pile_offset(nd.card, i)
		nd.z_index = 10 + i
		if anim and i >= pile_nodes.size() - fresh:
			var d: float = nd.get_meta("delay", 0.0)
			nd.set_meta("delay", 0.0)
			nd.move_to(base + o[0], o[1], 0.3, 1.0, d)
		else:
			nd.position = base + o[0]
			nd.rotation = o[1]
			nd.scale = Vector2.ONE


func _update_hand(v: Dictionary, new_round: bool) -> void:
	var hand: Array = v["hand"].duplicate()
	hand.sort_custom(func(a, b): return Rules.base_of(a) < Rules.base_of(b) or (Rules.base_of(a) == Rules.base_of(b) and a < b))
	var opn: Array = (v["opens"][v["seat"]] as Array).duplicate()
	if new_round:
		for c in hand_nodes.values():
			c.queue_free()
		hand_nodes.clear()
	var all := hand + opn
	for c in hand_nodes.keys():
		if not all.has(c):
			hand_nodes[c].queue_free()
			hand_nodes.erase(c)
	var k := 0
	var new_cards := false
	for c in all:
		if not hand_nodes.has(c):
			var nd := CardNode.new().setup(c, true, Vector2(CW, CH))
			nd.position = _deck_center() - Vector2(CW, CH) / 2.0
			nd.scale = Vector2.ONE * (TW / CW)
			nd.set_interactive(true, true)
			nd.dropped.connect(_on_card_dropped)
			nd.tapped.connect(_on_card_tapped)
			nd.set_meta("delay", (0.7 if new_round else 0.0) + k * 0.07)
			cards_layer.add_child(nd)
			hand_nodes[c] = nd
			k += 1
			new_cards = true
	hand_order = hand
	open_order = opn
	if new_cards and not new_round:
		_sfx("draw")
	var keep: Array = []
	for c in sel:
		if all.has(c):
			keep.append(c)
	sel = keep
	_layout_hand(true)


func _layout_hand(anim: bool) -> void:
	var my := _my_turn() and not waiting_suit
	# --- hand: arc at the bottom ---
	var n := hand_order.size()
	var hs := _hs()
	if n > 0:
		var cw := CW * hs
		var maxw := size.x - 24.0
		var step: float = cw * 0.62 if n == 1 else minf(cw * 0.62, (maxw - cw) / float(n - 1))
		var total := cw + step * (n - 1)
		var cx0 := (size.x - total) / 2.0 + cw / 2.0
		var cy := size.y - CH * hs / 2.0 - 50.0
		var spread := minf(0.22, 0.03 * n)
		for i in n:
			var c: int = hand_order[i]
			var t := 0.0 if n == 1 else (float(i) - (n - 1) / 2.0) / ((n - 1) / 2.0)
			var ctr := Vector2(cx0 + step * i, cy + t * t * 24.0)
			if sel.has(c):
				ctr.y -= 46.0 * hs
			_place_mine(c, ctr - Vector2(CW, CH) / 2.0, t * spread, hs, 60 + i, my, anim)
	# --- my open cards on the bar ---
	var m := open_order.size()
	if m > 0:
		var sc := TW / CW
		var maxw2 := size.x * 0.62
		var step2: float = minf(TW + 14.0, (maxw2 - TW) / maxf(m - 1, 1))
		var total2 := TW + step2 * (m - 1)
		var cy := _my_open_y()
		for i in m:
			var c: int = open_order[i]
			var cx := size.x / 2.0 - total2 / 2.0 + TW / 2.0 + step2 * i
			var pos := Vector2(cx, cy) - Vector2(CW, CH) / 2.0
			if sel.has(c):
				pos.y -= 26.0
			_place_mine(c, pos, (float(i) - (m - 1) / 2.0) * 0.03, sc, 30 + i, my, anim)


func _place_mine(c: int, pos: Vector2, rot: float, sc: float, z: int, my: bool, anim: bool) -> void:
	var nd: CardNode = hand_nodes[c]
	if nd.is_dragging():
		return
	nd.z_index = z
	var ok := my and _can_play_view(c)
	nd.set_glow(ok or sel.has(c))
	nd.modulate = Color(1, 1, 1) if (not my or ok or sel.has(c)) else Color(0.66, 0.66, 0.66)
	var d: float = nd.get_meta("delay", 0.0)
	nd.set_meta("delay", 0.0)
	if anim:
		nd.move_to(pos, rot, 0.28, sc, d)
	else:
		nd.position = pos
		nd.rotation = rot
		nd.scale = Vector2.ONE * sc


func _update_opponents() -> void:
	for c in opp_layer.get_children():
		c.queue_free()
	var n: int = view.get("n", 0)
	var me: int = view.get("seat", 0)
	for s in n:
		if s == me:
			_dealer_chip_for_me()
			continue
		var cen := _seat_center(s)
		var side := _seat_side(s)
		# hand: small backs hanging over the bar edge
		var cnt: int = view["counts"][s]
		var shown := mini(cnt, 7)
		for i in shown:
			var b := TextureRect.new()
			b.texture = BACK
			b.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			b.stretch_mode = TextureRect.STRETCH_SCALE
			b.size = Vector2(30, 46)
			b.pivot_offset = b.size / 2.0
			b.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.material = CardNode._mat
			var t := 0.0 if shown == 1 else (float(i) - (shown - 1) / 2.0) / ((shown - 1) / 2.0)
			if side == "L":
				b.position = Vector2(4, cen.y - 23 + t * 26.0)
				b.rotation = PI / 2.0 + t * 0.25
			elif side == "R":
				b.position = Vector2(size.x - 34, cen.y - 23 + t * 26.0)
				b.rotation = -PI / 2.0 + t * 0.25
			else:
				b.position = Vector2(cen.x - 15 + t * 30.0, cen.y - OH / 2.0 - 46)
				b.rotation = PI + t * 0.25
			opp_layer.add_child(b)
		# open cards face up
		var opn: Array = view["opens"][s]
		var m := opn.size()
		if m > 0:
			var maxw := size.x * 0.27
			var step: float = minf(OW + 6.0, (maxw - OW) / maxf(m - 1, 1))
			var total := OW + step * (m - 1)
			for i in m:
				var c := TextureRect.new()
				c.texture = load(Rules.texture_path(opn[i]))
				c.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				c.stretch_mode = TextureRect.STRETCH_SCALE
				c.size = Vector2(OW, OH)
				c.pivot_offset = c.size / 2.0
				c.rotation = (float(i) - (m - 1) / 2.0) * 0.06
				c.position = Vector2(cen.x - total / 2.0 + step * i, cen.y - OH / 2.0)
				c.material = CardNode._mat
				c.mouse_filter = Control.MOUSE_FILTER_IGNORE
				opp_layer.add_child(c)
		# name tag
		var active: bool = view["cur"] == s and view["winner"] < 0
		var tag := PanelContainer.new()
		var st := StyleBoxFlat.new()
		st.bg_color = Color("#dcae45") if active else Color(0.1, 0.05, 0.02, 0.85)
		st.border_color = Color("#ffe39a") if active else Color("#8a6230")
		st.set_border_width_all(2)
		st.set_corner_radius_all(15)
		st.content_margin_left = 12
		st.content_margin_right = 12
		st.content_margin_top = 3
		st.content_margin_bottom = 3
		if active:
			st.shadow_color = Color(1, 0.8, 0.3, 0.6)
			st.shadow_size = 12
		tag.add_theme_stylebox_override("panel", st)
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var txt: String = "%s · %d" % [view["names"][s], cnt]
		if view["dealer"] == s:
			txt += "  (R)"
		var l := _lbl(txt, 21, Color("#2a1500") if active else Color("#f6e7c1"))
		if active:
			l.add_theme_constant_override("outline_size", 0)
		tag.add_child(l)
		opp_layer.add_child(tag)
		tag.reset_size()
		tag.position = Vector2(clampf(cen.x - tag.size.x / 2.0, 4.0, size.x - tag.size.x - 4.0), cen.y + OH / 2.0 + 6.0)


func _dealer_chip_for_me() -> void:
	if view["dealer"] != view["seat"]:
		return
	var l := _lbl("rozdával jsi", 18, Color("#d8c393"))
	l.size = Vector2(200, 24)
	l.position = Vector2(size.x / 2.0 - 100, _my_open_y() + TH / 2.0 + 2.0)
	opp_layer.add_child(l)


func _fly_backs(seat: int, count: int) -> void:
	var target := _seat_center(seat) - Vector2(TW, TH) / 2.0
	for i in mini(count, 5):
		var b := CardNode.new().setup(-1, false, Vector2(TW, TH))
		b.position = _deck_center() - Vector2(TW, TH) / 2.0
		b.z_index = 120
		fx_layer.add_child(b)
		var tw := b.move_to(target, randf_range(-0.4, 0.4), 0.35, 0.35, i * 0.07)
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
		suit_box.position = Vector2(pc.x - suit_box.size.x / 2.0 + 10.0, pc.y + TH / 2.0 + 6.0)
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
	for c in (view["hand"] as Array) + _my_open():
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
			hint_lbl.text = "Tvůj tah – táhni kartu na stůl. Víc stejných: ťukni na ně a vylož."
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
		var who := "Rozdával jsi ty" if v["dealer"] == me else "Rozdával %s" % _who(v["dealer"])
		_set_msg("%s (%d + %d). %s." % [who, int(ev.get("hand_n", 4)), int(ev.get("open_n", 2)), "Začínáš ty" if v["cur"] == me else "Začíná " + _who(v["cur"])])
		if v["penalty"] > 0:
			_shout("Sedma na stole!")
		elif v["ace_stop"]:
			_shout("Eso na stole!")
		if v["cur"] == me:
			_sfx("turn")
		return
	if prev.is_empty():
		return
	if int(ev.get("seq", -1)) == int(prev.get("ev", {}).get("seq", -2)):
		return
	var s: int = ev.get("seat", -1)
	var mine := s == me
	if t == "play":
		var cards: Array = ev["cards"]
		var r := Rules.rank_of(cards[0])
		var desc: String
		if cards.size() == 1:
			desc = "%s %s" % [ACC[r], Rules.SUIT_NAMES[Rules.suit_of(cards[0])].to_lower()]
		else:
			desc = "%d× %s" % [cards.size(), ACC_PL[r]]
		_set_msg(("Dal jsi " + desc) if mine else ("%s dal %s" % [_who(s), desc]))
		if ev.get("win", false):
			_shout("Prší! Vyhrál jsi!" if mine else "Prší! %s je venku" % _who(s))
		elif r == Rules.R7:
			if cards.size() == 1:
				_shout("Sedma! Bere se %d" % int(ev.get("penalty", 2)))
			else:
				_shout("%d sedmy! Bere se %d" % [cards.size(), int(ev.get("penalty", 2))])
		elif r == Rules.RA:
			_shout("Eso – stůj!")
		elif r == Rules.RQ:
			_shout("Svršek – na %s!" % Rules.SUIT_NAMES[int(ev["suit"])].to_lower())
		elif int(ev.get("left", 9)) == 1:
			_shout("Poslední karta!" if mine else "%s má poslední!" % _who(s))
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
	msg_panel.position = Vector2(size.x / 2.0 - msg_panel.size.x / 2.0, _deck_center().y - TH / 2.0 - msg_panel.size.y - 16.0)
	msg_panel.modulate = Color(1, 1, 1, 0)
	create_tween().tween_property(msg_panel, "modulate", Color.WHITE, 0.2)


func _shout(t: String) -> void:
	shout_lbl.text = t
	shout_lbl.visible = true
	shout_lbl.scale = Vector2(0.3, 0.3)
	shout_lbl.modulate = Color.WHITE
	var tw := create_tween()
	tw.tween_property(shout_lbl, "scale", Vector2(1.12, 1.12), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
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
	v.add_theme_constant_override("separation", 16)
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


func _info_wait(t: String) -> void:
	var a := _overlay_panel(520)
	var v: VBoxContainer = a[1]
	v.add_child(_lbl(t, 40, Color("#f3d48a"), 460))
	v.add_child(_lbl("Míchá se…", 24, Color("#e9d6a8")))


func _show_end(info: Dictionary, controls: bool) -> void:
	var w: int = info["winner"]
	var me: int = view.get("seat", -1)
	var won := w == me
	_sfx("win" if won else "lose")
	var a := _overlay_panel(580)
	var v: VBoxContainer = a[1]
	v.add_child(_lbl("Prší! Vyhrál jsi!" if won else "Vyhrál %s" % info["names"][w], 48, Color("#f3d48a"), 520))
	var lo: int = info.get("loser", -1)
	if lo >= 0:
		v.add_child(_lbl("Nejvíc karet zbylo: %s – příště rozdává." % ("tobě" if lo == me else info["dealer_name"]), 24, Color("#e9d6a8"), 520))
	var lines: Array = []
	for i in (info["names"] as Array).size():
		lines.append("%s:  %d" % [info["names"][i], int(info["scores"][i])])
	v.add_child(_lbl("Skóre\n" + "\n".join(lines), 26))
	if controls:
		v.add_child(_btn("Další runda", _begin_round))
	else:
		v.add_child(_lbl("Čekáme na další rundu…", 24, Color("#d8c393"), 500))
	v.add_child(_btn("Do menu", _go_menu, 28))
	v.add_child(_lbl("Karty: foto Countakeshi, Wikimedia Commons, CC BY-SA 4.0", 16, Color(1, 1, 1, 0.55), 500))


func _confirm_leave() -> void:
	var a := _overlay_panel(520)
	var v: VBoxContainer = a[1]
	v.add_child(_lbl("Odejít od baru?", 44, Color("#f3d48a")))
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
	pending_dealer = -1
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
			elif pending_dealer < 0:
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
		seat_total = clampi(int(cfg.get_value("player", "seats", seat_total)), 2, 10)
		deck_count = clampi(int(cfg.get_value("player", "decks", deck_count)), 1, 5)


func _save_cfg() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE)
	cfg.set_value("player", "name", my_name)
	cfg.set_value("player", "sound", sound_on)
	cfg.set_value("player", "seats", seat_total)
	cfg.set_value("player", "decks", deck_count)
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
	# Test hooks: --autolocal=N --decks=D --autohost --seats=N --wait=K --autojoin=IP|discover --games=N --fast --autoplay --name=X --shot=path
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=")
		auto[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if auto.is_empty():
		return
	if auto.has("name"):
		my_name = auto["name"]
	if auto.has("decks"):
		deck_count = int(auto["decks"])
	if auto.has("seats"):
		seat_total = int(auto["seats"])
	if auto.has("autolocal"):
		seat_total = int(auto["autolocal"])
		_start_local()
	elif auto.has("autohost"):
		_open_host()
	elif auto.has("autojoin"):
		_open_finder()
		if auto["autojoin"] == "discover":
			Net.tables_changed.connect(func():
				if mode == "" and not Net.found.is_empty():
					_join(Net.found.keys()[0]))
		else:
			_join(auto["autojoin"])
	if auto.has("inputtest"):
		_input_test(auto["inputtest"])
	if auto.has("dealshot"):
		get_tree().create_timer(0.3).timeout.connect(func(): _show_deal_dialog({"n": 10, "decks": 5, "max": 13}, func(_h, _o): pass))
	if auto.has("shot"):
		get_tree().create_timer(float(auto.get("shotdelay", "3"))).timeout.connect(func():
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(auto["shot"])
			print("SHOT_SAVED")
			if not auto.has("games"):
				get_tree().quit())


# ---------- input self-test (drag / swipe / tap / side / multi) ----------
func _input_test(kind: String) -> void:
	for i in 600:
		await get_tree().create_timer(0.05).timeout
		if _my_turn() and not waiting_suit and overlay == null:
			var c := -1
			var mine: Array = hand_order + open_order
			for k in mine:
				if _can_play_view(k) and Rules.rank_of(k) != Rules.RQ:
					c = k
			var twin := -1
			if c >= 0 and kind == "multi":
				for k in mine:
					if k != c and Rules.rank_of(k) == Rules.rank_of(c):
						twin = k
				if twin < 0:
					c = -1
			if c >= 0:
				await get_tree().create_timer(0.9).timeout
				var nd: CardNode = hand_nodes[c]
				var a := nd.position + nd.size * nd.scale / 2.0 + (nd.size - nd.size * nd.scale) / 2.0
				var b := _pile_center() if kind == "drag" else (a + Vector2(130, -25) if kind == "side" else a + Vector2(0, -170))
				var before: int = (view["hand"] as Array).size() + _my_open().size()
				if kind == "tap" or kind == "multi":
					await _tap(a)
					if kind == "multi":
						var nd2: CardNode = hand_nodes[twin]
						await get_tree().create_timer(0.4).timeout
						await _tap(nd2.position + nd2.size / 2.0)
					await get_tree().create_timer(0.4).timeout
					await _tap(play_btn.position + play_btn.size / 2.0)
				else:
					await _mouse(a, true)
					var steps := 10 if kind == "drag" else 3
					for j in steps:
						await _move(a.lerp(b, float(j + 1) / steps))
					await _mouse(b, false)
				await get_tree().create_timer(1.0).timeout
				var after: int = (view["hand"] as Array).size() + _my_open().size()
				var expect := before - (2 if kind == "multi" else 1)
				var ok: bool = after == expect or int(view["winner"]) >= 0
				if kind == "side":
					ok = after == before
				print("INPUTTEST ", kind, " card=", Rules.card_name(c), " ", before, "->", after, " -> ", "OK" if ok else "FAIL")
				get_tree().quit()
				return
			if kind != "multi" or i % 10 == 0:
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


# =====================================================================
#  UPDATES (APK from GitHub; disabled in a Google Play build)
# =====================================================================
func _app_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "2.0"))


static func version_number(v: String) -> int:
	## "Prší 2.45" / "2.45" -> 45
	var m := RegEx.create_from_string("2\\.(\\d+)").search(v)
	return int(m.get_string(1)) if m else 0


func _check_update() -> void:
	if OS.has_feature("play_store") or not (OS.has_feature("android") or auto.has("updtest")):
		return
	var http := HTTPRequest.new()
	add_child(http)
	http.timeout = 10.0
	http.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body: PackedByteArray):
		http.queue_free()
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			return
		var d = JSON.parse_string(body.get_string_from_utf8())
		if not (d is Dictionary):
			return
		var remote := version_number(str(d.get("name", "")))
		var local := version_number(_app_version())
		if auto.has("updtest"):
			print("UPDATE_CHECK local=", local, " remote=", remote)
		if remote > local and local > 0:
			update_btn.text = "Stáhnout novou verzi 2.%d" % remote
			update_btn.visible = true)
	http.request(str(auto.get("updurl", RELEASE_API)), ["User-Agent: PrsiApp", "Accept: application/vnd.github+json"])
