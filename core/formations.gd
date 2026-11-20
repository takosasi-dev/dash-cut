# 敵の並び 24 個(手で作ったデータ)と、出す順の作り方(仕様書 §9.6)。
# 教える並び T1〜T4 の中身と出る位置(1・2・6・12 番目)は変えない(INV-9)。順は種だけで決まる(INV-3)。
# T1・T2 の座標は 2026-11-20 に依頼者の判断で後ろ(上)へずらした。出す時の自機から 120 px 以上(INV-10)で、点対称へ移さずに出る。
extends RefCounted

const B := preload("res://core/balance.gd")
const Rng := preload("res://core/rng.gd")

const STILL := 0
const CHASER := 1
const SHOOTER := 2

# [id, tier, teach, [[kind, x, y], ...]]
const DATA := [
	["T1", 1, true, [[STILL, 360, 770], [STILL, 360, 680], [STILL, 360, 590]]],
	["T2", 1, true, [[STILL, 360, 450], [STILL, 360, 370], [STILL, 360, 290], [STILL, 460, 260], [STILL, 540, 260], [STILL, 620, 260]]],
	["A1", 1, false, [[STILL, 200, 400], [STILL, 300, 500], [STILL, 400, 600], [STILL, 500, 700]]],
	["A2", 1, false, [[STILL, 160, 500], [STILL, 260, 500], [STILL, 360, 500], [STILL, 460, 500], [STILL, 560, 500]]],
	["A3", 1, false, [[STILL, 200, 350], [STILL, 280, 450], [STILL, 360, 550], [STILL, 440, 450], [STILL, 520, 350]]],
	["A4", 1, false, [[STILL, 200, 400], [STILL, 200, 500], [STILL, 200, 600], [STILL, 520, 700], [STILL, 520, 800], [STILL, 520, 900]]],
	["A5", 1, false, [[STILL, 260, 600], [STILL, 360, 600], [STILL, 460, 600], [STILL, 360, 500], [STILL, 360, 700]]],
	["A6", 1, false, [[STILL, 600, 300], [STILL, 520, 380], [STILL, 440, 460], [STILL, 360, 540]]],
	["T3", 2, true, [[CHASER, 360, 280], [STILL, 160, 700], [STILL, 260, 700], [STILL, 460, 700], [STILL, 560, 700]]],
	["B1", 2, false, [[CHASER, 100, 300], [STILL, 250, 700], [STILL, 350, 700], [STILL, 450, 700]]],
	["B2", 2, false, [[CHASER, 150, 300], [CHASER, 570, 300], [STILL, 300, 800], [STILL, 360, 860], [STILL, 420, 920]]],
	["B3", 2, false, [[CHASER, 360, 250], [STILL, 200, 500], [STILL, 300, 500], [STILL, 400, 500], [STILL, 500, 500]]],
	["B4", 2, false, [[CHASER, 100, 1000], [CHASER, 620, 1000], [STILL, 360, 300], [STILL, 360, 400], [STILL, 360, 500]]],
	["B5", 2, false, [[CHASER, 600, 250], [STILL, 150, 450], [STILL, 250, 550], [STILL, 350, 650], [STILL, 450, 750]]],
	["B6", 2, false, [[CHASER, 120, 250], [CHASER, 360, 250], [CHASER, 600, 250], [STILL, 260, 600], [STILL, 360, 600], [STILL, 460, 600]]],
	["B7", 2, false, [[CHASER, 360, 1100], [STILL, 160, 300], [STILL, 260, 350], [STILL, 360, 400], [STILL, 460, 450]]],
	["T4", 3, true, [[SHOOTER, 360, 300], [STILL, 200, 900], [STILL, 300, 900], [STILL, 420, 900], [STILL, 520, 900]]],
	["C1", 3, false, [[SHOOTER, 120, 300], [STILL, 300, 600], [STILL, 400, 600], [STILL, 500, 600]]],
	["C2", 3, false, [[SHOOTER, 120, 300], [SHOOTER, 600, 300], [CHASER, 360, 250], [STILL, 260, 700], [STILL, 360, 700], [STILL, 460, 700]]],
	["C3", 3, false, [[SHOOTER, 600, 1050], [CHASER, 100, 300], [STILL, 200, 450], [STILL, 300, 550], [STILL, 400, 650]]],
	["C4", 3, false, [[SHOOTER, 360, 260], [CHASER, 120, 900], [CHASER, 600, 900], [STILL, 360, 500], [STILL, 360, 600], [STILL, 360, 700]]],
	["C5", 3, false, [[SHOOTER, 100, 700], [STILL, 400, 350], [STILL, 450, 450], [STILL, 500, 550], [STILL, 550, 650]]],
	["C6", 3, false, [[SHOOTER, 150, 1050], [SHOOTER, 570, 1050], [STILL, 200, 400], [STILL, 300, 400], [STILL, 400, 400], [STILL, 500, 400]]],
	["C7", 3, false, [[SHOOTER, 360, 1080], [CHASER, 100, 300], [CHASER, 620, 300], [STILL, 250, 700], [STILL, 360, 620], [STILL, 470, 540]]],
]

# 何番目(0 から)に出す教える並び。それ以外の番目は TIER_AT の tier から選ぶ
const TEACH_AT := {0: "T1", 1: "T2", 5: "T3", 11: "T4"}


static func radius(kind: int) -> float:
	return [B.STILL_RADIUS, B.CHASER_RADIUS, B.SHOOTER_RADIUS][kind]


# 並びを 1 個、{ id, tier, teach, members: [{ kind, x, y }] } の形で返す。
static func get_formation(id: String) -> Dictionary:
	for f: Array in DATA:
		if f[0] == id:
			return _dict(f)
	return {}


static func all() -> Array:
	return DATA.map(func(f: Array) -> Dictionary: return _dict(f))


static func _dict(f: Array) -> Dictionary:
	var members: Array = f[3].map(func(m: Array) -> Dictionary: return {"kind": m[0], "x": float(m[1]), "y": float(m[2])})
	return {"id": f[0], "tier": f[1], "teach": f[2], "members": members}


# その tier の、教える並びを除いた id の並び。
static func pool(tier: int) -> Array:
	return DATA.filter(func(f: Array) -> bool: return f[1] == tier and not f[2]).map(func(f: Array) -> String: return f[0])


# 出す順 60 個([{ id, flip }])。§9.6 の作り方をそのまま。
static func build_order(seed_value: int) -> Array:
	var rng := Rng.new(seed_value)
	var out: Array = []
	var prev := ""
	for k in B.ORDER_LEN:
		if TEACH_AT.has(k):
			prev = TEACH_AT[k]
			out.append({"id": prev, "flip": false})
			continue
		var tier := 1
		if k >= 6:
			tier = 2
		if k >= 12:
			tier = 2 if rng.next_int(2) == 0 else 3
		var ids := pool(tier)
		var id: String = ids[rng.next_int(ids.size())]
		for t in 4:
			if id != prev:
				break
			id = ids[rng.next_int(ids.size())]
		prev = id
		out.append({"id": id, "flip": rng.next_int(2) == 1})
	return out
