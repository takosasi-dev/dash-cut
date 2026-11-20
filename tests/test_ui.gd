# 画面の流れのテスト(AC-18・AC-20・AC-21・FR-2・FR-3・FR-19・FR-24・FR-25・E-5・E-6)。
# main.tscn を木に置き、入力のイベントを直接渡し、フレームは _process を呼んで進める(窓なしで確かめられる範囲)。
extends "res://tests/suite.gd"

const MainScene := preload("res://ui/main.tscn")
const Store := preload("res://save/save_store.gd")


static func kev(pk: int, pressed: bool = true, echo: bool = false) -> InputEventKey:
	var e := InputEventKey.new()
	e.pressed = pressed
	e.physical_keycode = pk as Key
	e.keycode = pk as Key
	e.echo = echo
	return e


static func mouse(down: bool, pos: Vector2, device: int = 0) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = pos
	e.device = device
	return e


static func touch(down: bool, pos: Vector2, index: int = 0) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.pressed = down
	e.position = pos
	e.index = index
	return e


func _main() -> Node:
	if FileAccess.file_exists(Store.PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Store.PATH))
	var m := MainScene.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(m)
	return m


func _done(m: Node) -> void:
	m.get_parent().remove_child(m)
	m.free()


static func click(m: Node, button_name: String) -> void:
	var root: Node = m.pause_view if m.pause_view != null and m.pause_view.visible else m.current
	var b := root.find_child(button_name, true, false) as Button
	b.pressed.emit()


static func frames(m: Node, n: int, dt: float = 1.0 / 60.0) -> void:
	for k in n:
		if m.play != null:
			m.play._process(dt)
		if m.current != null and m.current != m.play and m.current.has_method("_process"):
			m.current._process(dt)


# マウスで払う(押して、動かして、離す)。
static func swipe(m: Node, from: Vector2, to: Vector2) -> void:
	m.play.pointer(mouse(true, from))
	var mv := InputEventMouseMotion.new()
	mv.position = to
	m.play.pointer(mv)
	m.play.pointer(mouse(false, to))


static func finish(m: Node) -> void:
	m.play.sim.clock_running = true  # 斬らないと時計が進まない(FR-12)ので、動かしてから終わらせる
	while not m.play.sim.is_over():
		m.play.sim.step()
	m.play.finished.emit(m.play.sim.result())  # 終わった後の 400 ms を待たない


func test_ac18_flow_mouse() -> bool:
	var m := _main()
	eq(m.screen, "title", "S1 から始まる")
	click(m, "daily")
	eq(m.screen, "play", "今日の並びで S2")
	eq(int(m.run["mode"]), 0, "今日の並び")
	frames(m, 31)  # 印の 60 tick
	m.play._refresh()
	swipe(m, Vector2(300, 1000), Vector2(300, 900))
	frames(m, 12)
	eq(m.play.sim.cuts, 3, "上へ払うと T1 の 3 体を斬る")
	ok(m.play.sim.clock_running, "時計が動く")
	var seed_before: int = m.run["seed"]
	finish(m)
	eq(m.screen, "result", "S3")
	ok(m.current.share.begins_with("DashCut ") and m.current.share.contains(S.LABEL_DAILY_FIRST), "共有する文字(今日の並び・1回目)")
	ok(m.current._retry.disabled, "300 ms の前は押せない")
	m._input(kev(KEY_R))
	eq(m.screen, "result", "300 ms の前は R でも進まない")
	m.current._shown_at -= 1000
	frames(m, 1)
	click(m, "retry")
	eq(m.screen, "play", "もう1回")
	eq(int(m.run["seed"]), seed_before, "今日の並びは同じ種(FR-19)")
	finish(m)
	ok(not m.current.share.contains(S.LABEL_DAILY_FIRST), "2 回目は「今日の並び」")
	click(m, "title")
	eq(m.screen, "title", "タイトルへ")
	_done(m)
	return true


