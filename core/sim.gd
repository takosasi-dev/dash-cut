# 1 回のプレイの全状態と step()(仕様書 §9.3)。突進・斬る判定・敵と弾・当たり・点・時計・並びの出現を持つ。
# 入力は queue_dash(ix, iy) の整数 2 つだけ(INV-6)。ui と audio は events() と snapshot() を読むだけ(INV-1)。
# 1 tick = 1/120 秒。Node・Time・乱数関数・sin・cos を使わない(INV-2・INV-5)。
extends RefCounted

const B := preload("res://core/balance.gd")
const Geom := preload("res://core/geom.gd")
const Score := preload("res://core/score.gd")
const F := preload("res://core/formations.gd")

const MODE_DAILY := 0
const MODE_PRACTICE := 1

var mode := MODE_DAILY
var seed_value := 1
var tick := 0  # step() を呼んで進めた数(止めの間も数える)

# 自分
var px := B.PLAYER_START_X
var py := B.PLAYER_START_Y
var face_x := 0.0  # 最後に突進した向き(描く印)
var face_y := -1.0
var charges := B.CHARGE_MAX
var regen := 0
var hp := B.HP_MAX
var hurt_left := 0

# 突進
var pending: Variant = null  # [ix, iy] か null
var dash_left := 0
var dash_ux := 0.0
var dash_uy := 0.0
var dash_n := 0
var freeze_left := 0

# 時計と点
var time_left := B.ROUND_TICKS
var clock_running := false
var clock_ticks := 0  # 時計が動き出してからの tick
var points := 0
var chain := 0
var chain_idle := 0
var cuts := 0
var max_n := 0
var max_chain := 0

# 敵 { id, kind, x, y, r, mark, t } と弾 { x, y, vx, vy }
var enemies: Array = []
var bullets: Array = []
var _next_id := 1

# 並び
var order: Array = []  # [{ id, flip }] 60 個
var spawned := 0  # 出した並びの数
var _since_spawn := 0
var _low_armed := false  # 場の敵が SPAWN_WHEN_LEFT より多い時を見た(「2 体以下になった tick」を 1 回に数える)
var _due := false  # 出すと決めたが、敵が多い・自機が近いので待っている
var _teach_wait := 0  # 教える並びを、自機が離れるまで待った tick
var teach_waits: Array = []  # 出した教える並びごとの [id, 待った tick](テストと測りが読む)
var _t1_ids: Array = []

var over := false
var reason := ""  # "time" / "hp"
var _events: Array = []


func _init(p_seed: int, p_mode: int = MODE_DAILY) -> void:
	seed_value = p_seed
	mode = p_mode
	order = F.build_order(p_seed)
	_spawn_next()  # 1 番目(T1)は開始時に出す
	_t1_ids = enemies.map(func(e: Dictionary) -> int: return e["id"])


# 次の step で使う突進の指示。(0, 0) は無視。突進中・止めの間は 1 つだけ覚える(後の物で上書き。E-3)。
func queue_dash(ix: int, iy: int) -> void:
	if over or (ix == 0 and iy == 0):
		return
	pending = [ix, iy]


func events() -> Array:
	return _events


func is_over() -> bool:
	return over


func is_dashing() -> bool:
	return dash_left > 0


func step() -> void:
	_events = []
	# 1
	if over:
		return
	tick += 1
	# 2 止め(時計も敵も進めない)
	if freeze_left > 0:
		freeze_left -= 1
		return
	# 3 突進を始める
	if pending != null and dash_left == 0:
		var p: Array = pending
		pending = null
		if charges >= 1:
			charges -= 1
			var u := Geom.unit(p[0], p[1])
			dash_ux = u[0]
			dash_uy = u[1]
			face_x = dash_ux
			face_y = dash_uy
			dash_left = B.DASH_TICKS
			dash_n = 0
			_events.append({"type": "dash_start", "x": px, "y": py, "ux": dash_ux, "uy": dash_uy})
		else:
			_events.append({"type": "no_charge"})
	# 4 突進
	var dashed := dash_left > 0
	if dashed:
		_dash_tick()
	# 5 敵と弾
	_move_enemies()
	_move_bullets()
	# 6 当たり(突進中・突進が終わった tick・当たらない時間は飛ばす)
	if not dashed and hurt_left == 0:
		_check_hits()
	# 7
	_tick_timers()
	_tick_marks()
	_tick_spawn()
	# 8
	if clock_running:
		time_left -= 1
		clock_ticks += 1
	if time_left <= 0:
		_finish("time")
	elif hp <= 0:
		_finish("hp")


