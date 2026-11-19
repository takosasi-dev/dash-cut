# S1 タイトル(画面設計書 §2)。入口 2 つと設定。今日の並びの右に端末の日付、下に記録を出す。Enter で今日の並び。
extends Control

signal chosen(what: String)  # "daily" / "practice" / "settings"

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Score := preload("res://core/score.gd")
const Kit := preload("res://ui/kit.gd")


# store は save_store、day は通し日数、date は "2026-11-19"。
func build(store: RefCounted, day: int, date: String) -> void:
	size = Vector2(B.SCREEN_W, B.SCREEN_H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(Kit.place(Kit.label(S.NAME, 72, Kit.C_TEXT, 900), 0, 200, B.SCREEN_W, 110))
	add_child(Kit.place(Kit.label(S.TAGLINE, 28, Kit.C_DIM, 500), 0, 310, B.SCREEN_W, 44))
	if store.load_failed:
		add_child(Kit.place(Kit.label(S.LOAD_FAILED, 22, Kit.C_DANGER, 500), 0, 360, B.SCREEN_W, 36))
	var daily := Kit.place(Kit.button("daily", "%s   %s" % [S.B_DAILY, date], 36), 80, 440, 560, 120)
	var practice := Kit.place(Kit.button("practice", S.B_PRACTICE, 34), 80, 650, 560, 120)
	var settings := Kit.place(Kit.button("settings", S.B_SETTINGS, 30), 220, 870, 280, 88)
	for b: Button in [daily, practice, settings]:
		var what := String(b.name)
		b.pressed.connect(func() -> void: chosen.emit(what))
		add_child(b)
	# 記録(初めての起動では出さない)
	if store.has_any_record():
		var d: Dictionary = store.daily(day)
		var rec := S.REC_NONE
		if d["first"] != null:
			rec = (S.REC_FIRST % Score.comma(d["first"])) + " / " + (S.REC_TODAY_BEST % Score.comma(d["best"]))
		add_child(Kit.place(Kit.label(rec, 24, Kit.C_DIM, 500), 0, 570, B.SCREEN_W, 40))
		var pb: Variant = store.practice_best()
		if pb != null:
			add_child(Kit.place(Kit.label(S.REC_BEST % Score.comma(pb), 24, Kit.C_DIM, 500), 0, 780, B.SCREEN_W, 40))
	var ver := Kit.label(S.VERSION, 20, Kit.C_DIM)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(Kit.place(ver, 24, 1228, 200, 32))


func key(ev: InputEventKey) -> void:
	if ev.pressed and not ev.echo and ev.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]:
		chosen.emit("daily")