func test_drag_rules() -> bool:
	var m := _main()
	click(m, "practice")
	eq(int(m.run["mode"]), 1, "練習")
	var sim: Sim = m.play.sim
	swipe(m, Vector2(100, 100), Vector2(115, 115))
	ok(sim.pending == null, "24 px 未満は突進しない(E-1)")
	swipe(m, Vector2(100, 100), Vector2(100.4, 75.6))
	eq(sim.pending, [0, -24], "差を整数に丸めて渡す")
	sim.pending = null
	m.play.pointer(mouse(true, Vector2(0, 0), InputEvent.DEVICE_ID_EMULATION))
	m.play.pointer(mouse(false, Vector2(0, 300), InputEvent.DEVICE_ID_EMULATION))
	ok(sim.pending == null, "タッチから作られたマウスは捨てる")
	m.play.pointer(touch(true, Vector2(0, 0), 1))
	m.play.pointer(touch(false, Vector2(0, 300), 1))
	ok(sim.pending == null, "2 本目の指は見ない(E-6)")
	m.play.pointer(touch(true, Vector2(0, 0)))
	var d := InputEventScreenDrag.new()
	d.index = 0
	d.position = Vector2(-100, 0)
	m.play.pointer(d)
	m.play._refresh()
	ok(not m.play.field.aim.is_empty(), "押している間は狙いの線(FR-4)")
	m.play.pointer(touch(false, Vector2(-100, 0)))
	eq(sim.pending, [-100, 0], "1 本目の指で払う")
	sim.pending = null
	m.play.pointer(mouse(true, Vector2(0, 0)))
	m.play.pointer(mouse(true, Vector2(500, 500)))  # 離すイベントが来ないまま押し直した(E-5)
	m.play.pointer(mouse(false, Vector2(500, 510)))
	ok(sim.pending == null, "前の押し始めは捨てる")
	m.play.pointer(mouse(true, Vector2(0, 0)))
	m._notification(Node.NOTIFICATION_WM_MOUSE_EXIT)
	m.play.pointer(mouse(false, Vector2(0, 300)))
	ok(sim.pending == null, "画面の外へ出た操作は突進にしない")
	_done(m)
	return true


func test_keyboard_dash() -> bool:
	var m := _main()
	m._input(kev(KEY_ENTER))
	eq(m.screen, "play", "Enter で今日の並び")
	var sim: Sim = m.play.sim
	m._input(kev(KEY_SPACE))
	ok(sim.pending == null, "矢印を押していなければ何もしない")
	m._input(kev(KEY_UP))
	m._input(kev(KEY_LEFT))
	m.play._refresh()
	ok(not m.play.field.aim.is_empty(), "矢印の向きも狙いの線に出す")
	m._input(kev(KEY_SPACE))
	eq(sim.pending, [-1, -1], "斜めは同じ大きさの整数")
	m._input(kev(KEY_LEFT, false))
	m._input(kev(KEY_SPACE, true, true))
	eq(sim.pending, [-1, -1], "押しっぱなしのスペースは数えない")
	m._input(kev(KEY_SPACE))
	eq(sim.pending, [0, -1], "離した矢印は抜ける")
	_done(m)
	return true


func test_ac21_pause_freezes() -> bool:
	var m := _main()
	click(m, "daily")
	frames(m, 31)
	swipe(m, Vector2(300, 1000), Vector2(300, 900))
	frames(m, 20)
	ok(m.play.sim.clock_running, "時計が動いている")
	m._input(kev(KEY_ESCAPE))
	ok(m.pause_view != null, "Esc で一時停止")
	var t: int = m.play.sim.time_left
	frames(m, 120)
	eq(m.play.sim.time_left, t, "一時停止の間は減らない")
	swipe(m, Vector2(300, 1000), Vector2(300, 900))
	ok(m.play.sim.pending == null, "一時停止の間の払う操作は数えない")
	m._input(kev(KEY_ESCAPE))
	ok(m.pause_view == null, "Esc で続ける")
	frames(m, 2)
	ok(m.play.sim.time_left < t, "続けると進む")
	m._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	ok(m.pause_view != null, "裏に回ると一時停止(E-7)")
	t = m.play.sim.time_left
	frames(m, 60)
	eq(m.play.sim.time_left, t, "裏の間も減らない")
	m._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	ok(m.pause_view != null, "戻っても自動では再開しない")
	var seed_before: int = m.run["seed"]
	m._input(kev(KEY_R))
	ok(m.screen == "play" and m.pause_view == null and m.play.sim.tick == 0, "R でやり直す")
	eq(int(m.run["seed"]), seed_before, "同じ種")
	_done(m)
	return true


