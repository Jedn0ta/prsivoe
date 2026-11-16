class_name CardNode
extends Panel
## One playing card on the table. Supports drag, flick (swipe) and tap.

signal dropped(node: CardNode, pos: Vector2, velocity: Vector2, travel: Vector2)
signal tapped(node: CardNode)
signal grabbed(node: CardNode)

const BACK: Texture2D = preload("res://img/back.png")
const SHADER: Shader = preload("res://card.gdshader")

static var _style_normal: StyleBoxFlat
static var _style_glow: StyleBoxFlat
static var _mat: ShaderMaterial

var card: int = -1
var face_up: bool = true
var draggable: bool = false
var tappable: bool = false
var tex: TextureRect

var _down := false
var _dragging := false
var _press := Vector2.ZERO
var _grab := Vector2.ZERO
var _last := Vector2.ZERO
var _last_t := 0
var _vel := Vector2.ZERO
var _tw: Tween


static func _ensure_styles() -> void:
	if _style_normal != null:
		return
	_style_normal = StyleBoxFlat.new()
	_style_normal.bg_color = Color(0.95, 0.93, 0.87)
	_style_normal.set_corner_radius_all(9)
	_style_normal.shadow_color = Color(0, 0, 0, 0.45)
	_style_normal.shadow_size = 9
	_style_normal.shadow_offset = Vector2(0, 5)
	_style_glow = _style_normal.duplicate()
	_style_glow.border_color = Color(1.0, 0.82, 0.32)
	_style_glow.set_border_width_all(5)
	_style_glow.set_expand_margin_all(5)
	_style_glow.set_corner_radius_all(13)
	_style_glow.shadow_color = Color(1.0, 0.75, 0.2, 0.55)
	_style_glow.shadow_size = 16
	_style_glow.shadow_offset = Vector2.ZERO
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER


func setup(c: int, up: bool, sz: Vector2) -> CardNode:
	_ensure_styles()
	card = c
	face_up = up
	size = sz
	pivot_offset = sz / 2.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", _style_normal)
	tex = TextureRect.new()
	tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_SCALE
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex.material = _mat
	add_child(tex)
	refresh()
	return self


func refresh() -> void:
	if face_up and card >= 0:
		tex.texture = load(Rules.texture_path(card))
	else:
		tex.texture = BACK


func set_glow(on: bool) -> void:
	add_theme_stylebox_override("panel", _style_glow if on else _style_normal)


func set_interactive(drag: bool, tap: bool) -> void:
	draggable = drag
	tappable = tap
	mouse_filter = Control.MOUSE_FILTER_STOP if (drag or tap) else Control.MOUSE_FILTER_IGNORE


func is_dragging() -> bool:
	return _dragging


func move_to(pos: Vector2, rot: float, dur: float = 0.25, sc: float = 1.0, delay: float = 0.0) -> Tween:
	if _tw and _tw.is_valid():
		_tw.kill()
	_tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tw.tween_property(self, "position", pos, dur).set_delay(delay)
	_tw.tween_property(self, "rotation", rot, dur).set_delay(delay)
	_tw.tween_property(self, "scale", Vector2(sc, sc), dur).set_delay(delay)
	return _tw


func shake() -> void:
	var p := position
	var t := create_tween()
	for i in 4:
		t.tween_property(self, "position", p + Vector2(12 if i % 2 == 0 else -12, 0), 0.04)
	t.tween_property(self, "position", p, 0.04)


func _gui_input(e: InputEvent) -> void:
	if not (draggable or tappable):
		return
	var parent := get_parent() as Control
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		var mp: Vector2 = parent.get_global_transform().affine_inverse() * (e as InputEventMouse).global_position
		if e.pressed:
			_down = true
			_dragging = false
			_press = mp
			_grab = mp - position
			_last = mp
			_last_t = Time.get_ticks_msec()
			_vel = Vector2.ZERO
			accept_event()
		elif _down:
			_down = false
			accept_event()
			var travel := mp - _press
			if not _dragging:
				tapped.emit(self)
			else:
				_dragging = false
				dropped.emit(self, mp, _vel, travel)
	elif e is InputEventMouseMotion and _down and draggable:
		var mp: Vector2 = parent.get_global_transform().affine_inverse() * (e as InputEventMouse).global_position
		if not _dragging and (mp - _press).length() > 14.0:
			_dragging = true
			if _tw and _tw.is_valid():
				_tw.kill()
			z_index = 200
			var t := create_tween().set_parallel(true)
			t.tween_property(self, "rotation", 0.0, 0.12)
			t.tween_property(self, "scale", Vector2(1.12, 1.12), 0.12)
			grabbed.emit(self)
		if _dragging:
			var now := Time.get_ticks_msec()
			var dt := maxf(float(now - _last_t), 1.0) / 1000.0
			_vel = _vel.lerp((mp - _last) / dt, 0.55)
			_last = mp
			_last_t = now
			position = mp - _grab
		accept_event()
