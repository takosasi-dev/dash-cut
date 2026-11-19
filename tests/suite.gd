# テストの土台。ok / eq で確かめ、失敗は errors にたまる。sim を作って進める道具も持つ。
# 各テストは最後に true を返す(途中で止まったことを見分けるため)。
extends RefCounted

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Sim := preload("res://core/sim.gd")
const F := preload("res://core/formations.gd")
const Geom := preload("res://core/geom.gd")

var errors: Array = []


func ok(cond: bool, msg: String) -> void:
	if not cond:
		errors.append(msg)


func eq(got: Variant, want: Variant, msg: String) -> void:
	if typeof(got) != typeof(want) or got != want:
		errors.append("%s: %s のはずが %s" % [msg, want, got])


static func run(sim: Sim, ticks: int) -> Array:
	var ev: Array = []
	for k in ticks:
		sim.step()
		ev.append_array(sim.events())
	return ev


# 印が明けるまで進める(T1 は開始時に出て、60 tick は斬れない)。
static func wait_marks(sim: Sim) -> Array:
	return run(sim, B.SPAWN_MARK_TICKS)


# 突進を指示し、突進と止めが終わるまで進める。
static func dash(sim: Sim, ix: int, iy: int) -> Array:
	sim.queue_dash(ix, iy)
	var ev := run(sim, 1)
	var guard := 0
	while (sim.dash_left > 0 or sim.freeze_left > 0) and guard < 1000:
		sim.step()
		ev.append_array(sim.events())
		guard += 1
	return ev


static func types(ev: Array) -> Array:
	return ev.map(func(e: Dictionary) -> String: return e["type"])


static func of_type(ev: Array, t: String) -> Array:
	return ev.filter(func(e: Dictionary) -> bool: return e["type"] == t)


# 敵のいない場(テスト用)。2 番目の並びの特別な決まりを過ぎた形にし、時間で出る並びも遠ざける。
static func bare(seed_value: int = 1) -> Sim:
	var sim := Sim.new(seed_value)
	sim.enemies.clear()
	sim.spawned = 2
	sim._since_spawn = -1000000
	return sim


# 敵を 1 体置く(テスト用。印なし)。
static func put(sim: Sim, kind: int, x: float, y: float, mark: int = 0) -> Dictionary:
	var e := {"id": 9000 + sim.enemies.size(), "kind": kind, "x": x, "y": y, "r": F.radius(kind), "mark": mark, "t": 0}
	sim.enemies.append(e)
	return e


# 試しの bot: 回数があり突進していなければ、印の明けた一番近い敵へ向けて突進する。every tick ごとに 1 回考える。
static func bot_play(sim: Sim, every: int = 30, limit: int = 20000) -> void:
	var t := 0
	while not sim.is_over() and t < limit:
		if t % every == 0 and sim.dash_left == 0 and sim.freeze_left == 0 and sim.charges > 0:
			var best: Variant = null
			var bd := 1e18
			for e: Dictionary in sim.enemies:
				if int(e["mark"]) > 0:
					continue
				var d: float = (e["x"] - sim.px) ** 2 + (e["y"] - sim.py) ** 2
				if d < bd:
					bd = d
					best = e
			if best != null:
				sim.queue_dash(roundi(best["x"] - sim.px), roundi(best["y"] - sim.py))
		sim.step()
		t += 1
