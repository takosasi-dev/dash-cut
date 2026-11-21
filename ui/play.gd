# S2 プレイ(画面設計書 §3)。払う操作とキーを整数 2 つにして sim.queue_dash に渡し、たまった時間ぶん sim を進め(1 フレーム 8 tick まで)、
# events で演出と音を出し、snapshot を描く。ゲームの決まりは持たない(INV-1)。狙いの線は core/geom の preview(INV-4)。
# マウスは左ボタン、タッチは 1 本目だけを見る。タッチから作られたマウスのイベントは捨てる(E-6)。
extends Control

signal finished(result: Dictionary)
signal pause_requested

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Sim := preload("res://core/sim.gd")
const Geom := preload("res://core/geom.gd")
const Score := preload("res://core/score.gd")
const Kit := preload("res://ui/kit.gd")
const Field := preload("res://ui/field.gd")
const Fx := preload("res://ui/fx.gd")

var sim: Sim = null
var paused := false
var shake_on := true
var reduce_flash := false
var field: Field
var fx: Fx
var input_at := 0  # 最後に突進を指示した時刻(usec。動き出しを描くまでを測る)
var dash_started := false  # このフレームで突進が始まった(測る側が読む)
var _acc := 0.0
var _over_at := -1
var _shake_until := 0
var _shake_px := 0.0
var _drag := false
var _drag_from := Vector2.ZERO
var _drag_to := Vector2.ZERO
var _held := {KEY_LEFT: false, KEY_RIGHT: false, KEY_UP: false, KEY_DOWN: false}
var _l: Dictionary = {}
var _pause_btn: Button


