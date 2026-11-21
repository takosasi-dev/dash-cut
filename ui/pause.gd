# S5 一時停止(画面設計書 §6・§11)。プレイ画面を墨で暗くし、真ん中の濃墨の帯にボタンを置く。続ける・やり直す・設定・タイトルへ。
# Esc で続ける、R でやり直す、矢印で選んで Enter。PAUSE_IN_MS で薄く→濃く出る(見た目だけ。最初から押せる)。
extends Control

signal picked(what: String)  # "resume" / "restart" / "settings" / "title"

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Kit := preload("res://ui/kit.gd")
const Menu := preload("res://ui/menu.gd")
const KeyHint := preload("res://ui/keyhint.gd")

const BAND := Rect2(0, 290, 720, 690)

var menu: Menu
var _shown_at := 0


func build() -> void:
	size = Vector2(B.SCREEN_W, B.SCREEN_H)
	_shown_at = Time.get_ticks_msec()
	var dim := ColorRect.new()
	dim.color = Color(Kit.C_INK, 0.78)
	add_child(Kit.place(dim, -4000, -4000, B.SCREEN_W + 8000, B.SCREEN_H + 8000))  # 下のプレイ画面の操作を止める
	var band := _Band.new()
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(Kit.place(band, -4000, BAND.position.y, B.SCREEN_W + 8000, BAND.size.y))
	add_child(Kit.place(Kit.label(S.PAUSE, 44, Kit.C_TEXT, 800), 0, 318, B.SCREEN_W, 72))
	var list: Array[Button] = []
	var y := 420.0
	for pair: Array in [["resume", S.B_RESUME], ["restart", S.B_RESTART], ["settings", S.B_SETTINGS], ["title", S.B_TITLE]]:
		var b := Kit.place(Kit.button(pair[0], pair[1], 30), 160, y, 400, 92)
		var what: String = pair[0]
		b.pressed.connect(func() -> void: picked.emit(what))
		add_child(b)
		list.append(b)
		y += 116
	var hint := KeyHint.new([[["Esc"], S.B_RESUME], [["R"], S.B_RESTART], [["up", "down"], S.KEY_SELECT], [["Enter"], S.KEY_OK]])
	hint.center = true
	add_child(Kit.place(hint, 0, 894, B.SCREEN_W, 56))  # 帯の中(下の回数の印に重ねない)
	menu = Menu.new(list, 0)
	modulate.a = 0.0


func _process(_delta: float) -> void:
	modulate.a = Kit.ease_out(float(Time.get_ticks_msec() - _shown_at) / B.PAUSE_IN_MS)


func key(ev: InputEventKey) -> void:
	if not ev.pressed:
		return
	if not ev.echo and ev.physical_keycode == KEY_ESCAPE:
		picked.emit("resume")
	elif not ev.echo and ev.physical_keycode == KEY_R:
		picked.emit("restart")
	else:
		menu.key(ev)


# 真ん中の帯(濃墨と、上下の薄墨の罫)。窓の横いっぱいに敷く。
class _Band extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(Kit.C_SUMI, 0.96))
		draw_line(Vector2(0, 1), Vector2(size.x, 1), Kit.C_USU, 2.0)
		draw_line(Vector2(0, size.y - 1), Vector2(size.x, size.y - 1), Kit.C_USU, 2.0)
