# 突進の幾何(仕様書 §9.4)。線分と円の距離・場の内側への切り詰め・1 tick の移動・狙いの予測。
# 狙いの線(preview)と本番(sim)は、同じ dash_step と segment_hits_circle を使う(INV-4)。平方根と四則だけ(INV-5)。
extends RefCounted

const B := preload("res://core/balance.gd")


# 線分 (ax, ay)-(bx, by) と点 (cx, cy) の距離が r 以下なら真。
static func segment_hits_circle(ax: float, ay: float, bx: float, by: float, cx: float, cy: float, r: float) -> bool:
	var dx := bx - ax
	var dy := by - ay
	var len2 := dx * dx + dy * dy
	var t := 0.0
	if len2 > 0.0:
		t = clampf(((cx - ax) * dx + (cy - ay) * dy) / len2, 0.0, 1.0)
	var qx := ax + dx * t - cx
	var qy := ay + dy * t - cy
	return qx * qx + qy * qy <= r * r


# (ix, iy) を長さ 1 の向きにする。(0, 0) は [0, 0]。
static func unit(ix: int, iy: int) -> Array:
	var l := sqrt(float(ix * ix + iy * iy))
	if l == 0.0:
		return [0.0, 0.0]
	return [ix / l, iy / l]


# 1 tick の突進の移動。場の内側(端から PLAYER_RADIUS 以上)に切り詰めた位置 [x, y] を返す。
static func dash_step(x: float, y: float, ux: float, uy: float) -> Array:
	var s := B.DASH_DISTANCE / B.DASH_TICKS
	return [clampf(x + ux * s, B.FIELD_X0 + B.PLAYER_RADIUS, B.FIELD_X1 - B.PLAYER_RADIUS),
		clampf(y + uy * s, B.FIELD_Y0 + B.PLAYER_RADIUS, B.FIELD_Y1 - B.PLAYER_RADIUS)]


# 敵を斬れるか(印の間は斬れない)。e は sim の敵 { x, y, r, mark }。
static func can_cut(ax: float, ay: float, bx: float, by: float, e: Dictionary) -> bool:
	return int(e["mark"]) == 0 and segment_hits_circle(ax, ay, bx, by, e["x"], e["y"], float(e["r"]) + B.BLADE_HALF_WIDTH)


# 狙いの予測(FR-4)。今の敵の位置で、本番と同じ刻みの移動と判定をする。{ end_x, end_y, hit_ids }
static func preview(px: float, py: float, ix: int, iy: int, enemies: Array) -> Dictionary:
	var u := unit(ix, iy)
	var hit_ids: Array = []
	var x := px
	var y := py
	for k in B.DASH_TICKS:
		var p := dash_step(x, y, u[0], u[1])
		for e: Dictionary in enemies:
			if not hit_ids.has(e["id"]) and can_cut(x, y, p[0], p[1], e):
				hit_ids.append(e["id"])
		x = p[0]
		y = p[1]
	return {"end_x": x, "end_y": y, "hit_ids": hit_ids}
