# 演出(仕様書 §9.12 と、磨きで足した物 §14)。sim.events() を受けて、通り道の線・斬った印・止め・割れる破片と輪・点の表示・
# 縁の赤・回数と体力とつなぎの印の動き・終わりの理由を持ち、描く。時間は画面の時計(ms)で数え、止め(sim の tick)は sim の freeze_left を見る(INV-7)。
# 判定はしない(INV-1)。光は reduce_flash、揺れは play.gd の shake_on に従う。
extends RefCounted

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Score := preload("res://core/score.gd")
const Kit := preload("res://ui/kit.gd")

# 6 方向(60 度ごと)。単位円上の点を表で持つ
const DIRS := [Vector2(1, 0), Vector2(0.5, 0.866), Vector2(-0.5, 0.866), Vector2(-1, 0), Vector2(-0.5, -0.866), Vector2(0.5, -0.866)]

var reduce_flash := false
var trail: Dictionary = {}  # { ax, ay, ux, uy, end_at, bx, by }(end_at は突進の終わり。-1 は突進中)
var corpses: Array = []  # 斬った敵 { x, y, kind, r, at, ux, uy }。止めが明けたら割る
var shards: Array = []  # { x, y, vx, vy, at, color, size, rot, spin }
var rings: Array = []  # { x, y, r, at, grow }
var popups: Array = []  # { text, x, y, at, big, n }
var edge_at := -100000
var whiff_at := -100000
var no_charge_at := -100000
var refill_at := -100000  # 斬って回数が戻った
var flash_at := -100000  # 3 体以上の割れる瞬間
var hp_lost := {"at": -100000, "index": 0}
var chain_lost := {"at": -100000, "text": ""}
var chain_bump_at := -100000
var points_bump_at := -100000
var over := {"at": -1, "text": ""}
var freezing := false
var _shatter_wait := false
var _shatter_n := 0
var _chain := 0


# 1 つの出来事を受ける。now は ms。
func on_event(e: Dictionary, now: int) -> void:
	match e["type"]:
		"dash_start":
			trail = {"ax": e["x"], "ay": e["y"], "ux": e["ux"], "uy": e["uy"], "end_at": -1}
		"cut_mark":
			var u := Vector2(trail.get("ux", 0.0), trail.get("uy", -1.0))
			corpses.append({"x": e["x"], "y": e["y"], "kind": e["kind"], "r": e["r"], "at": now, "ux": u.x, "uy": u.y})
		"dash_end":
			if not trail.is_empty():
				trail["end_at"] = now
				trail["bx"] = e["x"]
				trail["by"] = e["y"]
			var n := int(e["n"])
			if n >= 1:
				_shatter_wait = true
				_shatter_n = n
				refill_at = now
				points_bump_at = now
				var text := S.POP % [n, Score.mult_text(int(e["mult10"])), Score.comma(int(e["points"]))]
				_add_popup(text, e["x"], e["y"] - 40.0, now, n)
			else:
				whiff_at = now
		"no_charge":
			no_charge_at = now
		"hurt":
			edge_at = now
			hp_lost = {"at": now, "index": int(e["hp"])}
		"over":
			over = {"at": now, "text": S.REASON_HP if e["reason"] == "hp" else S.REASON_TIME}


# 点の表示を足す。まだ見えている表示と重なるなら、その上へずらす。
func _add_popup(text: String, x: float, y: float, now: int, n: int) -> void:
	var moved := true
	var guard := 0
	while moved and guard < 20:
		moved = false
		guard += 1
		for p: Dictionary in popups:
			var py: float = p["y"] - B.POPUP_RISE * float(now - int(p["at"])) / B.POPUP_MS
			if absf(float(p["x"]) - x) < 280.0 and absf(py - y) < B.POPUP_GAP:
				y = py - B.POPUP_GAP
				moved = true
	y = maxf(y, B.FIELD_Y0 + B.POPUP_TOP_GAP)  # 上りきっても字の上の端が HUD の帯に掛からない(v0.3.0 で 40 から)
	popups.append({"text": text, "x": x, "y": y, "at": now, "big": n >= B.BIG_CUT, "n": n})


# つなぎの数の変化を受ける(snapshot を読むだけ)。増えたら字を跳ねさせ、0 に戻ったら前の数を赤く残す。
func on_chain(chain: int, now: int) -> void:
	if chain > _chain:
		chain_bump_at = now
	elif chain == 0 and _chain > 0:
		chain_lost = {"at": now, "text": S.HUD_CHAIN % [_chain, Score.mult_text(Score.mult10(_chain))]}
	_chain = chain


