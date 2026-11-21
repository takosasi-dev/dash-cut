# 画面の切り替え(S1〜S5)・キーの振り分け・保存・自動の一時停止を受け持つ。ゲームの決まりは持たない(INV-1)。
# 払う操作は ui/play.gd が _unhandled_input で受ける(ボタンを押した操作は突進にしない)。
# 画面の切り替わり(v0.3.0、画面設計書 §11)は見た目だけ: 論理の画面はすぐ替わり、新しい画面は最初から押せる。斜めの一太刀(ui/wipe.gd)と
# 薄く→濃く・横から寄る動きを Time の ms で付ける。「もう1回」「やり直す」は動きを付けない。点滅を弱める 入 では薄く→濃くだけ。
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
const Wipe := preload("res://ui/wipe.gd")
const Backdrop := preload("res://ui/backdrop.gd")

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
var backdrop: Backdrop
var wipe: Wipe
var _enter_node: Control = null  # 入りの動きの途中の画面
var _enter_at := -100000
var _enter_ms := 0
var _enter_from := 0.0  # 入りの始めの濃さ
var _enter_shift := 0.0


func _ready() -> void:
	stage = Control.new()
	stage.size = Vector2(B.SCREEN_W, B.SCREEN_H)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	var bg := ColorRect.new()
	bg.color = Kit.C_BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(Kit.place(bg, -4000, -4000, B.SCREEN_W + 8000, B.SCREEN_H + 8000))
	backdrop = Backdrop.new()
	stage.add_child(backdrop)
	wipe = Wipe.new()
	stage.add_child(wipe)
	store = Store.new()
	Sfx.set_volume(int(store.settings()["volume"]))
	debug = _flag("debug")
	auto = OS.get_cmdline_user_args().has("--auto")
	_watch_visibility()
	get_viewport().size_changed.connect(_center)
	_center()
	RenderingServer.frame_post_draw.connect(_after_draw)
	_show_title()
	if auto:
		_on_title("daily")


# 縦横比が 9:16 でない窓では、720×1280 を真ん中に置き、余りは背景の色で埋める(E-17)。
# project.godot の aspect は expand(keep だと余りが黒く塗られる)。
func _center() -> void:
	var r := get_viewport().get_visible_rect()
	stage.position = (r.position + (r.size - Vector2(B.SCREEN_W, B.SCREEN_H)) / 2.0).round()
	var view := Rect2(r.position - stage.position, r.size)  # 見えている範囲(舞台の座標)
	backdrop.view = view
	wipe.view = view


func _reduce() -> bool:
	return bool(store.settings()["reduce_flash"])


# 新しい画面を舞台に置き、current にする。motion: "wipe"(斜めの一太刀と入り)/ "fade"(入りだけ)/ "none"。
func _show(node: Control, motion: String) -> void:
	stage.add_child(node)
	stage.move_child(wipe, -1)
	current = node
	_enter_node = null
	if motion == "none":
		return
	var reduce := _reduce()
	_enter_node = node
	_enter_at = Time.get_ticks_msec()
	_enter_ms = B.FADE_MS if reduce else B.ENTER_MS
	_enter_from = 0.0 if motion == "wipe" or reduce else 0.45
	_enter_shift = 0.0 if reduce else B.ENTER_SHIFT
	_step_enter()
	if motion == "wipe" and not reduce:
		wipe.run()


func _step_enter() -> void:
	if _enter_node == null or not is_instance_valid(_enter_node):
		_enter_node = null
		return
	var k := Kit.ease_out(float(Time.get_ticks_msec() - _enter_at) / _enter_ms)
	_enter_node.modulate.a = lerpf(_enter_from, 1.0, k)
	_enter_node.position.x = _enter_shift * (1.0 - k)
	if k >= 1.0:
		_enter_node = null


# 入りの動きか斜めの一太刀が走っている間は真(撮る時に待つ)。
func moving() -> bool:
	return _enter_node != null or wipe.running()


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
		if c.get_index() == 0 or c == backdrop or c == wipe:
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
	t.build(store, d["day"], d["date"], _reduce())
	t.chosen.connect(_on_title)
	_backdrop(true)
	_show(t, "wipe")


func _backdrop(slashes: bool) -> void:
	backdrop.visible = true
	backdrop.slashes = slashes
	backdrop.reduce_flash = _reduce()


