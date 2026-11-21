# S1 タイトル(画面設計書 §2・§11)。題字、入口 2 つと設定。今日の並びの右に端末の日付、下に記録を出す。
# ↑↓ で選び Enter で押す(最初は今日の並び。v0.2.0 の「Enter で今日の並び」のまま)。
extends Control

signal chosen(what: String)  # "daily" / "practice" / "settings"

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Score := preload("res://core/score.gd")
const Kit := preload("res://ui/kit.gd")
const Logo := preload("res://ui/logo.gd")
const Menu := preload("res://ui/menu.gd")
const KeyHint := preload("res://ui/keyhint.gd")

var menu: Menu
var logo: Logo


# store は save_store、day は通し日数、date は "2026-11-19"。still は題字を動かさない(点滅を弱める 入)。
func build(store: RefCounted, day: int, date: String, still: bool = false) -> void:
	size = Vector2(B.SCREEN_W, B.SCREEN_H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo = Logo.new()
	logo.still = still
	logo.position = Vector2(40, 140)
	add_child(logo)
	var tag := Kit.label(S.TAGLINE, 26, Kit.C_DIM, 500)
	add_child(Kit.place(tag, 0, 452, B.SCREEN_W, 44))
	if store.load_failed:
		add_child(Kit.place(Kit.label(S.LOAD_FAILED, 22, Kit.C_DANGER, 500), 0, 506, B.SCREEN_W, 36))
	var daily := Kit.place(Kit.button("daily", "%s   %s" % [S.B_DAILY, date], 34), 80, 570, 560, 120)
	var practice := Kit.place(Kit.button("practice", S.B_PRACTICE, 32), 80, 770, 560, 120)
	var settings := Kit.place(Kit.button("settings", S.B_SETTINGS, 30), 220, 970, 280, 88)
	var list: Array[Button] = [daily, practice, settings]
	for b: Button in list:
		var what := String(b.name)
		b.pressed.connect(func() -> void: chosen.emit(what))
		add_child(b)
	# 記録(初めての起動では出さない)
	if store.has_any_record():
		var d: Dictionary = store.daily(day)
		var rec := S.REC_NONE
		if d["first"] != null:
			rec = (S.REC_FIRST % Score.comma(d["first"])) + " / " + (S.REC_TODAY_BEST % Score.comma(d["best"]))
		add_child(Kit.place(Kit.label(rec, 24, Kit.C_DIM, 500), 0, 698, B.SCREEN_W, 40))
		var pb: Variant = store.practice_best()
		if pb != null:
			add_child(Kit.place(Kit.label(S.REC_BEST % Score.comma(pb), 24, Kit.C_DIM, 500), 0, 898, B.SCREEN_W, 40))
	var ver := Kit.label(S.VERSION, 20, Kit.C_DIM)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(Kit.place(ver, 28, 1210, 140, 56))
	add_child(Kit.place(KeyHint.new([[["up", "down"], S.KEY_SELECT], [["Enter"], S.KEY_OK]]), 160, 1210, 532, 56))
	menu = Menu.new(list, 0)


func _draw() -> void:
	# 一言の左右の細い罫
	var f := Kit.font(500)
	var w := f.get_string_size(S.TAGLINE, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	var y := 474.0
	var gap := 22.0
	draw_line(Vector2(B.SCREEN_W / 2.0 - w / 2.0 - gap - 70.0, y), Vector2(B.SCREEN_W / 2.0 - w / 2.0 - gap, y), Kit.C_USU, 2.0)
	draw_line(Vector2(B.SCREEN_W / 2.0 + w / 2.0 + gap, y), Vector2(B.SCREEN_W / 2.0 + w / 2.0 + gap + 70.0, y), Kit.C_USU, 2.0)


func key(ev: InputEventKey) -> void:
	menu.key(ev)