func _dash_tick() -> void:
	var ax := px
	var ay := py
	var p := Geom.dash_step(px, py, dash_ux, dash_uy)
	px = p[0]
	py = p[1]
	var keep: Array = []
	for e: Dictionary in enemies:
		if Geom.can_cut(ax, ay, px, py, e):
			_events.append({"type": "cut_mark", "id": e["id"], "kind": e["kind"], "x": e["x"], "y": e["y"], "r": e["r"], "k": dash_n})
			dash_n += 1
			cuts += 1
			chain_idle = 0
		else:
			keep.append(e)
	enemies = keep
	dash_left -= 1
	if dash_left > 0:
		return
	var n := dash_n
	if n >= 1:
		var m10 := Score.mult10(chain)
		var got := Score.points(n, chain)
		points += got
		charges = mini(charges + 1, B.CHARGE_MAX)
		chain += 1
		max_chain = maxi(max_chain, chain)
		max_n = maxi(max_n, n)
		freeze_left = B.FREEZE_BASE + B.FREEZE_PER * mini(n, B.FREEZE_N_CAP)
		clock_running = true
		_events.append({"type": "dash_end", "n": n, "points": got, "mult10": m10, "chain": chain, "x": px, "y": py})
	else:
		chain = 0
		_events.append({"type": "dash_end", "n": 0, "points": 0, "mult10": Score.mult10(0), "chain": 0, "x": px, "y": py})


func _move_enemies() -> void:
	var cs := B.CHASER_SPEED / B.TICK_HZ
	for e: Dictionary in enemies:
		if int(e["mark"]) > 0:
			continue
		match int(e["kind"]):
			F.CHASER:
				var dx: float = px - e["x"]
				var dy: float = py - e["y"]
				var l := sqrt(dx * dx + dy * dy)
				if l > cs:
					e["x"] += dx / l * cs
					e["y"] += dy / l * cs
				else:
					e["x"] = px
					e["y"] = py
			F.SHOOTER:
				e["t"] += 1
				var ph: int = int(e["t"]) % B.SHOOTER_PERIOD_TICKS
				if ph == B.SHOOTER_PERIOD_TICKS - B.SHOOTER_WARN_TICKS:
					_events.append({"type": "shoot_warn", "id": e["id"], "x": e["x"], "y": e["y"]})
				elif ph == 0 and bullets.size() < B.BULLET_CAP:
					_fire(e)


func _fire(e: Dictionary) -> void:
	var dx: float = px - e["x"]
	var dy: float = py - e["y"]
	var l := sqrt(dx * dx + dy * dy)
	if l == 0.0:
		dx = 0.0
		dy = 1.0
		l = 1.0
	var bs := B.BULLET_SPEED / B.TICK_HZ
	bullets.append({"x": e["x"], "y": e["y"], "vx": dx / l * bs, "vy": dy / l * bs})


func _move_bullets() -> void:
	var keep: Array = []
	for b: Dictionary in bullets:
		b["x"] += b["vx"]
		b["y"] += b["vy"]
		if b["x"] >= B.FIELD_X0 and b["x"] <= B.FIELD_X1 and b["y"] >= B.FIELD_Y0 and b["y"] <= B.FIELD_Y1:
			keep.append(b)
	bullets = keep


func _touching(x: float, y: float, r: float) -> bool:
	var dx := x - px
	var dy := y - py
	var rr := r + B.PLAYER_RADIUS
	return dx * dx + dy * dy <= rr * rr


func _check_hits() -> void:
	for e: Dictionary in enemies:
		if int(e["kind"]) == F.CHASER and int(e["mark"]) == 0 and _touching(e["x"], e["y"], e["r"]):
			_hurt("chaser")
			return
	for k in bullets.size():
		var b: Dictionary = bullets[k]
		if _touching(b["x"], b["y"], B.BULLET_RADIUS):
			bullets.remove_at(k)
			_hurt("bullet")
			return


func _hurt(by: String) -> void:
	hp -= 1
	hurt_left = B.HURT_INVINCIBLE_TICKS
	chain = 0
	chain_idle = 0
	_events.append({"type": "hurt", "by": by, "hp": hp})


