# S3 結果(画面設計書 §4・§11)。終わった理由、点(明朝。600 ms で数え上げ)、最高との差、3 つの数、共有する文字の枠を出す。
# 新しい記録なら、数え上げの後に朱の判「新記録」を押す(点滅を弱める 入 では大きさを変えずに出す)。
# もう1回は最初から選んであり(朱の印)、300 ms 後から押せる(Enter・R でも)。その 300 ms は選びを動かすキーも捨てる。
# コピーは clipboard_set を試し、選べる枠も常に出す(E-11)。枠の右クリックのメニューは出さない(Ctrl+C は使える)。
extends Control

signal retry
signal to_title

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Score := preload("res://core/score.gd")
const Kit := preload("res://ui/kit.gd")
const Menu := preload("res://ui/menu.gd")
const KeyHint := preload("res://ui/keyhint.gd")

const POINTS_SIZE := 104
const POINTS_BASE := 330.0
const STATS_Y := 446.0

var share := ""
var reduce_flash := false
var menu: Menu
var _points := 0
var _shown_at := 0
var _retry: Button
var _copied: Label
var _best_label: Label = null
var _new_best := false
var _stats: Array = []  # [[見出し, 数], …](数は _draw で明朝)
var _num_w := 0.0  # 最後の点の字の幅(数え上げの間も同じ所に右寄せで描く)


# rec は save_store.record() の戻り値。
func build(result: Dictionary, rec: Dictionary, share_text: String, p_reduce_flash: bool = false) -> void:
	size = Vector2(B.SCREEN_W, B.SCREEN_H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	share = share_text
	reduce_flash = p_reduce_flash
	_points = int(result["points"])
	_shown_at = Time.get_ticks_msec()
	var why := S.REASON_HP if result["reason"] == "hp" else S.REASON_TIME
	add_child(Kit.place(Kit.label(why, 30, Kit.C_DIM, 700), 0, 160, B.SCREEN_W, 50))
	_num_w = _measure(Score.comma(_points))
	if rec["prev_best"] != null:
		var diff := _points - int(rec["prev_best"])
		var text: String = S.RES_NEW_BEST % Score.comma(diff) if rec["new_best"] else S.RES_TO_BEST % Score.comma(-diff)
		_best_label = Kit.place(Kit.label(text, 28, Kit.C_TEXT if rec["new_best"] else Kit.C_DIM, 700), 0, 356, B.SCREEN_W, 44)
		_best_label.pivot_offset = Vector2(B.SCREEN_W / 2.0, 22)
		_new_best = rec["new_best"]
		add_child(_best_label)
	_stats = [[S.RES_CUTS, int(result["cuts"])], [S.RES_MAX_N, int(result["max_n"])], [S.RES_MAX_CHAIN, int(result["max_chain"])]]
	for k in 3:
		add_child(Kit.place(Kit.label(_stats[k][0], 22, Kit.C_DIM, 500), 60 + 200 * k, STATS_Y + 10, 200, 34))
	_retry = Kit.place(Kit.button("retry", S.B_RETRY, 40), 80, 610, 560, 120)
	_retry.disabled = true
	add_child(_retry)
	var box := TextEdit.new()
	box.name = "share"
	box.text = share
	box.editable = false
	box.context_menu_enabled = false
	box.focus_mode = Control.FOCUS_CLICK
	box.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	add_child(Kit.place(box, 40, 784, 640, 150))
	var copy := Kit.place(Kit.button("copy", S.B_COPY, 30), 40, 956, 300, 88)
	var title := Kit.place(Kit.button("title", S.B_TITLE, 30), 380, 956, 300, 88)
	add_child(copy)
	add_child(title)
	_copied = Kit.label("", 22, Kit.C_DIM)
	add_child(Kit.place(_copied, 0, 1054, B.SCREEN_W, 40))
	if not rec.get("saved", true):
		add_child(Kit.place(Kit.label(S.SAVE_FAILED, 24, Kit.C_DANGER, 500), 0, 1100, B.SCREEN_W, 40))
	add_child(Kit.place(KeyHint.new([[["up", "down", "left", "right"], S.KEY_SELECT], [["Enter"], S.KEY_OK], [["R"], S.B_RETRY]]), 28, 1210, 664, 56))
	_retry.pressed.connect(func() -> void: retry.emit())
	copy.pressed.connect(_copy)
	title.pressed.connect(func() -> void: to_title.emit())
	var list: Array[Button] = [_retry, copy, title]
	menu = Menu.new(list, 0)  # もう1回を最初から選んでおく(押せない 300 ms の間も印は出す)


static func _measure(text: String) -> float:
	var f := Kit.num_font()
	var cell := f.get_string_size("0", HORIZONTAL_ALIGNMENT_LEFT, -1, POINTS_SIZE).x
	var w := 0.0
	for ch in text:
		w += cell if ch >= "0" and ch <= "9" else f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, POINTS_SIZE).x
	return w