func test_pause_settings_back() -> bool:
	var m := _main()
	click(m, "daily")
	m._input(kev(KEY_ESCAPE))
	click(m, "settings")
	eq(m.screen, "settings", "一時停止から設定")
	click(m, "shake_off")
	click(m, "reduce_flash_on")
	click(m, "volume_25")
	eq(m.store.settings(), {"volume": 25, "shake": false, "reduce_flash": true}, "変えた時点で保存")
	eq(Store.new().settings()["volume"], 25, "読み直しても残る")
	m._input(kev(KEY_ESCAPE))
	eq(m.screen, "play", "戻ると一時停止へ")
	ok(m.pause_view != null and m.pause_view.visible, "一時停止の画面")
	ok(not m.play.shake_on and m.play.fx.reduce_flash, "設定がプレイに届く")
	click(m, "title")
	click(m, "settings")
	eq(m.screen, "settings", "タイトルから設定")
	click(m, "back")
	eq(m.screen, "title", "戻るとタイトル")
	_done(m)
	return true


func test_ac20_no_shake_when_off() -> bool:
	var m := _main()
	m.store.set_setting("shake", false)
	click(m, "practice")
	eq(m.play.shake_on, false, "揺れを切った設定")
	var now := Time.get_ticks_msec()
	m.play._on_event({"type": "dash_end", "n": 4, "points": 1600, "mult10": 10, "chain": 1, "x": 360.0, "y": 600.0}, now)
	m.play._on_event({"type": "hurt", "by": "bullet", "hp": 2}, now)
	frames(m, 3, 0.0)
	eq(m.play.position, Vector2.ZERO, "揺れを切ると、3 体以上を斬っても当たっても動かない")
	m.play.shake_on = true
	m.play._on_event({"type": "dash_end", "n": 3, "points": 900, "mult10": 10, "chain": 1, "x": 360.0, "y": 600.0}, Time.get_ticks_msec())
	var moved := false
	for k in 5:
		frames(m, 1, 0.0)
		moved = moved or m.play.position != Vector2.ZERO
	ok(moved, "入なら揺れる")
	_done(m)
	return true


func test_fr25_sound_after_first_input() -> bool:
	var m := _main()
	Sfx.unlocked = false
	var before: int = Sfx.played
	click(m, "daily")
	m.play._on_event({"type": "dash_start", "x": 0.0, "y": 0.0, "ux": 0.0, "uy": -1.0}, 0)
	eq(Sfx.played, before, "最初の操作の前は鳴らさない")
	m._input(mouse(true, Vector2(10, 10)))
	ok(Sfx.unlocked, "クリックで鳴らせるようになる")
	m.play._on_event({"type": "cut_mark", "id": 1, "kind": 0, "x": 0.0, "y": 0.0, "r": 18.0, "k": 2}, 0)
	ok(Sfx.played == before + 1 and Sfx.last_name == "cut", "斬った音")
	ok(absf(Sfx.last_pitch - pow(2.0, 2.0 / 12.0)) < 1e-6, "3 体目は 2 半音上がる")
	_done(m)
	return true


func test_title_records_and_load_failed() -> bool:
	var m := _main()
	var texts := _texts(m.current)
	ok(not texts.has(S.REC_NONE), "初めての起動では記録の行を出さない")
	m.store.record(1, 1, 18200)
	m._show_title()
	texts = _texts(m.current)
	ok(texts.has(S.REC_NONE), "今日まだ遊んでいなければ「まだ遊んでいない」")
	ok(texts.has(S.REC_BEST % "18,200"), "練習の最高")
	_done(m)
	var f := FileAccess.open(Store.PATH, FileAccess.WRITE)
	f.store_string("{broken")
	f.close()
	var m2 := MainScene.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(m2)
	ok(_texts(m2.current).has(S.LOAD_FAILED), "保存を読めなかった 1 行(E-9)")
	_done(m2)
	return true