func _tick_timers() -> void:
	if charges < B.CHARGE_MAX:
		regen += 1
		if regen >= B.CHARGE_REGEN_TICKS:
			charges += 1
			regen = 0
	else:
		regen = 0
	if hurt_left > 0:
		hurt_left -= 1
	if chain > 0 and dash_left == 0:
		chain_idle += 1
		if chain_idle >= B.CHAIN_KEEP_TICKS:
			chain = 0
			chain_idle = 0


func _tick_marks() -> void:
	for e: Dictionary in enemies:
		if int(e["mark"]) > 0:
			e["mark"] -= 1


func _tick_spawn() -> void:
	_since_spawn += 1
	var n := enemies.size()
	if n > B.SPAWN_WHEN_LEFT:
		_low_armed = true
	if spawned == 1:
		# 2 番目: T1 の 3 体を全部斬った tick か、時計が動き出してから 720 tick の早い方
		var t1_left := enemies.any(func(e: Dictionary) -> bool: return _t1_ids.has(e["id"]))
		if not t1_left or clock_ticks >= B.SPAWN_FORCE_TICKS:
			_due = true
	elif (n <= B.SPAWN_WHEN_LEFT and _low_armed) or _since_spawn >= B.SPAWN_FORCE_TICKS:
		_due = true
	if _due and n < B.ENEMY_CAP:
		# 教える並びは、全員が自機から 120 px 以上離れている tick まで待って出す(2026-11-20 の依頼者の判断)。
		# 待ちが上限を超えたら、ほかの並びと同じ INV-10 の扱い(点対称へ・出さない)で出す
		if _teach_blocked() and _teach_wait < B.TEACH_WAIT_MAX_TICKS:
			_teach_wait += 1
			return
		_spawn_next()


func _order_at(k: int) -> Dictionary:
	if k >= B.ORDER_LEN:
		k = B.ORDER_LOOP_FROM + (k - B.ORDER_LEN) % (B.ORDER_LEN - B.ORDER_LOOP_FROM)
	return order[k]


# 次に出すのが教える並びで、自機から 120 px 未満の member があれば真。
func _teach_blocked() -> bool:
	var f := F.get_formation(_order_at(spawned)["id"])
	return f["teach"] and f["members"].any(func(m: Dictionary) -> bool: return _too_close(m["x"], m["y"]))


# 出す順の次の並びを出す(印つき)。自分から近すぎる member は点対称の位置へ、それも近ければ出さない(INV-10)。
func _spawn_next() -> void:
	var o := _order_at(spawned)
	var f := F.get_formation(o["id"])
	if f["teach"]:
		teach_waits.append([o["id"], _teach_wait])
	_teach_wait = 0
	for m: Dictionary in f["members"]:
		var x: float = B.FIELD_X1 - m["x"] if o["flip"] else m["x"]
		var y: float = m["y"]
		if _too_close(x, y):
			x = B.FIELD_X1 - x
			y = B.FIELD_Y0 + B.FIELD_Y1 - y
			if _too_close(x, y):
				continue
		var kind: int = m["kind"]
		enemies.append({"id": _next_id, "kind": kind, "x": x, "y": y, "r": F.radius(kind), "mark": B.SPAWN_MARK_TICKS, "t": 0})
		_events.append({"type": "spawn_mark", "id": _next_id, "kind": kind, "x": x, "y": y})
		_next_id += 1
	spawned += 1
	_since_spawn = 0
	_low_armed = false
	_due = false


func _too_close(x: float, y: float) -> bool:
	var dx := x - px
	var dy := y - py
	return dx * dx + dy * dy < B.SPAWN_MIN_DIST * B.SPAWN_MIN_DIST


func _finish(why: String) -> void:
	over = true
	reason = why
	pending = null
	_events.append({"type": "over", "reason": why})


# 描画用(読むだけ。敵と弾の配列は中身をそのまま渡す)。
func snapshot() -> Dictionary:
	return {"x": px, "y": py, "face_x": face_x, "face_y": face_y, "charges": charges, "regen": regen, "hp": hp,
		"hurt_left": hurt_left, "time_left": time_left, "clock_running": clock_running, "points": points, "chain": chain,
		"freeze_left": freeze_left, "dashing": dash_left > 0, "enemies": enemies, "bullets": bullets, "tick": tick, "cuts": cuts}


func result() -> Dictionary:
	return {"points": points, "cuts": cuts, "max_n": max_n, "max_chain": max_chain, "reason": reason, "ticks": tick}
