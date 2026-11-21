# UI の見た目(v0.3.0、画面設計書 §11)で足した分岐のテスト: キーでボタンを選ぶ(スペースでは押さない)・結果の最初の 300 ms は選びも動かさない・
# 切り替わりは見た目だけ(論理の画面はすぐ替わり、もう1回は動きなし、点滅を弱める 入 では幕を出さない)・新しい記録の判・
# HUD の帯の上や切り替わりの最中でも払える・題字の止まった形・状態の窓口の focus と moving。
extends "res://tests/suite.gd"

const MainScene := preload("res://ui/main.tscn")
const Store := preload("res://save/save_store.gd")
const Logo := preload("res://ui/logo.gd")


static func kev(pk: int, pressed: bool = true, echo: bool = false) -> InputEventKey:
	var e := InputEventKey.new()
	e.pressed = pressed
	e.physical_keycode = pk as Key
	e.keycode = pk as Key
	e.echo = echo
	return e


static func mouse(down: bool, pos: Vector2) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = pos
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


static func focus(m: Node) -> String:
	var f: Control = m.get_viewport().gui_get_focus_owner()
	return String(f.name) if f != null else ""


static func press(m: Node, button_name: String) -> void:
	var root: Node = m.pause_view if m.pause_view != null and m.pause_view.visible else m.current
	(root.find_child(button_name, true, false) as Button).pressed.emit()


static func finish(m: Node) -> void:
	m.play.sim.clock_running = true
	while not m.play.sim.is_over():
		m.play.sim.step()
	m.play.finished.emit(m.play.sim.result())


func test_title_menu_keys() -> bool:
	var m := _main()
	eq(focus(m), "daily", "最初は今日の並びを選んでいる")
	eq(m.state()["focus"], "daily", "状態の窓口にも出す")
	m._input(kev(KEY_UP))
	eq(focus(m), "daily", "上に何も無ければ動かない")
	m._input(kev(KEY_DOWN))
	eq(focus(m), "practice", "↓ で練習")
	m._input(kev(KEY_SPACE))
	eq(m.screen, "title", "スペースではメニューのボタンを押さない")
	m._input(kev(KEY_ENTER))
	ok(m.screen == "play" and int(m.run["mode"]) == 1, "Enter で選んだ練習")
	var p: Node = m.play
	m._input(kev(KEY_ENTER))
	ok(m.play == p and m.screen == "play", "Enter の連打で 2 回始まらない")
	_done(m)
	return true


func test_settings_grid_keys() -> bool:
	var m := _main()
	press(m, "settings")
	eq(focus(m), "volume_75", "設定は今の音量を選んで開く")
	m._input(kev(KEY_RIGHT))
	eq(focus(m), "volume_100", "→ で隣")
	m._input(kev(KEY_DOWN))
	eq(focus(m), "shake_off", "↓ で下の行の近い方")
	m._input(kev(KEY_ENTER))
	eq(m.store.settings()["shake"], false, "Enter で押す(揺れを切る)")
	ok((m.current.find_child("shake_off", true, false) as Button).theme_type_variation == &"OnButton", "選んだ値は塗る")
	m._input(kev(KEY_ESCAPE))
	eq(m.screen, "title", "Esc で戻る")
	_done(m)
	return true


func test_result_focus_and_lock() -> bool:
	var m := _main()
	press(m, "practice")
	finish(m)
	eq(m.screen, "result", "結果")
	eq(focus(m), "retry", "もう1回を最初から選んでいる(押せない間も)")
	m._input(kev(KEY_DOWN))
	eq(focus(m), "retry", "押せない 300 ms は選びも動かさない")
	m.current._shown_at -= 1000
	m.current._process(0.0)
	m._input(kev(KEY_DOWN))
	ok(focus(m) in ["copy", "title"], "↓ で下のボタン: " + focus(m))
	m._input(kev(KEY_UP))
	eq(focus(m), "retry", "↑ でもう1回へ戻る")
	m._input(kev(KEY_SPACE))
	eq(m.screen, "result", "スペースでは押さない(遊びの連打で進まない)")
	m._input(kev(KEY_ENTER))
	eq(m.screen, "play", "Enter でもう1回")
	_done(m)
	return true