func _on_title(what: String) -> void:
	match what:
		"settings":
			_show_settings("title")
		"daily":
			var d := _today()
			_start({"mode": Sim.MODE_DAILY, "seed": Day.day_seed(d["day"]), "day": d["day"], "date": d["date"]}, "wipe")
		"practice":
			var d2 := _today()
			var s := Time.get_ticks_usec() & 0xFFFFFFFF
			_start({"mode": Sim.MODE_PRACTICE, "seed": s if s != 0 else 1, "day": d2["day"], "date": d2["date"]}, "wipe")


# 端末の今日の日付。始めた時の日付で回を決める(E-12)。
func _today() -> Dictionary:
	var t := Time.get_date_dict_from_system()
	var y := int(t["year"])
	var m := int(t["month"])
	var dd := int(t["day"])
	return {"day": Day.day_index(y, m, dd), "date": Day.date_string(y, m, dd)}


# --- S2 プレイ ---

# motion: タイトルからは "wipe"。もう1回・やり直すは "none"(押してすぐ遊べるように動きを付けない)。
func _start(r: Dictionary, motion: String = "none") -> void:
	_clear()
	run = r
	screen = "play"
	play = Play.new()
	var st: Dictionary = store.settings()
	play.shake_on = st["shake"]
	play.reduce_flash = st["reduce_flash"]
	backdrop.visible = false
	_show(play, motion)
	play.start(int(r["mode"]), int(r["seed"]))
	play.finished.connect(_on_finished)
	play.pause_requested.connect(_pause)


func _pause() -> void:
	if play == null or pause_view != null or not play.is_playing():
		return
	play.set_paused(true)
	pause_view = Pause.new()
	pause_view.build()
	pause_view.picked.connect(_on_pause)
	stage.add_child(pause_view)
	stage.move_child(wipe, -1)


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
	r.build(result, rec, text, _reduce())
	r.retry.connect(func() -> void: _start(run))  # FR-19: 同じ入口。今日の並びは同じ種
	r.to_title.connect(_show_title)
	_backdrop(false)
	_show(r, "fade")  # 「もう1回」の選びの印が幕に隠れないように、幕は使わない
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
		s.add_child(Kit.place(dim, -4000, -4000, B.SCREEN_W + 8000, B.SCREEN_H + 8000))
		s.move_child(dim, 0)
		_settings_overlay = s
		screen = "settings"
		_show(s, "fade")
	else:
		_clear()
		screen = "settings"
		_backdrop(false)
		_show(s, "wipe")


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
		pause_view.menu.select(2)  # 設定のボタンに選びを戻す
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
	var out := {"screen": screen, "paused": pause_view != null, "buttons": {}, "focus": "", "moving": moving(), "sfx": Sfx.played, "unlocked": Sfx.unlocked,
		"save_failed": store.write_failed, "load_failed": store.load_failed, "lat": _pct(lat_ms), "frame": _pct(frame_ms)}
	var root: Control = pause_view if pause_view != null and pause_view.visible else current
	if root != null:
		for b in root.find_children("*", "Button", true, false):
			var btn := b as Button
			if btn.is_visible_in_tree() and not btn.disabled:
				# 720×1280 の中の位置。入りの動きで画面がずれていても、止まった時の位置を出す
				var c := root.get_global_transform().affine_inverse() * btn.global_position + btn.size / 2
				out["buttons"][String(btn.name)] = [c.x, c.y]
		var f := get_viewport().gui_get_focus_owner()
		if f != null and root.is_ancestor_of(f):
			out["focus"] = String(f.name)
	if play != null and play.sim != null:
		var s := play.sim.snapshot()
		out["play"] = {"x": s["x"], "y": s["y"], "tick": s["tick"], "time_left": s["time_left"], "points": s["points"],
			"charges": s["charges"], "hp": s["hp"], "enemies": s["enemies"].size(), "bullets": s["bullets"].size(), "pos": [play.position.x, play.position.y],
			"chain": s["chain"], "dashing": s["dashing"], "freeze": s["freeze_left"], "clock": s["clock_running"],
			"foes": s["enemies"].map(func(e: Dictionary) -> Array: return [roundi(e["x"]), roundi(e["y"]), int(e["kind"]), int(e["mark"])])}
	return out


static func _pct(list: Array) -> Dictionary:
	if list.is_empty():
		return {"n": 0}
	var s := list.duplicate()
	s.sort()
	return {"n": s.size(), "p50": s[s.size() / 2], "p95": s[mini(int(ceil(s.size() * 0.95)) - 1, s.size() - 1)], "max": s[-1]}


func _process(_delta: float) -> void:
	_step_enter()
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
