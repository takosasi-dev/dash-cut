# 題字(v0.3.0、画面設計書 §11)。「DashCut」を明朝で描き、左下から右上への斜めの線で上下に斬って、上の片を線に沿ってずらす。
# 後ろに朱の払い(太い入りから細く抜ける形、かすれの筋)、右上に朱の落款「斬」。
# 入りの動き: 払いが LOGO_STROKE_MS で引かれ、続いて LOGO_SPLIT_MS で上の片がずれ、斬った線が光って薄く残る。still が真なら動かさず終わりの形で出す。
# 斬った片: 題字を 1 度だけ小さな SubViewport に描き、その絵を上と下の 2 枚の多角形に貼る(clip_children は Web の Compatibility で
# 周りが黒く抜けたので使わない)。
extends Control

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Kit := preload("res://ui/kit.gd")

const W := 640.0
const H := 300.0
const SIZE := 124  # 題字の字の大きさ
const BASE_Y := 200.0  # 題字の基線
const PIVOT := Vector2(318, 150)  # 斬る線が通る所
const DIR := Vector2(0.9701, -0.2425)  # 斬る線の向き(右上がり 14 度)
const SHIFT := 16.0  # 上の片が線に沿ってずれる長さ
const LIFT := 4.0  # 上の片が線から離れる幅(切れ目が見えるように)
const UP := Vector2(-0.2425, -0.9701)  # 斬る線に直角の上向き

var still := false
var start_ms := 0
var _vp: SubViewport


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(W, H)
	start_ms = Time.get_ticks_msec()
	_vp = SubViewport.new()
	_vp.size = Vector2i(int(W), int(H))
	_vp.transparent_bg = true
	_vp.disable_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var text := _Text.new()
	text.size = size
	_vp.add_child(text)
	add_child(_vp)


# 0〜1。払いが引かれた割合。
func stroke_k() -> float:
	return 1.0 if still else Kit.ease_out(float(Time.get_ticks_msec() - start_ms) / B.LOGO_STROKE_MS)


# 0〜1。上の片がずれた割合。
func split_k() -> float:
	return 1.0 if still else Kit.ease_out(float(Time.get_ticks_msec() - start_ms - B.LOGO_STROKE_MS) / B.LOGO_SPLIT_MS)


func _process(_delta: float) -> void:
	if Time.get_ticks_msec() - start_ms < B.LOGO_STROKE_MS + B.LOGO_SPLIT_MS + 400:
		queue_redraw()


func _draw() -> void:
	_brush(stroke_k())
	var s := split_k()
	# 斬る線が上と下の辺を切る所(題字の絵の中)
	var l := Vector2(0, PIVOT.y - PIVOT.x * DIR.y / DIR.x)
	var r := Vector2(W, PIVOT.y + (W - PIVOT.x) * DIR.y / DIR.x)
	var tex := _vp.get_texture()
	_piece(tex, PackedVector2Array([l, r, Vector2(W, H), Vector2(0, H)]), Vector2.ZERO)
	_piece(tex, PackedVector2Array([Vector2.ZERO, Vector2(W, 0), r, l]), (DIR * SHIFT + UP * LIFT) * s)
	# 斬った線: ずれた瞬間に和紙色に光って消え、字の上には墨の細い切れ目が残る
	if s > 0.0:
		var a := PIVOT - DIR * 270.0
		var b := PIVOT + DIR * 270.0
		draw_line(a, b, Kit.C_INK, 2.5 * s, true)
		var glow := 0.0 if still else maxf(0.0, 1.0 - float(Time.get_ticks_msec() - start_ms - B.LOGO_STROKE_MS - B.LOGO_SPLIT_MS) / 300.0)
		if glow > 0.0:
			draw_line(a - DIR * 30.0, b + DIR * 30.0, Color(Kit.C_WASHI, 0.12 * glow), 10.0, true)
			draw_line(a - DIR * 30.0, b + DIR * 30.0, Color(Kit.C_WASHI, 0.9 * glow), 1.5, true)
	_seal(Vector2(590, 64), 0.0 if s <= 0.0 else 1.0)


# 題字の絵の一部(pts の形)を、off だけずらして貼る。
func _piece(tex: Texture2D, pts: PackedVector2Array, off: Vector2) -> void:
	var uvs := PackedVector2Array()
	var at := PackedVector2Array()
	for p in pts:
		uvs.append(p / size)
		at.append(p + off)
	draw_colored_polygon(at, Color.WHITE, uvs, tex)


# 朱の払い: 左下の太い入りから右上へ細く抜ける。k は引かれた割合。
func _brush(k: float) -> void:
	var a := Vector2(30, 246)
	var b := Vector2(640, 96)
	var full_len := a.distance_to(b)
	var length := full_len * k
	if length < 8.0:
		return  # 短すぎると面が作れない
	var u := (b - a).normalized()
	var n := Vector2(-u.y, u.x)
	var top := PackedVector2Array()
	var bottom := PackedVector2Array()
	var steps := 24
	for i in steps + 1:
		var d := length * float(i) / steps
		var full := d / full_len  # 払い全体での位置(太さは全体の形で決める)
		var w := 30.0 * (1.0 - pow(full, 1.6)) + 1.0
		if full < 0.06:
			w *= 0.75 + 0.25 * full / 0.06  # 入りは少し丸く
		var p := a + u * d + n * (sin(full * 3.0) * 6.0)
		top.append(p + n * w * 0.55)
		bottom.append(p - n * w * 0.45)
	bottom.reverse()
	draw_colored_polygon(top + bottom, Color(Kit.C_SHU, 0.92))
	# かすれ: 抜けの方に墨の細い筋を通す
	for line: Array in [[0.45, -6.0, 1.6], [0.58, 4.0, 1.2], [0.7, -1.0, 1.0]]:
		var from: float = line[0]
		if k <= from + 0.02:
			continue
		var p0 := a + u * full_len * from + n * float(line[1])
		var p1 := a + u * length + n * float(line[1]) * 0.6
		draw_line(p0, p1, Color(Kit.C_INK, 0.85), line[2], true)


# 落款: 朱の四角に「斬」を白く抜く。少し傾ける。
func _seal(c: Vector2, a: float) -> void:
	if a <= 0.0:
		return
	var s := 58.0
	draw_set_transform(c, -0.07, Vector2.ONE)
	draw_rect(Rect2(-s / 2, -s / 2, s, s), Color(Kit.C_SHU, a))
	draw_rect(Rect2(-s / 2 + 4, -s / 2 + 4, s - 8, s - 8), Color(Kit.C_WASHI, 0.85 * a), false, 1.5)
	draw_string(Kit.num_font(), Vector2(-s / 2, 15), S.SEAL, HORIZONTAL_ALIGNMENT_CENTER, s, 40, Color(Kit.C_WASHI, a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


class _Text extends Control:
	func _draw() -> void:
		draw_string(Kit.num_font(), Vector2(0, BASE_Y), S.NAME, HORIZONTAL_ALIGNMENT_CENTER, W - 30.0, SIZE, Kit.C_WASHI)
