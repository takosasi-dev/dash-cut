# 画面の切り替え(S1〜S5)・キーの振り分け・保存・自動の一時停止を受け持つ。ゲームの決まりは持たない(INV-1)。
# 払う操作は ui/play.gd が _unhandled_input で受ける(ボタンを押した操作は突進にしない)。
# ?debug=1(または --debug)で window.dcState に状態を出す。--auto は窓なしの確かめ用(タイトル → プレイ → 結果 → もう1回 を自動で通す)。
extends Node

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Sim := preload("res://core/sim.gd")
const Day := preload("res://core/day_index.gd")
const Share := preload("res://core/share_text.gd")
const Store := preload("res://save/save_store.gd")
const Kit := preload("res://ui/kit.gd")
const Play := preload("res://ui/play.gd")
const Title := preload("res://ui/title.gd")
const Result := preload("res://ui/result.gd")
const Settings := preload("res://ui/settings.gd")
const Pause := preload("res://ui/pause.gd")

var stage: Control
var store: Store
var screen := "title"  # title / play / result / settings
var current: Control = null  # 今の画面(play の時は play)
var play: Play = null
var pause_view: Pause = null
var settings_from := "title"
var run := {}  # 今の回 { mode, seed, day, date }
var debug := false
var auto := false
var lat_ms: Array = []
var frame_ms: Array = []
var _visibility_cb: Variant = null
var _last_frame := 0
var _settings_overlay: Control = null
var _auto_frame := 0
var _auto_rounds := 0


func _ready() -> void:
	stage = Control.new()
	stage.size = Vector2(B.SCREEN_W, B.SCREEN_H)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	var bg := ColorRect.new()
	bg.color = Kit.C_BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(Kit.place(bg, -2000, -2000, B.SCREEN_W + 4000, B.SCREEN_H + 4000))
	store = Store.new()
	Sfx.set_volume(int(store.settings()["volume"]))
	debug = _flag("debug")
	auto = OS.get_cmdline_user_args().has("--auto")
	_watch_visibility()
	RenderingServer.frame_post_draw.connect(_after_draw)
	_show_title()
	if auto:
		_on_title("daily")


static func _flag(flag: String) -> bool:
	if OS.has_feature("web"):
		var q: Variant = JavaScriptBridge.eval("location.search", true)
		return q is String and q.contains(flag + "=1")
	return OS.get_cmdline_user_args().has("--" + flag)


func _clear() -> void:
	if pause_view != null:
		pause_view.queue_free()
		pause_view = null
	if _settings_overlay != null:
		_settings_overlay = null
	for c in stage.get_children():
		if c.get_index() == 0:
			continue
		c.queue_free()
	current = null
	play = null