# 止めが明けたら、印のついた敵を同時に割る(1 体ごとに破片 6 個・輪 1 つ、300 ms)。3 体以上は輪を大きくし、場を白く光らせる。
func update(now: int, freeze_left: int) -> void:
	freezing = freeze_left > 0 and not corpses.is_empty()
	if _shatter_wait and freeze_left == 0:
		_shatter_wait = false
		var big := _shatter_n >= B.BIG_CUT
		if big:
			flash_at = now
		for c: Dictionary in corpses:
			var color := Kit.kind_color(c["kind"])
			var along := Vector2(c["ux"], c["uy"]) * B.SHARD_SPEED * 0.45  # 突進の向きへ流す
			var r: float = c["r"]
			for k in B.SHARDS_PER_ENEMY:
				var d: Vector2 = DIRS[k]
				var sp := B.SHARD_SPEED * (0.8 + 0.2 * (k % 3))
				shards.append({"x": c["x"] + d.x * r * 0.4, "y": c["y"] + d.y * r * 0.4, "vx": d.x * sp + along.x, "vy": d.y * sp + along.y,
					"at": now, "color": color, "size": r * 0.75, "rot": k * 1.05, "spin": 9.0 if k % 2 == 0 else -9.0})
			rings.append({"x": c["x"], "y": c["y"], "r": r, "at": now, "grow": B.RING_GROW_BIG if big else B.RING_GROW})
		corpses.clear()
	shards = shards.filter(func(s: Dictionary) -> bool: return now - int(s["at"]) < B.SHARD_MS)
	rings = rings.filter(func(r: Dictionary) -> bool: return now - int(r["at"]) < B.RING_MS)
	popups = popups.filter(func(p: Dictionary) -> bool: return now - int(p["at"]) < B.POPUP_MS)
	if not trail.is_empty() and int(trail["end_at"]) >= 0 and now - int(trail["end_at"]) >= B.TRAIL_MS:
		trail = {}


func is_whiffing(now: int) -> bool:
	return now - whiff_at < B.WHIFF_MS


func is_no_charge(now: int) -> bool:
	return now - no_charge_at < B.NO_CHARGE_MS


# 0〜1 の進み。始まっていないか終わっていれば -1。
static func phase(now: int, at: int, ms: int) -> float:
	var t := float(now - at) / ms
	return t if t >= 0.0 and t < 1.0 else -1.0


# 場の全体が白く光る強さ(3 体以上の割れる瞬間)。点滅を弱める時は FLASH_ALPHA_REDUCED まで。
func flash_alpha(now: int) -> float:
	var t := phase(now, flash_at, B.FLASH_MS)
	if t < 0.0:
		return 0.0
	return (B.FLASH_ALPHA_REDUCED if reduce_flash else B.FLASH_ALPHA) * (1.0 - t)


# 字が跳ねる大きさ(1.0 が普段)。
static func bump(now: int, at: int) -> float:
	var t := phase(now, at, B.BUMP_MS)
	return 1.0 if t < 0.0 else 1.0 + B.BUMP_SCALE * (1.0 - t) * (1.0 - t)


# 場の上に描く物(通り道の線と残像・斬った敵と線・破片・輪)。px, py は今の自分の位置。
func draw_world(ci: CanvasItem, now: int, px: float, py: float) -> void:
	if not trail.is_empty():
		var a := Vector2(trail["ax"], trail["ay"])
		var running := int(trail["end_at"]) < 0
		var b := Vector2(px, py) if running else Vector2(trail["bx"], trail["by"])
		var k := 1.0 if running else clampf(1.0 - float(now - int(trail["end_at"])) / B.TRAIL_MS, 0.0, 1.0)
		ci.draw_line(a, b, Color(Kit.C_LINE, 0.16 * k), 14.0, true)
		ci.draw_line(a, b, Color(Kit.C_LINE, 0.75 * k), 3.0, true)
		for f: float in [0.35, 0.6, 0.82]:  # 残像
			ci.draw_circle(a.lerp(b, f), B.PLAYER_RADIUS * (0.6 + 0.4 * f), Color(Kit.C_PLAYER, 0.22 * f * k))
	for c: Dictionary in corpses:
		var p := Vector2(c["x"], c["y"])
		var r: float = c["r"]
		var color := Kit.kind_color(c["kind"])
		if freezing:
			color = color.lerp(Color.WHITE, 0.6)  # 止めの間は白く光る
		Kit.draw_shape(ci, c["kind"], p, r, color, Vector2(px, py))  # 止まった絵のまま残す
		var u := Vector2(c["ux"], c["uy"]).rotated(-0.8)  # 突進の向きから斜めに(通り道の線と重ねない)
		var g := clampf(float(now - int(c["at"])) / B.CUT_GROW_MS, 0.0, 1.0)
		var half := (r + 10.0) * g
		ci.draw_line(p - u * half, p + u * half, Kit.C_LINE, 6.0 if freezing else 4.0, true)
	for s: Dictionary in shards:
		var t := float(now - int(s["at"])) / B.SHARD_MS
		var e := t * (1.0 - 0.45 * t)  # 少しずつ遅くなる
		var sp := Vector2(s["x"], s["y"]) + Vector2(s["vx"], s["vy"]) * e * B.SHARD_MS / 1000.0
		var sz: float = s["size"] * (1.0 - 0.7 * t)
		var rot: float = s["rot"] + s["spin"] * t
		var pts := PackedVector2Array([Vector2(sz, 0).rotated(rot) + sp, Vector2(-sz * 0.5, sz * 0.45).rotated(rot) + sp, Vector2(-sz * 0.35, -sz * 0.5).rotated(rot) + sp])
		ci.draw_colored_polygon(pts, Color(s["color"], 1.0 - t * t))
	for r: Dictionary in rings:
		var t := float(now - int(r["at"])) / B.RING_MS
		ci.draw_arc(Vector2(r["x"], r["y"]), float(r["r"]) + float(r["grow"]) * t, 0.0, TAU, 40, Color(Kit.C_LINE, 0.9 * (1.0 - t)), 4.0 * (1.0 - t) + 1.0, true)