func _ready() -> void:
	size = Vector2(B.SCREEN_W, B.SCREEN_H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx = Fx.new()
	field = Field.new()
	field.fx = fx
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(Kit.place(field, 0, 0, B.SCREEN_W, B.SCREEN_H))
	_pause_btn = Kit.place(Kit.button("pause", S.PAUSE_MARK, 28), 28, 28, 80, 80)
	_pause_btn.focus_mode = Control.FOCUS_NONE  # 遊びの間はキーで選ばない(Esc で止める)
	_pause_btn.pressed.connect(func() -> void: pause_requested.emit())
	add_child(_pause_btn)
	# 残り時間・点・つなぎ・体力の丸・回数の四角は field が描く(明朝の数字を 1 桁ずつ同じ幅で)。ここは日本語の見出しだけ
	_l["time_cap"] = Kit.place(Kit.label(S.HUD_TIME_CAP, 20, Kit.C_DIM, 500), 260, 22, 200, 30)
	_l["hp"] = Kit.place(Kit.label(S.HUD_HP, 20, Kit.C_DIM, 500), 578, 22, 132, 30)
	_l["hint"] = Kit.place(Kit.label(S.HINT, 36, Color(Kit.C_TEXT, 0.8), 700), 0, 1050, B.SCREEN_W, 60)
	_l["keys"] = Kit.place(Kit.label(S.HINT_KEYS, 22, Kit.C_DIM, 500), 0, 1106, B.SCREEN_W, 36)
	_l["charge"] = Kit.place(Kit.label(S.HUD_CHARGE, 24, Kit.C_DIM, 500), 196, 1200, 100, 44)
	for k: String in _l:
		add_child(_l[k])


# mode: 0 = 今日の並び、1 = 練習。
func start(mode: int, seed_value: int) -> void:
	sim = Sim.new(seed_value, mode)
	fx.reduce_flash = reduce_flash
	paused = false
	_acc = 0.0
	_over_at = -1
	cancel_drag()
	_refresh()


func is_playing() -> bool:
	return sim != null and not sim.is_over()


func set_paused(on: bool) -> void:
	paused = on
	_acc = 0.0  # 一時停止の間にたまった時間は捨てる(FR-24)
	cancel_drag()
	for k: int in _held:
		_held[k] = false


# 押している途中の操作を捨てる(E-5)。
func cancel_drag() -> void:
	_drag = false


func _unhandled_input(event: InputEvent) -> void:
	pointer(event)


# マウス・タッチの払う操作(FR-2)。離した時に差の長さが 24 px 以上なら突進を指示する。
func pointer(event: InputEvent) -> void:
	if not is_playing() or paused:
		return
	if event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT or event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		_press(event.pressed, event.position)
	elif event is InputEventMouseMotion:
		if event.device != InputEvent.DEVICE_ID_EMULATION and _drag:
			_drag_to = event.position
	elif event is InputEventScreenTouch:
		if event.index == 0:
			_press(event.pressed, event.position)
	elif event is InputEventScreenDrag:
		if event.index == 0 and _drag:
			_drag_to = event.position


func _press(down: bool, pos: Vector2) -> void:
	if down:
		_drag = true  # 前の押し始めが残っていても捨てる(E-5)
		_drag_from = pos
		_drag_to = pos
		return
	if not _drag:
		return
	_drag = false
	_drag_to = pos
	var d := _drag_vec()
	if d.length() >= B.MIN_DRAG:
		_queue(d.x, d.y)


func _drag_vec() -> Vector2i:
	var d := _drag_to - _drag_from
	return Vector2i(roundi(d.x), roundi(d.y))


func _queue(ix: int, iy: int) -> void:
	sim.queue_dash(ix, iy)
	input_at = Time.get_ticks_usec()


# 矢印の組の向き(FR-3)。押していなければ (0, 0)。
func _key_dir() -> Vector2i:
	return Vector2i(int(_held[KEY_RIGHT]) - int(_held[KEY_LEFT]), int(_held[KEY_DOWN]) - int(_held[KEY_UP]))


# S2 のキー(画面設計書 §8)。矢印で向き、スペースで突進、Esc で一時停止。
func key(ev: InputEventKey) -> void:
	var k := ev.physical_keycode
	if _held.has(k):
		_held[k] = ev.pressed
		return
	if not ev.pressed or ev.echo:
		return
	if k == KEY_ESCAPE:
		pause_requested.emit()
	elif k == KEY_SPACE and is_playing() and not paused:
		var d := _key_dir()
		if d != Vector2i.ZERO:
			_queue(d.x, d.y)


func _process(delta: float) -> void:
	if sim == null:
		return
	var now := Time.get_ticks_msec()
	position = Vector2.ZERO
	if shake_on and now < _shake_until:
		position = Vector2(randf_range(-_shake_px, _shake_px), randf_range(-_shake_px, _shake_px))
	dash_started = false
	if _over_at >= 0:
		if now - _over_at >= B.OVER_MS:
			_over_at = -2
			finished.emit(sim.result())
	elif not paused and _over_at == -1:
		_acc += delta * B.TICK_HZ
		var n := int(_acc)
		_acc -= n
		if n > B.MAX_STEPS_PER_FRAME:
			n = B.MAX_STEPS_PER_FRAME  # E-8: 超えた分は捨てる
			_acc = 0.0
		for k in n:
			sim.step()
			for e: Dictionary in sim.events():
				_on_event(e, now)
	_refresh()


# 演出の表(§9.12)。演出は events を受けたフレームに始める。
func _on_event(e: Dictionary, now: int) -> void:
	fx.on_event(e, now)
	match e["type"]:
		"dash_start":
			dash_started = true
			Sfx.play("dash")
		"cut_mark":
			Sfx.play("cut", mini(int(e["k"]), B.SEMITONE_CAP))
		"dash_end":
			var n := int(e["n"])
			if n >= 1:
				Sfx.play("shatter", mini(int(e["chain"]) - 1, B.SEMITONE_CAP))
				if n >= B.BIG_CUT:
					_shake(B.SHAKE_CUT_PX, B.SHAKE_CUT_MS, now)
			else:
				Sfx.play("whiff")
		"no_charge":
			Sfx.play("empty")
		"hurt":
			Sfx.play("hurt")
			_shake(B.SHAKE_HURT_PX, B.SHAKE_HURT_MS, now)
		"shoot_warn":
			Sfx.play("warn")
		"over":
			Sfx.play("over")
			_over_at = now
			cancel_drag()


func _shake(px: float, ms: int, now: int) -> void:
	if not shake_on:
		return  # 揺れを切ると何もしない(AC-20)
	_shake_px = px
	_shake_until = now + ms


func aim_vec() -> Vector2i:
	if _drag:
		var d := _drag_vec()
		return d if d.length() >= B.MIN_DRAG else Vector2i.ZERO
	return _key_dir()


func _refresh() -> void:
	var now := Time.get_ticks_msec()
	var s := sim.snapshot()
	fx.update(now, int(s["freeze_left"]))
	var running: bool = s["clock_running"]
	fx.on_chain(int(s["chain"]), now)
	_l["hint"].visible = not running
	_l["keys"].visible = not running
	var a := aim_vec()
	field.aim = {} if a == Vector2i.ZERO or not is_playing() or paused else Geom.preview(s["x"], s["y"], a.x, a.y, s["enemies"])
	field.guide = _guide_target(s) if int(s["cuts"]) == 0 and not running else Vector2.INF
	field.snap = s
	field.now = now
	field.queue_redraw()


# 最初に斬るまで矢印で指す先: 印の明けた一番近い敵(見せるだけ。判定はしない)。いなければ INF。
static func _guide_target(s: Dictionary) -> Vector2:
	var me := Vector2(s["x"], s["y"])
	var best := Vector2.INF
	for e: Dictionary in s["enemies"]:
		var p := Vector2(e["x"], e["y"])
		if int(e["mark"]) == 0 and (best == Vector2.INF or me.distance_squared_to(p) < me.distance_squared_to(best)):
			best = p
	return best
