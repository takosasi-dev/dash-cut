# タイトル・設定・結果の地(v0.3.0、画面設計書 §11)。薄墨のにじみがゆっくり動き、小さな塵が上へ漂う。
# slashes が真なら(タイトルだけ)、SLASH_EVERY_MS ごとに細い和紙色の斬り線が 1 本走って消える。点滅を弱める 入 では斬り線を出さない。
# 安い _draw だけ(丸と線)。画面全体にかける shader は使わない。見えている範囲(view)いっぱいに描く。
extends Control

const B := preload("res://core/balance.gd")
const Kit := preload("res://ui/kit.gd")

const BLOBS := [[0.22, 0.18, 420.0, 0.00], [0.82, 0.46, 520.0, 1.70], [0.30, 0.86, 460.0, 3.10]]  # x, y(view に対する割合), 半径, 位相
const DUST := 30

var view := Rect2(0, 0, 720, 1280)
var slashes := false
var reduce_flash := false
var _t0 := 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_t0 = Time.get_ticks_msec()


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	var t := float(Time.get_ticks_msec() - _t0) / 1000.0
	# にじみ: 大きな丸を薄く重ねて、真ん中ほど濃い薄墨のぼかしにする
	for b: Array in BLOBS:
		var c := view.position + view.size * Vector2(b[0], b[1]) + Vector2(sin(t * 0.07 + b[3]), cos(t * 0.05 + b[3])) * 60.0
		var r: float = b[2]
		for i in 8:
			draw_circle(c, r * (1.0 - i * 0.11), Color(Kit.C_USU, 0.035))
	# 塵: 決まった並びの点が、ゆっくり上へ流れる
	for i in DUST:
		var fx := fmod(i * 0.6180339 + 0.13, 1.0)
		var speed := 8.0 + 10.0 * fmod(i * 0.371, 1.0)
		var fy := fmod(fmod(i * 0.4142, 1.0) * view.size.y - t * speed, view.size.y)
		if fy < 0.0:
			fy += view.size.y
		var p := view.position + Vector2(fx * view.size.x + sin(t * 0.3 + i) * 12.0, fy)
		draw_circle(p, 1.2 + fmod(i * 0.29, 1.0) * 1.6, Color(Kit.C_WASHI, 0.10 + 0.12 * fmod(i * 0.53, 1.0)))
	if slashes and not reduce_flash:
		_slash()


# 斬り線: SLASH_EVERY_MS ごとに 1 本。180 ms で伸び、SLASH_MS で消える。場所と向きは回の番号で決める。
func _slash() -> void:
	var now := Time.get_ticks_msec() - _t0
	var n := now / B.SLASH_EVERY_MS
	var age := now - n * B.SLASH_EVERY_MS
	if n == 0 or age > B.SLASH_MS:
		return
	var h := fmod(n * 0.7548776, 1.0)
	var c := view.position + view.size * Vector2(0.15 + 0.7 * h, 0.2 + 0.6 * fmod(n * 0.5698403, 1.0))
	var u := Vector2(1.0, -0.42 - 0.3 * fmod(n * 0.31, 1.0)).normalized()
	var grow := Kit.ease_out(float(age) / 180.0)
	var half := 420.0
	var a := c - u * half
	var b := a + u * half * 2.0 * grow
	var fade := 1.0 - clampf(float(age - 180) / float(B.SLASH_MS - 180), 0.0, 1.0)
	draw_line(a, b, Color(Kit.C_WASHI, 0.05 * fade), 16.0, true)
	draw_line(a, b, Color(Kit.C_WASHI, 0.35 * fade), 1.5, true)