# 遊びで矢印を押したまま終わると、結果に押しっぱなしのリピート(echo)が届く。それで「もう1回」から外れない。
func test_result_ignores_echo_arrows() -> bool:
	var m := _main()
	press(m, "practice")
	finish(m)
	m.current._shown_at -= 1000
	m.current._process(0.0)
	eq(focus(m), "retry", "もう1回を選んでいる")
	for k in [KEY_DOWN, KEY_RIGHT, KEY_LEFT, KEY_UP, KEY_DOWN]:
		m._input(kev(k, true, true))
	eq(focus(m), "retry", "echo の矢印では動かさない")
	eq(m.screen, "result", "結果のまま")
	m._input(kev(KEY_DOWN))
	ok(focus(m) in ["copy", "title"], "押し直した矢印では動く: " + focus(m))
	_done(m)
	return true


func test_transitions_are_visual_only() -> bool:
	var m := _main()
	ok(m.wipe.running() and m.moving(), "タイトルは斜めの一太刀で入る")
	press(m, "daily")
	eq(m.screen, "play", "論理の画面はすぐ替わる")
	ok(m.state()["moving"], "動きの間は moving")
	finish(m)
	eq(m.current.position.x, B.ENTER_SHIFT, "結果は横から寄る")
	m.current._shown_at -= 1000
	m.current._process(0.0)
	var st: Dictionary = m.state()
	eq(st["buttons"]["retry"], [360.0, 670.0], "ボタンの位置は止まった時の位置を出す")
	press(m, "retry")
	ok(m.screen == "play" and m._enter_node == null and m.current.modulate.a == 1.0, "もう1回は動きを付けずにすぐ遊びへ")
	m.store.set_setting("reduce_flash", true)
	m.wipe.start_ms = -100000
	m._show_title()
	ok(not m.wipe.running(), "点滅を弱める 入 では幕を出さない")
	eq(m._enter_ms, B.FADE_MS, "薄く→濃くだけ")
	ok(m.backdrop.reduce_flash and m.current.logo.still, "地の斬り線と題字の動きも止める")
	_done(m)
	return true


func test_new_best_stamp() -> bool:
	var m := _main()
	m.store.record(1, 1, 1000)
	press(m, "practice")
	m.play.sim.points = 2300
	finish(m)
	var r: Node = m.current
	eq(r.stamp_k(), -1.0, "数え上げの間は判を出さない")
	r._shown_at -= B.COUNT_MS + B.STAMP_MS
	eq(r.stamp_k(), 1.0, "数え上げの後に新しい記録の判")
	r._process(0.0)
	m._input(kev(KEY_R))
	m.play.sim.points = 100
	finish(m)
	m.current._shown_at -= 5000
	eq(m.current.stamp_k(), -1.0, "記録でなければ判は出さない")
	_done(m)
	return true


# HUD の帯や切り替わりの幕は描くだけ(Control で入力を止めない)。帯の上から払っても、幕が走っている間に払っても突進になる。
func test_swipe_on_band_and_during_wipe() -> bool:
	var m := _main()
	press(m, "daily")
	for k in 31:
		m.play._process(1.0 / 60.0)
	var vp := m.get_viewport()
	var xf := vp.get_final_transform()
	ok(m.wipe.running(), "幕が走っている")
	for pair: Array in [[Vector2(360, 120), Vector2(360, 20)], [Vector2(360, 1230), Vector2(360, 1130)]]:
		m.play.sim.pending = null
		vp.push_input(mouse(true, xf * (m.stage.position + pair[0])))
		var mv := InputEventMouseMotion.new()
		mv.position = xf * (m.stage.position + pair[1])
		vp.push_input(mv)
		vp.push_input(mouse(false, xf * (m.stage.position + pair[1])))
		eq(m.play.sim.pending, [0, -100], "帯の上から払える: %s" % [pair[0]])
	_done(m)
	return true


func test_logo_still() -> bool:
	var l := Logo.new()
	l.still = true
	ok(l.stroke_k() == 1.0 and l.split_k() == 1.0, "動かさない時は終わりの形")
	var l2 := Logo.new()
	ok(l2.stroke_k() < 1.0 and l2.split_k() <= 0.0, "入りは払いから")
	l.free()
	l2.free()
	return true
