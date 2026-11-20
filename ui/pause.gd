# S5 一時停止(画面設計書 §6)。プレイ画面を暗くした上に重ねる。続ける・やり直す・設定・タイトルへ。Esc で続ける、R でやり直す。
extends Control

signal picked(what: String)  # "resume" / "restart" / "settings" / "title"

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Kit := preload("res://ui/kit.gd")


func build() -> void:
	size = Vector2(B.SCREEN_W, B.SCREEN_H)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	add_child(Kit.place(dim, -4000, -4000, B.SCREEN_W + 8000, B.SCREEN_H + 8000))  # 下のプレイ画面の操作を止める
	add_child(Kit.place(Kit.label(S.PAUSE, 48, Kit.C_TEXT, 800), 0, 260, B.SCREEN_W, 80))
	var y := 400.0
	for pair: Array in [["resume", S.B_RESUME], ["restart", S.B_RESTART], ["settings", S.B_SETTINGS], ["title", S.B_TITLE]]:
		var b := Kit.place(Kit.button(pair[0], pair[1], 32), 160, y, 400, 96)
		var what: String = pair[0]
		b.pressed.connect(func() -> void: picked.emit(what))
		add_child(b)
		y += 120


func key(ev: InputEventKey) -> void:
	if not ev.pressed or ev.echo:
		return
	if ev.physical_keycode == KEY_ESCAPE:
		picked.emit("resume")
	elif ev.physical_keycode == KEY_R:
		picked.emit("restart")