static func _texts(root: Node) -> Array:
	return root.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)


func test_result_best_diff() -> bool:
	var m := _main()
	m.store.record(1, 1, 1000)
	click(m, "practice")
	m.play.sim.points = 2300
	finish(m)
	ok(_texts(m.current).has(S.RES_NEW_BEST % "1,300"), "最高 +1,300(新しい記録)")
	m.current._shown_at -= 1000
	frames(m, 1)
	m._input(kev(KEY_R))
	m.play.sim.points = 1500
	finish(m)
	ok(_texts(m.current).has(S.RES_TO_BEST % "800"), "最高まで −800")
	m.current.find_child("copy", true, false).pressed.emit()
	eq(m.current._copied.text, S.COPIED, "コピーの後の 1 行")
	_done(m)
	return true


func test_e8_frame_step_cap() -> bool:
	var m := _main()
	click(m, "practice")
	var t: int = m.play.sim.tick
	frames(m, 1, 1.0)
	eq(m.play.sim.tick - t, B.MAX_STEPS_PER_FRAME, "1 秒遅れたフレームでも 8 tick だけ進める")
	frames(m, 1)
	eq(m.play.sim.tick - t, B.MAX_STEPS_PER_FRAME + 2, "超えた分は捨てる")
	_done(m)
	return true


# 窓なしでは frame_post_draw が来ないので、Web で毎フレーム走る測りと状態の窓口をここで回す。
func test_after_draw_and_state() -> bool:
	var m := _main()
	m._after_draw()
	var st: Dictionary = m.state()
	ok(st["buttons"].has("daily") and st["buttons"].has("practice"), "タイトルのボタンの位置")
	click(m, "daily")
	frames(m, 31)
	swipe(m, Vector2(300, 1000), Vector2(300, 900))
	frames(m, 1)
	m._after_draw()
	eq(m.lat_ms.size(), 1, "指示から動き出しを描くまでを 1 回数える")
	m._after_draw()
	eq(m.lat_ms.size(), 1, "同じ突進は 2 回数えない")
	st = m.state()
	ok(st["play"]["tick"] > 0 and st["buttons"].has("pause"), "プレイの状態")
	m._input(kev(KEY_ESCAPE))
	m._after_draw()
	st = m.state()
	ok(st["paused"] and st["buttons"].has("resume") and not st["buttons"].has("pause"), "一時停止の状態")
	ok(m._pct([3.0, 1.0, 2.0])["p50"] == 2.0, "中央値")
	_done(m)
	return true


# ビューポートを通した入力(GUI のボタンと、場を払う _unhandled_input の振り分け)。
func test_input_routing_through_viewport() -> bool:
	var m := _main()
	click(m, "daily")
	var vp := m.get_viewport()
	var xf := vp.get_final_transform()  # 画面(720×1280)の位置 → 窓の位置
	frames(m, 31)
	vp.push_input(mouse(true, xf * Vector2(300, 1000)))
	var mv := InputEventMouseMotion.new()
	mv.position = xf * Vector2(300, 900)
	vp.push_input(mv)
	vp.push_input(mouse(false, xf * Vector2(300, 900)))
	eq(m.play.sim.pending, [0, -100], "場を払うと突進の指示")
	m.play.sim.pending = null
	vp.push_input(mouse(true, xf * (m.stage.position + Vector2(68, 68))))  # 画面は窓の真ん中に置く(E-17)
	vp.push_input(mouse(false, xf * (m.stage.position + Vector2(68, 68))))
	ok(m.play.sim.pending == null, "一時停止のボタンを押した操作は突進にしない")
	ok(m.pause_view != null, "一時停止のボタンで一時停止")
	_done(m)
	return true