func _input(event: InputEvent) -> void:
	if (event is InputEventKey or event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:
		Sfx.unlock()  # FR-25: 最初の操作から鳴らす
	if not (event is InputEventKey):
		return
	if screen != "play" and (event.ctrl_pressed or event.meta_pressed or event.alt_pressed):
		return  # 結果の枠の Ctrl+C などは部品に渡す
	get_viewport().set_input_as_handled()  # 矢印・スペースを Godot のフォーカスの移動やボタンに使わせない
	if screen == "settings":
		current.key(event)
	elif pause_view != null:
		pause_view.key(event)
	elif current != null and current.has_method("key"):
		current.key(event)


# --- S1 タイトル ---

func _show_title() -> void:
	_clear()
	screen = "title"
	var d := _today()
	var t := Title.new()
	t.build(store, d["day"], d["date"])
	t.chosen.connect(_on_title)
	stage.add_child(t)
	current = t


func _on_title(what: String) -> void:
	match what:
		"settings":
			_show_settings("title")
		"daily":
			var d := _today()
			_start({"mode": Sim.MODE_DAILY, "seed": Day.day_seed(d["day"]), "day": d["day"], "date": d["date"]})
		"practice":
			var d2 := _today()
			var s := Time.get_ticks_usec() & 0xFFFFFFFF
			_start({"mode": Sim.MODE_PRACTICE, "seed": s if s != 0 else 1, "day": d2["day"], "date": d2["date"]})


# 端末の今日の日付。始めた時の日付で回を決める(E-12)。
func _today() -> Dictionary:
	var t := Time.get_date_dict_from_system()
	var y := int(t["year"])
	var m := int(t["month"])
	var dd := int(t["day"])
	return {"day": Day.day_index(y, m, dd), "date": Day.date_string(y, m, dd)}


# --- S2 プレイ ---

func _start(r: Dictionary) -> void:
	_clear()
	run = r
	screen = "play"
	play = Play.new()
	var st: Dictionary = store.settings()
	play.shake_on = st["shake"]
	play.reduce_flash = st["reduce_flash"]
	stage.add_child(play)
	play.start(int(r["mode"]), int(r["seed"]))
	play.finished.connect(_on_finished)
	play.pause_requested.connect(_pause)
	current = play


func _pause() -> void:
	if play == null or pause_view != null or not play.is_playing():
		return
	play.set_paused(true)
	pause_view = Pause.new()
	pause_view.build()
	pause_view.picked.connect(_on_pause)
	stage.add_child(pause_view)


func _on_pause(what: String) -> void:
	match what:
		"resume":
			pause_view.queue_free()
			pause_view = null
			play.set_paused(false)  # 押した tick から再開(待ち時間なし)
		"restart":
			_start(run)  # 同じ入口を初めから。今日の並びの 1 回目には数えない
		"settings":
			_show_settings("pause")
		"title":
			_show_title()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_pause()  # E-7: 戻っても自動では再開しない
	elif what == NOTIFICATION_WM_MOUSE_EXIT and play != null:
		play.cancel_drag()  # E-5: 画面の外で離した操作は突進にしない


# タブが裏に回ったら一時停止にする。Web では通知が来ないことがあるので、ブラウザにも聞く(ParryDuel と同じ)。
func _watch_visibility() -> void:
	if not OS.has_feature("web"):
		return
	_visibility_cb = JavaScriptBridge.create_callback(func(_args: Array) -> void: _pause())
	var doc: Variant = JavaScriptBridge.get_interface("document")
	if doc != null:
		doc.addEventListener("visibilitychange", _visibility_cb)


# --- S3 結果 ---

func _on_finished(result: Dictionary) -> void:
	var rec := store.record(int(run["mode"]), int(run["day"]), int(result["points"]))
	var text := Share.make(run["date"], int(run["mode"]), rec["first_today"], result)
	_clear()
	screen = "result"
	var r := Result.new()
	r.build(result, rec, text)
	r.retry.connect(func() -> void: _start(run))  # FR-19: 同じ入口。今日の並びは同じ種
	r.to_title.connect(_show_title)
	stage.add_child(r)
	current = r
	if auto:
		print("SMOKE result %s" % JSON.stringify(result))


# --- S4 設定 ---

func _show_settings(from: String) -> void:
	settings_from = from
	var s := Settings.new()
	s.build(store)
	s.back.connect(_settings_back.bind(s))
	if from == "pause":
		pause_view.visible = false
		var dim := ColorRect.new()
		dim.color = Color(Kit.C_BG, 0.97)
		s.add_child(Kit.place(dim, -1000, -1000, B.SCREEN_W + 2000, B.SCREEN_H + 2000))
		s.move_child(dim, 0)
		stage.add_child(s)
		_settings_overlay = s
		screen = "settings"
		current = s
	else:
		_clear()
		screen = "settings"
		stage.add_child(s)
		current = s


func _settings_back(s: Control) -> void:
	Sfx.set_volume(int(store.settings()["volume"]))
	if settings_from == "pause" and play != null:
		var st: Dictionary = store.settings()
		play.shake_on = st["shake"]
		play.reduce_flash = st["reduce_flash"]
		play.fx.reduce_flash = st["reduce_flash"]
		s.queue_free()
		_settings_overlay = null
		pause_view.visible = true
		current = play
		screen = "play"
	else:
		_show_title()


# --- 測る・確かめる窓口(読むだけ) ---

func _after_draw() -> void:
	var now := Time.get_ticks_usec()
	if _last_frame > 0 and frame_ms.size() < 20000:
		frame_ms.append((now - _last_frame) / 1000.0)
	_last_frame = now
	if play != null and play.dash_started and play.input_at > 0:
		if lat_ms.size() < 2000:
			lat_ms.append((now - play.input_at) / 1000.0)
		play.input_at = 0
	if debug and OS.has_feature("web"):
		JavaScriptBridge.eval("window.dcState=" + JSON.stringify(JSON.stringify(state())), true)


func state() -> Dictionary:
	var out := {"screen": screen, "paused": pause_view != null, "buttons": {}, "sfx": Sfx.played, "unlocked": Sfx.unlocked,
		"save_failed": store.write_failed, "load_failed": store.load_failed, "lat": _pct(lat_ms), "frame": _pct(frame_ms)}
	var root: Control = pause_view if pause_view != null and pause_view.visible else current
	if root != null:
		for b in root.find_children("*", "Button", true, false):
			var btn := b as Button
			if btn.is_visible_in_tree() and not btn.disabled:
				out["buttons"][String(btn.name)] = [btn.global_position.x + btn.size.x / 2, btn.global_position.y + btn.size.y / 2]
	if play != null and play.sim != null:
		var s := play.sim.snapshot()
		out["play"] = {"x": s["x"], "y": s["y"], "tick": s["tick"], "time_left": s["time_left"], "points": s["points"],
			"charges": s["charges"], "hp": s["hp"], "enemies": s["enemies"].size(), "bullets": s["bullets"].size(), "pos": [play.position.x, play.position.y]}
	return out


static func _pct(list: Array) -> Dictionary:
	if list.is_empty():
		return {"n": 0}
	var s := list.duplicate()
	s.sort()
	return {"n": s.size(), "p50": s[s.size() / 2], "p95": s[mini(int(ceil(s.size() * 0.95)) - 1, s.size() - 1)], "max": s[-1]}


func _process(_delta: float) -> void:
	if auto:
		_auto_step()  # 窓なしでは frame_post_draw が来ないので、ここで回す


# 窓なしの確かめ(--auto)。プレイでは、印の明けた一番近い敵へ、マウスで払う操作を流す。結果では、もう1回を押して終わる。
func _auto_step() -> void:
	_auto_frame += 1
	if screen == "play" and play != null and play.is_playing() and _auto_frame % 12 == 0:
		var s := play.sim.snapshot()
		if s["dashing"] or int(s["freeze_left"]) > 0:
			return
		var me := Vector2(s["x"], s["y"])
		var best: Variant = null
		for e: Dictionary in s["enemies"]:
			if int(e["mark"]) == 0 and (best == null or me.distance_squared_to(Vector2(e["x"], e["y"])) < me.distance_squared_to(Vector2(best["x"], best["y"]))):
				best = e
		if best != null:
			var to := Vector2(best["x"], best["y"])
			for down: bool in [true, false]:
				var ev := InputEventMouseButton.new()
				ev.button_index = MOUSE_BUTTON_LEFT
				ev.pressed = down
				ev.position = me if down else me + (to - me).normalized() * 100.0
				play.pointer(ev)
	elif screen == "result" and _auto_rounds == 0 and not current._retry.disabled:
		_auto_rounds = 1
		current._retry.pressed.emit()
	elif screen == "play" and _auto_rounds == 1 and play.is_playing():
		print("SMOKE_OK frames=%d lat=%s frame=%s" % [_auto_frame, JSON.stringify(_pct(lat_ms)), JSON.stringify(_pct(frame_ms))])
		get_tree().quit(0)
