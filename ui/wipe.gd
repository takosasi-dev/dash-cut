# 画面の切り替わり(v0.3.0、画面設計書 §11): 墨の幕を斜めの一太刀で斬り、線の所に和紙色の光る線を走らせて新しい画面を見せる。
# 見た目だけで入力は飲まない(新しい画面は最初から押せる。マウスも通す)。時計は Time の ms(Tween は使わない。テストは _process を手で回す)。
# 点滅を弱める 入 では幕も線も出さず、新しい画面の薄く→濃くだけ(main が FADE_MS で行う)。
extends Control

const B := preload("res://core/balance.gd")
const Kit := preload("res://ui/kit.gd")

const LEAN := 0.38  # 線の傾き(高さに対する横のずれ)

var view := Rect2(0, 0, 720, 1280)  # 見えている範囲(舞台の座標)。窓の形で 720×1280 より広い
var start_ms := -100000


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func run() -> void:
	start_ms = Time.get_ticks_msec()
	queue_redraw()


func running() -> bool:
	return Time.get_ticks_msec() - start_ms < B.WIPE_MS


func _process(_delta: float) -> void:
	if Time.get_ticks_msec() - start_ms <= B.WIPE_MS + 50:
		queue_redraw()


func _draw() -> void:
	var k := float(Time.get_ticks_msec() - start_ms) / B.WIPE_MS
	if k < 0.0 or k >= 1.0:
		return
	var lean := view.size.y * LEAN
	# 線の真ん中の x を、見えている範囲の左の外から右の外へ走らせる
	var x := lerpf(view.position.x - lean, view.end.x + lean, Kit.ease_out(k))
	var top := Vector2(x + lean / 2.0, view.position.y)
	var bottom := Vector2(x - lean / 2.0, view.end.y)
	var far := view.end.x + lean * 2.0 + 40.0  # 線の上の端より必ず右
	draw_colored_polygon(PackedVector2Array([top, Vector2(far, view.position.y), Vector2(far, view.end.y), bottom]), Kit.C_INK)
	var fade := 1.0 - k
	draw_line(top, bottom, Color(Kit.C_WASHI, 0.12 * fade), 28.0, true)
	draw_line(top, bottom, Color(Kit.C_WASHI, 0.9 * fade), 3.0, true)
