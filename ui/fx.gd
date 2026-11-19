# 演出(仕様書 §9.12)。sim.events() を受けて、通り道の線・斬った印・割れる破片・点の表示・縁の赤・回数の印の動きを持ち、描く。
# 時間は画面の時計(ms)で数える。止め(sim の tick)は sim の freeze_left を見て、明けた時に割る(INV-7)。判定はしない(INV-1)。
extends RefCounted

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Score := preload("res://core/score.gd")
const Kit := preload("res://ui/kit.gd")

var reduce_flash := false
var trail: Dictionary = {}  # { ax, ay, end_at }(end_at は突進の終わり。-1 は突進中)
var corpses: Array = []  # 斬った敵 { x, y, kind, r }。止めが明けたら割る
var shards: Array = []  # { x, y, vx, vy, at, color }
var popups: Array = []  # { text, x, y, at, big }
var edge_at := -100000
var whiff_at := -100000
var no_charge_at := -100000
var _shatter_wait := false


# 1 つの出来事を受ける。now は ms。
func on_event(e: Dictionary, now: int) -> void:
	match e["type"]:
		"dash_start":
			trail = {"ax": e["x"], "ay": e["y"], "end_at": -1}
		"cut_mark":
			corpses.append({"x": e["x"], "y": e["y"], "kind": e["kind"], "r": e["r"]})
		"dash_end":
			if not trail.is_empty():
				trail["end_at"] = now
				trail["bx"] = e["x"]
				trail["by"] = e["y"]
			if int(e["n"]) >= 1:
				_shatter_wait = true
				var text := S.POP % [int(e["n"]), Score.mult_text(int(e["mult10"])), Score.comma(int(e["points"]))]
				popups.append({"text": text, "x": e["x"], "y": e["y"] - 40.0, "at": now, "big": int(e["n"]) >= B.BIG_CUT})
			else:
				whiff_at = now
		"no_charge":
			no_charge_at = now
		"hurt":
			edge_at = now


# 止めが明けたら、印のついた敵を同時に割る(破片 6 個、300 ms)。
func update(now: int, freeze_left: int) -> void:
	if _shatter_wait and freeze_left == 0:
		_shatter_wait = false
		for c: Dictionary in corpses:
			for k in B.SHARDS_PER_ENEMY:
				# 6 方向(60 度ごと)。単位円上の点は sin・cos を使わず表で持つ
				var d: Vector2 = [Vector2(1, 0), Vector2(0.5, 0.866), Vector2(-0.5, 0.866), Vector2(-1, 0), Vector2(-0.5, -0.866), Vector2(0.5, -0.866)][k]
				shards.append({"x": c["x"], "y": c["y"], "vx": d.x * B.SHARD_SPEED, "vy": d.y * B.SHARD_SPEED, "at": now, "color": Kit.kind_color(c["kind"])})
		corpses.clear()
	shards = shards.filter(func(s: Dictionary) -> bool: return now - int(s["at"]) < B.SHARD_MS)
	popups = popups.filter(func(p: Dictionary) -> bool: return now - int(p["at"]) < B.POPUP_MS)
	if not trail.is_empty() and int(trail["end_at"]) >= 0 and now - int(trail["end_at"]) >= B.TRAIL_MS:
		trail = {}


func is_whiffing(now: int) -> bool:
	return now - whiff_at < B.WHIFF_MS


func is_no_charge(now: int) -> bool:
	return now - no_charge_at < B.NO_CHARGE_MS


# 場の上に描く物(通り道の線・斬った敵と斜めの線・破片)。px, py は今の自分の位置。
func draw_world(ci: CanvasItem, now: int, px: float, py: float) -> void:
	if not trail.is_empty():
		var a := Vector2(trail["ax"], trail["ay"])
		var running := int(trail["end_at"]) < 0
		var b := Vector2(px, py) if running else Vector2(trail["bx"], trail["by"])
		var alpha := 0.7 if running else 0.7 * (1.0 - float(now - int(trail["end_at"])) / B.TRAIL_MS)
		ci.draw_line(a, b, Color(Kit.C_LINE, alpha), 3.0, true)
	for c: Dictionary in corpses:
		var p := Vector2(c["x"], c["y"])
		var r: float = c["r"]
		ci.draw_circle(p, r, Color(Kit.kind_color(c["kind"]), 0.5))
		ci.draw_line(p + Vector2(-r - 6, r + 6), p + Vector2(r + 6, -r - 6), Kit.C_LINE, 4.0, true)
	for s: Dictionary in shards:
		var t := float(now - int(s["at"])) / B.SHARD_MS
		var sp := Vector2(s["x"] + s["vx"] * t * B.SHARD_MS / 1000.0, s["y"] + s["vy"] * t * B.SHARD_MS / 1000.0)
		var sz := 7.0 * (1.0 - t) + 1.0
		ci.draw_colored_polygon(PackedVector2Array([sp + Vector2(0, -sz), sp + Vector2(sz, 0), sp + Vector2(0, sz), sp + Vector2(-sz, 0)]),
			Color(s["color"], 1.0 - t))


# 画面の一番上に描く物(点の表示・縁の赤)。
func draw_top(ci: CanvasItem, now: int) -> void:
	var f := Kit.font(800)
	for p: Dictionary in popups:
		var t := float(now - int(p["at"])) / B.POPUP_MS
		var size := int(32 * (B.POPUP_BIG if p["big"] else 1.0))
		var y: float = p["y"] - B.POPUP_RISE * t
		var w := 600.0
		var x := clampf(p["x"] - w / 2.0, 0.0, B.SCREEN_W - w)
		ci.draw_string_outline(f, Vector2(x, y), p["text"], HORIZONTAL_ALIGNMENT_CENTER, w, size, 6, Color(Kit.C_BG, 1.0 - t))
		ci.draw_string(f, Vector2(x, y), p["text"], HORIZONTAL_ALIGNMENT_CENTER, w, size, Color(Kit.C_TEXT, 1.0 - t))
	var et := float(now - edge_at) / B.EDGE_MS
	if et < 1.0:
		var a := (B.REDUCED_FLASH_ALPHA if reduce_flash else B.EDGE_ALPHA) * (1.0 - et)
		for k in 4:
			ci.draw_rect(Rect2(k * 6, k * 6, B.SCREEN_W - k * 12, B.SCREEN_H - k * 12), Color(Kit.C_DANGER, a * (1.0 - k / 4.0)), false, 6.0)
