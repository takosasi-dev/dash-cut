# S4 設定(画面設計書 §5・§11)。音量(5 段)・画面の揺れ・点滅を弱める。変えたらすぐ保存し(FR-22)、音量はその音量で斬る音を 1 回鳴らす。
# 選んでいる値は和紙で塗る(OnButton)。矢印で選び Enter で押す。Esc か「戻る」で来た画面へ。
extends Control

signal back

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Kit := preload("res://ui/kit.gd")
const Menu := preload("res://ui/menu.gd")
const KeyHint := preload("res://ui/keyhint.gd")

const ROWS := [250.0, 450.0, 650.0]  # 項目の見出しの y

var store: RefCounted
var menu: Menu
var _vol: Array[Button] = []
var _shake: Array[Button] = []
var _flash: Array[Button] = []


func build(p_store: RefCounted) -> void:
	store = p_store
	size = Vector2(B.SCREEN_W, B.SCREEN_H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var head := Kit.label(S.SETTINGS, 44, Kit.C_TEXT, 800)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(Kit.place(head, 60, 110, 600, 70))
	_caption(S.SET_VOLUME, ROWS[0])
	for k in B.VOLUMES.size():
		var v: int = B.VOLUMES[k]
		var b := Kit.place(Kit.button("volume_%d" % v, str(v), 28), 66 + 120 * k, ROWS[0] + 56, 104, 88)
		b.pressed.connect(func() -> void: _set_volume(v))
		add_child(b)
		_vol.append(b)
	_caption(S.SET_SHAKE, ROWS[1])
	_shake = _pair("shake", ROWS[1] + 56)
	_caption(S.SET_FLASH, ROWS[2])
	_flash = _pair("reduce_flash", ROWS[2] + 56)
	var ret := Kit.place(Kit.button("back", S.B_BACK, 30), 220, 900, 280, 88)
	ret.pressed.connect(func() -> void: back.emit())
	add_child(ret)
	add_child(Kit.place(KeyHint.new([[["up", "down", "left", "right"], S.KEY_SELECT], [["Enter"], S.KEY_OK], [["Esc"], S.B_BACK]]), 28, 1210, 664, 56))
	_paint()
	var list: Array[Button] = []
	list.append_array(_vol)
	list.append_array(_shake)
	list.append_array(_flash)
	list.append(ret)
	menu = Menu.new(list, B.VOLUMES.find(int(store.settings()["volume"])))


func _caption(text: String, y: float) -> void:
	var l := Kit.label(text, 28, Kit.C_TEXT, 700)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(Kit.place(l, 60, y, 600, 44))


# 入・切の 2 つのボタン。
func _pair(k: String, y: float) -> Array[Button]:
	var out: Array[Button] = []
	for on: bool in [true, false]:
		var b := Kit.place(Kit.button("%s_%s" % [k, "on" if on else "off"], S.ON if on else S.OFF, 30), 66 + 240 * (0 if on else 1), y, 224, 88)
		b.pressed.connect(func() -> void: _set_flag(k, on))
		add_child(b)
		out.append(b)
	return out


func _draw() -> void:
	# 見出しの下と項目の間の罫
	draw_line(Vector2(60, 196), Vector2(660, 196), Kit.C_USU, 2.0)
	for y: float in [ROWS[1] - 26.0, ROWS[2] - 26.0, 850.0]:
		draw_line(Vector2(60, y), Vector2(660, y), Color(Kit.C_USU, 0.6), 1.0)


func _paint() -> void:
	var st: Dictionary = store.settings()
	for k in _vol.size():
		Kit.set_selected(_vol[k], B.VOLUMES[k] == int(st["volume"]))
	for pair: Array in [[_shake, "shake"], [_flash, "reduce_flash"]]:
		Kit.set_selected(pair[0][0], st[pair[1]])
		Kit.set_selected(pair[0][1], not st[pair[1]])


func _set_volume(v: int) -> void:
	store.set_setting("volume", v)
	Sfx.set_volume(v)
	Sfx.play("cut")
	_paint()


func _set_flag(k: String, on: bool) -> void:
	store.set_setting(k, on)
	_paint()


func key(ev: InputEventKey) -> void:
	if ev.pressed and not ev.echo and ev.physical_keycode == KEY_ESCAPE:
		back.emit()
	else:
		menu.key(ev)
