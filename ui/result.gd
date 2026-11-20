# S3 結果(画面設計書 §4)。終わった理由、点(600 ms で数え上げ)、最高との差、3 つの数、共有する文字の枠を出す。
# もう1回は 300 ms 後から押せる(Enter・R でも)。コピーは clipboard_set を試し、選べる枠も常に出す(E-11)。
extends Control

signal retry
signal to_title

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Score := preload("res://core/score.gd")
const Kit := preload("res://ui/kit.gd")

var share := ""
var _points := 0
var _shown_at := 0
var _points_label: Label
var _retry: Button
var _copied: Label
var _best_label: Label = null
var _new_best := false


# rec は save_store.record() の戻り値。
func build(result: Dictionary, rec: Dictionary, share_text: String) -> void:
	size = Vector2(B.SCREEN_W, B.SCREEN_H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	share = share_text
	_points = int(result["points"])
	_shown_at = Time.get_ticks_msec()
	var why := S.REASON_HP if result["reason"] == "hp" else S.REASON_TIME
	add_child(Kit.place(Kit.label(why, 32, Kit.C_DIM, 700), 0, 230, B.SCREEN_W, 50))
	_points_label = Kit.label(S.RES_POINTS % "0", 96, Kit.C_TEXT, 900)
	add_child(Kit.place(_points_label, 0, 290, B.SCREEN_W, 140))
	if rec["prev_best"] != null:
		var diff := _points - int(rec["prev_best"])
		var text: String = S.RES_NEW_BEST % Score.comma(diff) if rec["new_best"] else S.RES_TO_BEST % Score.comma(-diff)
		_best_label = Kit.place(Kit.label(text, 28, Kit.C_GOOD if rec["new_best"] else Kit.C_DIM, 700), 0, 430, B.SCREEN_W, 44)
		_best_label.pivot_offset = Vector2(B.SCREEN_W / 2.0, 22)
		_new_best = rec["new_best"]
		add_child(_best_label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 36)
	for s: String in [S.RES_CUTS % int(result["cuts"]), S.RES_MAX_N % int(result["max_n"]), S.RES_MAX_CHAIN % int(result["max_chain"])]:
		row.add_child(Kit.label(s, 26, Kit.C_TEXT, 500))
	add_child(Kit.place(row, 0, 500, B.SCREEN_W, 48))
	_retry = Kit.place(Kit.button("retry", S.B_RETRY, 40), 80, 590, 560, 120)
	_retry.disabled = true
	add_child(_retry)
	var box := TextEdit.new()
	box.name = "share"
	box.text = share
	box.editable = false
	box.context_menu_enabled = true
	box.focus_mode = Control.FOCUS_CLICK
	box.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	box.add_theme_font_override("font", Kit.font(500))
	box.add_theme_font_size_override("font_size", 22)
	box.add_theme_color_override("font_readonly_color", Kit.C_TEXT)
	for st: String in ["normal", "read_only", "focus"]:
		var sb := Kit.box(Color(1, 1, 1, 0.03), Kit.C_FRAME, 2)
		sb.content_margin_top = 12
		box.add_theme_stylebox_override(st, sb)
	add_child(Kit.place(box, 40, 760, 640, 150))
	var copy := Kit.place(Kit.button("copy", S.B_COPY, 30), 40, 930, 300, 88)
	var title := Kit.place(Kit.button("title", S.B_TITLE, 30), 380, 930, 300, 88)
	add_child(copy)
	add_child(title)
	_copied = Kit.label("", 22, Kit.C_DIM)
	add_child(Kit.place(_copied, 0, 1030, B.SCREEN_W, 40))
	if not rec.get("saved", true):
		add_child(Kit.place(Kit.label(S.SAVE_FAILED, 24, Kit.C_DANGER, 500), 0, 1090, B.SCREEN_W, 40))
	_retry.pressed.connect(func() -> void: retry.emit())
	copy.pressed.connect(_copy)
	title.pressed.connect(func() -> void: to_title.emit())


func _copy() -> void:
	DisplayServer.clipboard_set(share)
	_copied.text = S.COPIED


@warning_ignore("integer_division")
func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() - _shown_at
	var shown := _points if t >= B.COUNT_MS else _points * t / B.COUNT_MS
	_points_label.text = S.RES_POINTS % Score.comma(shown)
	if _best_label != null:
		# 最高との差は数え上げが終わってから出す。新しい記録なら跳ねる
		_best_label.visible = t >= B.COUNT_MS
		_best_label.scale = Vector2.ONE * (1.0 + 0.5 * maxf(0.0, 1.0 - float(t - B.COUNT_MS) / 200.0) if _new_best else 1.0)
	if _retry.disabled and t >= B.RETRY_LOCK_MS:
		_retry.disabled = false


func key(ev: InputEventKey) -> void:
	if ev.pressed and not ev.echo and ev.physical_keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_R] and not _retry.disabled:
		retry.emit()
