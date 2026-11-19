# S4 設定(画面設計書 §5)。音量(5 段)・画面の揺れ・点滅を弱める。変えたらすぐ保存し(FR-22)、音量はその音量で斬る音を 1 回鳴らす。
# Esc か「戻る」で来た画面へ。
extends Control

signal back

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Kit := preload("res://ui/kit.gd")

var store: RefCounted
var _vol: Array[Button] = []
var _shake: Array[Button] = []
var _flash: Array[Button] = []


func build(p_store: RefCounted) -> void:
	store = p_store
	size = Vector2(B.SCREEN_W, B.SCREEN_H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(Kit.place(Kit.label(S.SETTINGS, 44, Kit.C_TEXT, 800), 0, 120, B.SCREEN_W, 70))
	_caption(S.SET_VOLUME, 260)
	for k in B.VOLUMES.size():
		var v: int = B.VOLUMES[k]
		var b := Kit.place(Kit.button("volume_%d" % v, str(v), 28), 60 + 124 * k, 310, 108, 88)
		b.pressed.connect(func() -> void: _set_volume(v))
		add_child(b)
		_vol.append(b)
	_caption(S.SET_SHAKE, 450)
	_shake = _pair("shake", 500)
	_caption(S.SET_FLASH, 640)
	_flash = _pair("reduce_flash", 690)
	var ret := Kit.place(Kit.button("back", S.B_BACK, 32), 220, 900, 280, 88)
	ret.pressed.connect(func() -> void: back.emit())
	add_child(ret)
	_paint()


func _caption(text: String, y: float) -> void:
	var l := Kit.label(text, 28, Kit.C_TEXT, 700)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(Kit.place(l, 60, y, 600, 44))


# 入・切の 2 つのボタン。
func _pair(k: String, y: float) -> Array[Button]:
	var out: Array[Button] = []
	for on: bool in [true, false]:
		var b := Kit.place(Kit.button("%s_%s" % [k, "on" if on else "off"], S.ON if on else S.OFF, 30), 60 + 232 * (0 if on else 1), y, 216, 88)
		b.pressed.connect(func() -> void: _set_flag(k, on))
		add_child(b)
		out.append(b)
	return out


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