func _copy() -> void:
	DisplayServer.clipboard_set(share)
	_copied.text = S.COPIED


func elapsed() -> int:
	return Time.get_ticks_msec() - _shown_at


# 判が押された割合(0〜1)。新しい記録でなければ -1。
func stamp_k() -> float:
	if not _new_best:
		return -1.0
	return clampf(float(elapsed() - B.COUNT_MS) / B.STAMP_MS, 0.0, 1.0) if elapsed() >= B.COUNT_MS else -1.0


@warning_ignore("integer_division")
func _process(_delta: float) -> void:
	var t := elapsed()
	if _best_label != null:
		# 最高との差は数え上げが終わってから出す。新しい記録なら跳ねる
		_best_label.visible = t >= B.COUNT_MS
		_best_label.scale = Vector2.ONE * (1.0 + 0.5 * maxf(0.0, 1.0 - float(t - B.COUNT_MS) / 200.0) if _new_best and not reduce_flash else 1.0)
	if _retry.disabled and t >= B.RETRY_LOCK_MS:
		_retry.disabled = false
	if t < B.COUNT_MS + B.STAMP_MS + 100:
		queue_redraw()


@warning_ignore("integer_division")
func _draw() -> void:
	var t := elapsed()
	var shown := _points if t >= B.COUNT_MS else _points * t / B.COUNT_MS
	var unit_f := Kit.font(700)
	var unit_w := unit_f.get_string_size(S.RES_UNIT, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
	var x0 := (B.SCREEN_W - _num_w - unit_w - 8.0) / 2.0
	Kit.draw_num(self, Vector2(x0, POINTS_BASE), Score.comma(shown), POINTS_SIZE, Kit.C_TEXT, _num_w, 2)
	draw_string(unit_f, Vector2(x0 + _num_w + 8.0, POINTS_BASE), S.RES_UNIT, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Kit.C_DIM)
	# 理由の左右の罫
	draw_line(Vector2(150, 185), Vector2(270, 185), Kit.C_USU, 2.0)
	draw_line(Vector2(450, 185), Vector2(570, 185), Kit.C_USU, 2.0)
	# 3 つの数: 罫で区切った 3 列
	draw_line(Vector2(60, STATS_Y), Vector2(660, STATS_Y), Kit.C_USU, 1.0)
	draw_line(Vector2(60, STATS_Y + 124), Vector2(660, STATS_Y + 124), Kit.C_USU, 1.0)
	for k in 3:
		if k > 0:
			draw_line(Vector2(60 + 200 * k, STATS_Y + 18), Vector2(60 + 200 * k, STATS_Y + 106), Color(Kit.C_USU, 0.8), 1.0)
		Kit.draw_num(self, Vector2(60 + 200 * k, STATS_Y + 98), str(_stats[k][1]), 46, Kit.C_TEXT, 200, 1)
	var sk := stamp_k()
	if sk >= 0.0:
		_stamp(Vector2(x0 + _num_w + unit_w + 70.0, POINTS_BASE - 74.0), sk)


# 朱の判「新記録」。k は押された割合(1.6 倍から縮んで押される)。
func _stamp(c: Vector2, k: float) -> void:
	c.x = minf(c.x, B.SCREEN_W - 70.0)
	var scale_k := 1.0 if reduce_flash else 1.0 + 0.6 * (1.0 - Kit.ease_out(k))
	var a := 1.0 if reduce_flash else clampf(k * 2.0, 0.0, 1.0)
	var w := 104.0
	var h := 50.0
	draw_set_transform(c, -0.12, Vector2.ONE * scale_k)
	draw_rect(Rect2(-w / 2, -h / 2, w, h), Color(Kit.C_SHU, a))
	draw_rect(Rect2(-w / 2 + 4, -h / 2 + 4, w - 8, h - 8), Color(Kit.C_WASHI, 0.8 * a), false, 1.5)
	draw_string(Kit.num_font(), Vector2(-w / 2, 11), S.STAMP_BEST, HORIZONTAL_ALIGNMENT_CENTER, w, 30, Color(Kit.C_WASHI, a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func key(ev: InputEventKey) -> void:
	if not ev.pressed:
		return
	if not ev.echo and ev.physical_keycode == KEY_R:
		if not _retry.disabled:
			retry.emit()
		return
	if _retry.disabled:
		return  # 押せない 300 ms は、選びを動かすキーも捨てる(終わった直後の矢印でもう1回から外れないように)
	menu.key(ev)