# 最初に斬るまで出す手がかりの矢印(自分から、一番近い敵の向きへ流れる 3 つの山形)。
func draw_guide(ci: CanvasItem, now: int, me: Vector2, to: Vector2) -> void:
	var d := to - me
	if d.length() < 1.0:
		return
	var u := d.normalized()
	var side := Vector2(-u.y, u.x)
	var cyc := float(now % B.GUIDE_MS) / B.GUIDE_MS
	for i in 3:
		var f := fmod(cyc + i / 3.0, 1.0)
		var c := me + u * (34.0 + 70.0 * f)
		var a := 0.75 * sin(f * PI)
		ci.draw_polyline(PackedVector2Array([c - u * 10.0 + side * 12.0, c + u * 4.0, c - u * 10.0 - side * 12.0]), Color(Kit.C_LINE, a), 4.0, true)


# 画面の一番上に描く物(場の光・点の表示・縁の赤・終わりの理由)。
func draw_top(ci: CanvasItem, now: int) -> void:
	var fa := flash_alpha(now)
	if fa > 0.0:
		ci.draw_rect(Rect2(B.FIELD_X0, B.FIELD_Y0, B.FIELD_X1 - B.FIELD_X0, B.FIELD_Y1 - B.FIELD_Y0), Color(1, 1, 1, fa))
	var f := Kit.num_font()  # 数は HUD と同じ明朝(「体」は Noto へ落ちる)
	var fo := Kit.font(800)
	for p: Dictionary in popups:
		var t := float(now - int(p["at"])) / B.POPUP_MS
		var pop := 1.0 + B.POP_IN_SCALE * maxf(0.0, 1.0 - float(now - int(p["at"])) / B.POP_IN_MS)
		var size := int(32 * (B.POPUP_BIG if p["big"] else 1.0) * pop)
		var y: float = p["y"] - B.POPUP_RISE * t
		var w := 640.0
		var x := clampf(p["x"] - w / 2.0, 0.0, B.SCREEN_W - w)
		var fade := 1.0 if t < 0.6 else 1.0 - (t - 0.6) / 0.4
		var col: Color = Kit.C_BULLET if p["big"] else (Kit.C_TEXT if int(p["n"]) >= 2 else Color(Kit.C_TEXT, 0.85))
		ci.draw_string_outline(f, Vector2(x, y), p["text"], HORIZONTAL_ALIGNMENT_CENTER, w, size, 8, Color(Kit.C_BG, fade))
		ci.draw_string(f, Vector2(x, y), p["text"], HORIZONTAL_ALIGNMENT_CENTER, w, size, Color(col, col.a * fade))
	var et := float(now - edge_at) / B.EDGE_MS
	if et >= 0.0 and et < 1.0:
		var a := (B.REDUCED_FLASH_ALPHA if reduce_flash else B.EDGE_ALPHA) * (1.0 - et)
		for k in 4:
			ci.draw_rect(Rect2(k * 6, k * 6, B.SCREEN_W - k * 12, B.SCREEN_H - k * 12), Color(Kit.C_DANGER, a * (1.0 - k / 4.0)), false, 6.0)
	if int(over["at"]) >= 0:
		var ot := clampf(float(now - int(over["at"])) / B.OVER_MS, 0.0, 1.0)
		ci.draw_rect(Rect2(B.FIELD_X0, B.FIELD_Y0, B.FIELD_X1 - B.FIELD_X0, B.FIELD_Y1 - B.FIELD_Y0), Color(Kit.C_BG, 0.55 * ot))
		var fs := int(64 * (1.15 - 0.15 * ot))
		ci.draw_string_outline(fo, Vector2(0, 660), over["text"], HORIZONTAL_ALIGNMENT_CENTER, B.SCREEN_W, fs, 10, Color(Kit.C_BG, ot))
		ci.draw_string(fo, Vector2(0, 660), over["text"], HORIZONTAL_ALIGNMENT_CENTER, B.SCREEN_W, fs, Color(Kit.C_TEXT, ot))
