# 負荷の測り(NFR-1・撤退基準 R-4)。敵 40・弾 30・破片 240 の場面を 3600 フレーム(60 秒ぶん)続け、1 フレームの時間を数える。
# 窓なし(描画はダミー)で回すので、本物の GPU の描く時間は入らない。書き出した物には入らない(tools/ は書き出さない)。
#     python tools/gd.py perf(--fixed-fps 60 で 1 フレームに 2 tick 進める)
extends SceneTree

const B := preload("res://core/balance.gd")
const F := preload("res://core/formations.gd")
const Kit := preload("res://ui/kit.gd")

var main: Node
var frames := 0
var last := 0
var times: Array = []
var draws := 0


func _initialize() -> void:
	main = load("res://ui/main.tscn").instantiate()
	root.add_child(main)
	_go.call_deferred()


func _go() -> void:
	main._on_title("practice")
	main.play.field.draw.connect(func() -> void: draws += 1)


func _load() -> void:
	var sim: RefCounted = main.play.sim
	sim._since_spawn = -1000000
	sim.hp = 3
	sim.hurt_left = 10
	while sim.enemies.size() < 40:
		var k: int = sim.enemies.size()
		var kind: int = [F.STILL, F.CHASER, F.SHOOTER][k % 3]
		sim.enemies.append({"id": 5000 + frames * 50 + k, "kind": kind, "x": 60.0 + (k % 10) * 66.0, "y": 260.0 + (k / 10) * 90.0, "r": F.radius(kind), "mark": 0, "t": k * 7})
	while sim.bullets.size() < 30:
		var j: int = sim.bullets.size()
		sim.bullets.append({"x": 30.0 + j * 22.0, "y": 700.0, "vx": 0.5, "vy": 1.5})
	var fx: RefCounted = main.play.fx
	var now := Time.get_ticks_msec()
	while fx.shards.size() < 240:
		var i: int = fx.shards.size()
		fx.shards.append({"x": 360.0, "y": 640.0, "vx": (i % 20 - 10) * 20.0, "vy": (i / 20 - 6) * 30.0, "at": now, "color": Kit.C_STILL})
	if frames % 30 == 0:
		main.play.sim.queue_dash(1, -1 if frames % 60 == 0 else 1)  # 狙いの線と突進の分も入れる


func _process(_delta: float) -> bool:
	if main == null or main.play == null:
		return false
	var now := Time.get_ticks_usec()
	if last > 0:
		times.append((now - last) / 1000.0)
	_load()
	main.play._drag = true  # 狙いの予測(毎フレーム)も入れる
	main.play._drag_from = Vector2(360, 900)
	main.play._drag_to = Vector2(400, 860)
	last = Time.get_ticks_usec()
	frames += 1
	if frames >= 3600:
		_report()
		return true
	return false


func _report() -> void:
	times.sort()
	var n := times.size()
	print("PERF frames=%d draws=%d p50=%.2fms p95=%.2fms max=%.2fms enemies=%d bullets=%d shards=%d" % [n, draws, times[n / 2], times[int(n * 0.95)], times[-1],
		main.play.sim.enemies.size(), main.play.sim.bullets.size(), main.play.fx.shards.size()])
