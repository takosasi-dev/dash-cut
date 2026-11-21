# キーボードでボタンを選ぶ(画面設計書 §11 のキーボード)。↑↓←→ で向きの一番近いボタンへ、Enter で押す。マウスでも押せる。
# 選んでいるボタンには Godot のフォーカスを置き、theme.tres の focus(朱の縁と帯)で見せる。動かすと select、押すと confirm の小さな音。
# スペースは使わない(遊びの突進のキーなので、終わった直後の連打で結果のボタンを押さないため)。
extends RefCounted

var buttons: Array[Button] = []
var sel := 0


func _init(list: Array[Button], first: int = 0) -> void:
	buttons = list
	for b in buttons:
		b.mouse_entered.connect(func() -> void:
			var i := buttons.find(b)
			if i != sel and not b.disabled:
				select(i)
				Sfx.play("select"))
		b.pressed.connect(func() -> void: Sfx.play("confirm"))
	select(first)


func current() -> Button:
	return buttons[sel] if sel < buttons.size() else null


# i 番を選ぶ。木に入る前でも呼べる(入った時にフォーカスを置く)。
func select(i: int) -> void:
	if i < 0 or i >= buttons.size():
		return
	sel = i
	var b := buttons[i]
	if b.is_inside_tree():
		b.grab_focus()
	elif not b.tree_entered.is_connected(_refocus):
		b.tree_entered.connect(_refocus, CONNECT_ONE_SHOT)


func _refocus() -> void:
	select(sel)


# キーを受ける。使ったら真。
func key(ev: InputEventKey) -> bool:
	if not ev.pressed or buttons.is_empty():
		return false
	var dirs := {KEY_UP: Vector2.UP, KEY_DOWN: Vector2.DOWN, KEY_LEFT: Vector2.LEFT, KEY_RIGHT: Vector2.RIGHT}
	var k := ev.physical_keycode
	if dirs.has(k):
		var to := nearest(sel, dirs[k])
		if to >= 0:
			select(to)
			Sfx.play("select")
		return true
	if (k == KEY_ENTER or k == KEY_KP_ENTER) and not ev.echo:
		var b := buttons[sel]
		if not b.disabled:
			b.pressed.emit()
		return true
	return false


# from 番から dir の向きにある一番近いボタン(真横・真上を重く見る)。無ければ -1。
func nearest(from: int, dir: Vector2) -> int:
	var c := _center(buttons[from])
	var best := -1
	var best_cost := INF
	for i in buttons.size():
		if i == from or not buttons[i].visible:
			continue
		var d := _center(buttons[i]) - c
		var along := d.dot(dir)
		if along <= 1.0:
			continue
		var cost := along + 2.5 * absf(d.dot(Vector2(-dir.y, dir.x)))
		if cost < best_cost:
			best_cost = cost
			best = i
	return best


static func _center(b: Button) -> Vector2:
	return b.position + b.size / 2.0
