# core の決まりのテスト(仕様書 §9・AC-2〜AC-15・AC-23・E-n)。
extends "res://tests/suite.gd"

const Rng := preload("res://core/rng.gd")
const Day := preload("res://core/day_index.gd")
const Score := preload("res://core/score.gd")


func test_rng_known_values() -> bool:
	var r := Rng.new(1)
	eq(r.next(), 270369, "1 回目")
	eq(r.next(), 67634689, "2 回目")
	eq(r.next(), 2647435461, "3 回目")
	eq(Rng.new(0).state, 1, "0 は 1 にする")
	var r2 := Rng.new(12345)
	var all_in := true
	for k in 1000:
		var v := r2.next_int(7)
		all_in = all_in and v >= 0 and v < 7
	ok(all_in, "next_int は 0 以上 n 未満")
	return true


func test_segment_hits_circle() -> bool:
	ok(Geom.segment_hits_circle(0, 0, 100, 0, 50, 10, 10), "線分の真横 10 px は半径 10 で当たる")
	ok(not Geom.segment_hits_circle(0, 0, 100, 0, 50, 10.5, 10), "10.5 px は外れ")
	ok(Geom.segment_hits_circle(0, 0, 100, 0, 108, 0, 8), "終点の先 8 px は当たる")
	ok(not Geom.segment_hits_circle(0, 0, 100, 0, 109, 0, 8), "終点の先 9 px は外れ")
	ok(Geom.segment_hits_circle(5, 5, 5, 5, 8, 9, 5), "長さ 0 の線分は点との距離")
	return true


func test_unit_and_dash_step() -> bool:
	var u := Geom.unit(3, 4)
	ok(absf(u[0] - 0.6) < 1e-9 and absf(u[1] - 0.8) < 1e-9, "(3, 4) → (0.6, 0.8)")
	eq(Geom.unit(0, 0), [0.0, 0.0], "(0, 0)")
	var p := Geom.dash_step(10.0, 300.0, -1.0, 0.0)
	eq(p[0], B.PLAYER_RADIUS, "左の端で切り詰め")
	return true


func test_preview_t1() -> bool:
	var sim := Sim.new(1)
	var pv := Geom.preview(sim.px, sim.py, 0, -100, sim.enemies)
	eq(pv["hit_ids"].size(), 0, "印の間の敵は予測にも入らない")
	wait_marks(sim)
	pv = Geom.preview(sim.px, sim.py, 0, -100, sim.enemies)
	eq(pv["hit_ids"].size(), 3, "T1 の 3 体")
	ok(absf(pv["end_x"] - 360.0) < 1e-6 and absf(pv["end_y"] - 580.0) < 1e-6, "終点は 320 px 上")
	return true


func test_inv4_preview_matches_real_for_still() -> bool:
	for dir: Array in [[1, -1], [-3, -2], [100, 7], [0, 100], [-50, 0]]:
		var sim := Sim.new(7)
		sim.enemies.clear()
		for k in 8:
			put(sim, F.STILL, 180.0 + 50.0 * k, 900.0 - 40.0 * k)
		put(sim, F.STILL, 600.0, 900.0)
		var pv := Geom.preview(sim.px, sim.py, dir[0], dir[1], sim.enemies)
		var ev := dash(sim, dir[0], dir[1])
		var cut: Array = of_type(ev, "cut_mark").map(func(e: Dictionary) -> int: return e["id"])
		cut.sort()
		var want: Array = pv["hit_ids"].duplicate()
		want.sort()
		eq(cut, want, "止まる敵なら予測と本番が同じ %s" % [dir])
		ok(absf(sim.px - pv["end_x"]) < 1e-9 and absf(sim.py - pv["end_y"]) < 1e-9, "終点も同じ %s" % [dir])
	return true


func test_ac3_t1_upward() -> bool:
	var sim := Sim.new(1)
	# T1 の (360, 800) は開始位置 (360, 900) から 100 px なので、INV-10 で点対称の (360, 560) に出る。上向きの突進(終点 580)で 3 体とも斬れる
	eq(sim.enemies.map(func(e: Dictionary) -> Array: return [e["x"], e["y"]]), [[360.0, 560.0], [360.0, 700.0], [360.0, 600.0]], "T1 の出る位置")
	wait_marks(sim)
	var ev := dash(sim, 0, -100)
	eq(of_type(ev, "cut_mark").size(), 3, "3 体斬れる")
	eq(sim.charges, 3, "回数が 3 に戻る")
	eq(sim.points, 900, "900 点")
	var end: Array = of_type(ev, "dash_end")
	ok(end.size() == 1 and int(end[0]["n"]) == 3 and int(end[0]["mult10"]) == 10, "dash_end の n と倍率")
	ok(sim.clock_running, "時計が動き出す(FR-12)")
	return true


func test_ac4_whiff() -> bool:
	var sim := Sim.new(1)
	wait_marks(sim)
	dash(sim, 0, -100)
	eq(sim.chain, 1, "つなぎ 1")
	var before := sim.points
	var ev := dash(sim, 100, 0)
	eq(of_type(ev, "dash_end")[0]["n"], 0, "0 体")
	eq(sim.charges, 2, "回数が 1 減る")
	eq(sim.chain, 0, "つなぎ 0")
	eq(sim.points, before, "点は増えない")
	return true


func test_ac5_no_charge() -> bool:
	var sim := Sim.new(1)
	sim.enemies.clear()
	dash(sim, 100, 0)
	dash(sim, -100, 0)
	dash(sim, 100, 0)
	eq(sim.charges, 0, "3 回使って 0")
	var x := sim.px
	var y := sim.py
	sim.queue_dash(0, -100)
	var ev := run(sim, 1)
	ok(types(ev).has("no_charge"), "no_charge が出る")
	ok(sim.px == x and sim.py == y and not sim.is_dashing(), "位置は変わらない")
	ok(sim.pending == null, "指示は覚えない(E-2)")
	return true


func test_ac6_invincible_while_dashing() -> bool:
	var sim := bare()
	var bullet := {"x": sim.px, "y": sim.py, "vx": 0.0, "vy": 0.0}
	sim.bullets.append(bullet)
	sim.queue_dash(0, -100)
	var hp := sim.hp
	# 弾を自分に重ね続ける(追う敵は通り道にいれば斬れて消えるので、止めの間で確かめる)
	sim.step()
	while sim.is_dashing():
		bullet["x"] = sim.px
		bullet["y"] = sim.py
		sim.step()
		eq(sim.hp, hp, "突進中は減らない")
	bullet["x"] = sim.px
	bullet["y"] = sim.py
	sim.step()
	eq(sim.hp, hp - 1, "突進が終わった次の tick から減る")
	return true


func test_ac6_invincible_during_freeze() -> bool:
	var sim := bare()
	put(sim, F.STILL, sim.px, sim.py - 100.0)
	var chaser := put(sim, F.CHASER, 100.0, 1100.0)
	sim.queue_dash(0, -100)
	while sim.is_dashing() or sim.pending != null:
		sim.step()
	ok(sim.freeze_left > 0, "止めの間")
	chaser["x"] = sim.px
	chaser["y"] = sim.py
	var hp := sim.hp
	while sim.freeze_left > 0:
		sim.step()
		eq(sim.hp, hp, "止めの間は減らない")
	sim.step()
	eq(sim.hp, hp - 1, "止めが明けた次の tick から減る")
	return true


func test_ac7_edge_clamp() -> bool:
	for dir: Array in [[-100, 0], [100, 0], [0, -100], [0, 100], [-70, -70], [70, 70]]:
		var sim := Sim.new(3)
		sim.enemies.clear()
		for k in 3:
			dash(sim, dir[0], dir[1])
		ok(sim.px >= B.FIELD_X0 + 14.0 and sim.px <= B.FIELD_X1 - 14.0 and sim.py >= B.FIELD_Y0 + 14.0 and sim.py <= B.FIELD_Y1 - 14.0,
			"場の内側 %s: (%s, %s)" % [dir, sim.px, sim.py])
	return true


func test_e4_dash_into_wall_counts() -> bool:
	var sim := Sim.new(3)
	sim.enemies.clear()
	sim.px = B.PLAYER_RADIUS
	var ev := dash(sim, -100, 0)
	eq(sim.px, B.PLAYER_RADIUS, "動かない")
	eq(sim.charges, 2, "回数は減る")
	eq(of_type(ev, "dash_end")[0]["n"], 0, "0 体の突進")
	return true


func test_ac8_clock_waits_for_first_cut() -> bool:
	var sim := Sim.new(1)
	run(sim, 600)
	eq(sim.time_left, B.ROUND_TICKS, "600 tick 待っても 7200")
	dash(sim, 100, 0)
	run(sim, 300)
	eq(sim.time_left, B.ROUND_TICKS, "外した突進でも進まない")
	return true


func test_ac9_order_same_for_same_seed() -> bool:
	var a := Sim.new(424242)
	var b := Sim.new(424242)
	bot_play(a, 20, 3000)
	run(b, 3000)
	eq(a.order, b.order, "操作が違っても順は同じ")
	eq(Sim.new(424242, Sim.MODE_PRACTICE).order, a.order, "mode でも変わらない")
	ok(Sim.new(424243).order != a.order, "種が違えば違う")
	return true


func test_ac11_teach_positions() -> bool:
	for s in [1, 2, 99, 1283077756, 0xFFFFFFFF]:
		var o := F.build_order(s)
		eq(o.size(), 60, "60 個")
		for pair: Array in [[0, "T1"], [1, "T2"], [5, "T3"], [11, "T4"]]:
			eq(o[pair[0]], {"id": pair[1], "flip": false}, "%d 番目 (種 %d)" % [pair[0] + 1, s])
		for k in 60:
			var f := F.get_formation(o[k]["id"])
			var want_tier: int = [1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 3][k] if k < 12 else -1
			if want_tier > 0:
				eq(f["tier"], want_tier, "%d 番目の段" % (k + 1))
			else:
				ok(f["tier"] in [2, 3] and not f["teach"], "13 番目からは tier2・3 の教えない並び")
	return true


func test_order_avoids_repeat_mostly() -> bool:
	var repeats := 0
	for s in range(1, 51):
		var o := F.build_order(s)
		for k in range(1, 60):
			if o[k]["id"] == o[k - 1]["id"]:
				repeats += 1
	ok(repeats <= 2, "直前と同じ並びは選び直す(50 種で %d 回)" % repeats)
	return true


func test_ac10_formations_valid() -> bool:
	var list := F.all()
	eq(list.size(), 24, "24 個")
	var by_tier := {1: 0, 2: 0, 3: 0}
	for f: Dictionary in list:
		by_tier[f["tier"]] += 1
		var n := [0, 0, 0]
		for m: Dictionary in f["members"]:
			n[m["kind"]] += 1
			ok(m["x"] >= 40 and m["x"] <= 680 and m["y"] >= 240 and m["y"] <= 1120, "%s の member が場の内側(端から 40)" % f["id"])
		var total: int = n[0] + n[1] + n[2]
		ok(total <= 8, "%s は 8 体以下" % f["id"])
		match int(f["tier"]):
			1:
				ok(n[1] == 0 and n[2] == 0 and n[0] >= 3 and n[0] <= 6, "%s: tier1 は止まる 3〜6" % f["id"])
			2:
				ok(n[2] == 0 and n[1] >= 1 and n[1] <= 3 and n[0] >= 2 and n[0] <= 5, "%s: tier2 の組" % f["id"])
			3:
				ok(n[2] >= 1 and n[2] <= 2 and n[1] <= 2 and n[0] >= 2 and n[0] <= 5, "%s: tier3 の組" % f["id"])
		ok(best_line(f["members"]) >= B.LINE_MIN_CUTS, "%s: 320 px の線 1 本で 3 体以上(%d)" % [f["id"], best_line(f["members"])])
	eq(by_tier, {1: 8, 2: 8, 3: 8}, "tier ごとに 8 個")
	eq([F.pool(1).size(), F.pool(2).size(), F.pool(3).size()], [6, 7, 7], "教えない並び")
	return true


# member の 2 体の組を通る線で総当たりし、長さ 320 の線分 1 本で斬れる数の最大を数える(§9.6 の検査)。
static func best_line(members: Array) -> int:
	var best := 0
	for i in members.size():
		for j in range(i + 1, members.size()):
			var a: Dictionary = members[i]
			var b: Dictionary = members[j]
			var dx: float = b["x"] - a["x"]
			var dy: float = b["y"] - a["y"]
			var l := sqrt(dx * dx + dy * dy)
			dx /= l
			dy /= l
			var ts: Array = []
			for m: Dictionary in members:
				var rx: float = m["x"] - a["x"]
				var ry: float = m["y"] - a["y"]
				var perp := absf(rx * dy - ry * dx)
				if perp <= F.radius(m["kind"]) + B.BLADE_HALF_WIDTH:
					ts.append(rx * dx + ry * dy)
			ts.sort()
			var lo := 0
			for hi in ts.size():
				while ts[hi] - ts[lo] > B.DASH_DISTANCE:
					lo += 1
				best = maxi(best, hi - lo + 1)
	return best


func test_ac12_mark_cannot_be_cut_or_hurt() -> bool:
	var sim := Sim.new(1)
	put(sim, F.CHASER, sim.px, sim.py, B.SPAWN_MARK_TICKS)
	var ev := run(sim, 30)
	eq(sim.hp, 3, "印の追う敵に重なっても当たらない")
	ev = dash(sim, 0, -100)
	eq(of_type(ev, "cut_mark").size(), 0, "印の間の T1 は斬れない")
	return true


func test_ac13_end_reasons() -> bool:
	var sim := Sim.new(1)
	sim.hp = 1
	sim.enemies.clear()
	put(sim, F.CHASER, sim.px, sim.py)
	var ev := run(sim, 1)
	ok(sim.is_over() and sim.reason == "hp", "体力 0 で終わる")
	eq(of_type(ev, "over")[0]["reason"], "hp", "over の理由")
	sim = Sim.new(1)
	sim.clock_running = true
	sim.time_left = 3
	run(sim, 3)
	eq(sim.reason, "time", "残り 0 で時間")
	sim = Sim.new(1)
	sim.clock_running = true
	sim.time_left = 1
	sim.hp = 1
	sim.enemies.clear()
	put(sim, F.CHASER, sim.px, sim.py)
	run(sim, 1)
	ok(sim.hp == 0 and sim.reason == "time", "同じ tick なら時間(E-14)")
	var t := sim.tick
	run(sim, 10)
	eq(sim.tick, t, "終わった後は進まない")
	return true


func test_ac14_freeze_stops_world() -> bool:
	var sim := bare()
	sim.clock_running = true
	put(sim, F.CHASER, 100.0, 300.0)
	sim.bullets.append({"x": 600.0, "y": 300.0, "vx": 0.0, "vy": 2.0})
	put(sim, F.STILL, sim.px, sim.py - 150.0)
	put(sim, F.STILL, sim.px, sim.py - 200.0)
	put(sim, F.STILL, sim.px, sim.py - 250.0)
	sim.queue_dash(0, -100)
	while sim.is_dashing() or sim.pending != null:
		sim.step()
	eq(sim.freeze_left, B.FREEZE_BASE + B.FREEZE_PER * 3, "止めは 4 + 3")
	var snap := [sim.time_left, sim.enemies.map(func(e: Dictionary) -> Array: return [e["x"], e["y"]]),
		sim.bullets.map(func(b: Dictionary) -> Array: return [b["x"], b["y"]])]
	var n := sim.freeze_left
	run(sim, n)
	eq([sim.time_left, sim.enemies.map(func(e: Dictionary) -> Array: return [e["x"], e["y"]]),
		sim.bullets.map(func(b: Dictionary) -> Array: return [b["x"], b["y"]])], snap, "止めの間は止まる")
	run(sim, 1)
	eq(sim.time_left, snap[0] - 1, "明けると進む")
	return true


func test_freeze_length_caps() -> bool:
	for n in [1, 2, 4, 6]:
		var sim := Sim.new(1)
		sim.enemies.clear()
		for k in n:
			put(sim, F.STILL, sim.px, sim.py - 40.0 - 40.0 * k)
		sim.queue_dash(0, -100)
		while sim.is_dashing() or sim.pending != null:
			sim.step()
		eq(sim.freeze_left, 4 + mini(n, 4), "n = %d の止め" % n)
	return true


func test_ac15_day_index() -> bool:
	eq(Day.day_index(2026, 1, 1), 0, "2026-01-01")
	eq(Day.day_index(2026, 11, 12), 315, "2026-11-12")
	eq(Day.day_index(2027, 1, 1), 365, "2027-01-01")
	eq(Day.day_index(2025, 12, 31), 0, "2025-12-31")
	eq(Day.day_seed(315), 1283077756, "種の式")
	eq(Day.date_string(2026, 3, 7), "2026-03-07", "日付の文字")
	return true


func test_score_formula() -> bool:
	eq(Score.points(3, 0), 900, "つなぎ 0 で 3 体")
	eq(Score.points(3, 20), 2700, "つなぎ 20 で 3 体")
	eq(Score.points(3, 99), 2700, "つなぎは 20 で頭打ち")
	eq(Score.points(1, 7), 170, "1 体・つなぎ 7")
	eq(Score.mult_text(Score.mult10(7)), "1.7", "x1.7")
	eq(Score.comma(12400), "12,400", "コンマ")
	eq(Score.comma(1234567), "1,234,567", "コンマ 2 つ")
	eq(Score.comma(900), "900", "3 桁")
	eq(Score.sec1(7200), "60.0", "60.0")
	eq(Score.sec1(5676), "47.3", "47.3")
	eq(Score.sec1(1), "0.1", "最後の tick")
	return true


func test_chain_multiplier_in_play() -> bool:
	var sim := Sim.new(1)
	sim.enemies.clear()
	put(sim, F.STILL, sim.px, sim.py - 100.0)
	dash(sim, 0, -100)
	put(sim, F.STILL, sim.px, sim.py + 100.0)
	var ev := dash(sim, 0, 100)
	var end: Dictionary = of_type(ev, "dash_end")[0]
	eq([end["points"], end["mult10"], end["chain"]], [110, 11, 2], "2 回目は倍率 1.1")
	eq(sim.points, 210, "合計")
	eq(sim.max_chain, 2, "最大つなぎ")
	return true


func test_chain_times_out() -> bool:
	var sim := Sim.new(1)
	sim.enemies.clear()
	put(sim, F.STILL, sim.px, sim.py - 100.0)
	dash(sim, 0, -100)
	eq(sim.chain, 1, "つなぎ 1")
	run(sim, B.CHAIN_KEEP_TICKS - 20)
	eq(sim.chain, 1, "まだ切れない")
	run(sim, 40)
	eq(sim.chain, 0, "360 tick で切れる")
	return true


func test_hurt_resets_chain_and_invincible() -> bool:
	var sim := bare()
	put(sim, F.STILL, sim.px, sim.py - 100.0)
	dash(sim, 0, -100)
	sim.bullets.append({"x": sim.px, "y": sim.py, "vx": 0.0, "vy": 0.0})
	var ev := run(sim, 1)
	eq(sim.hp, 2, "弾で −1")
	eq(sim.chain, 0, "つなぎが 0")
	eq(sim.bullets.size(), 0, "弾は消える")
	ok(types(ev).has("hurt"), "hurt")
	var chaser := put(sim, F.CHASER, sim.px, sim.py)
	run(sim, B.HURT_INVINCIBLE_TICKS - 2)
	eq(sim.hp, 2, "96 tick は当たらない")
	run(sim, 3)
	eq(sim.hp, 1, "明けると当たる")
	ok(sim.enemies.has(chaser), "追う敵は消えない")
	return true


func test_charge_regen() -> bool:
	var sim := Sim.new(1)
	sim.enemies.clear()
	dash(sim, 100, 0)
	eq(sim.charges, 2, "2")
	run(sim, B.CHARGE_REGEN_TICKS - B.DASH_TICKS - 2)
	eq(sim.charges, 2, "まだ 2")
	run(sim, 3)
	eq(sim.charges, 3, "120 tick で 3")
	run(sim, 500)
	eq(sim.charges, 3, "3 より増えない")
	return true


func test_e3_command_during_dash_overwrites() -> bool:
	var sim := Sim.new(1)
	sim.enemies.clear()
	sim.queue_dash(100, 0)
	run(sim, 2)
	sim.queue_dash(0, 100)
	sim.queue_dash(-100, 0)
	while sim.is_dashing():
		sim.step()
	var ev := run(sim, 1)
	var st: Array = of_type(ev, "dash_start")
	ok(st.size() == 1 and st[0]["ux"] < 0.0, "後から来た指示を次の tick に使う")
	sim.queue_dash(0, 0)
	ok(sim.pending == null, "(0, 0) は無視")
	return true


func test_chaser_and_bullet_motion() -> bool:
	var sim := Sim.new(1)
	sim.enemies.clear()
	var e := put(sim, F.CHASER, sim.px, sim.py - 300.0)
	sim.bullets.append({"x": 700.0, "y": 300.0, "vx": 2.0, "vy": 0.0})
	run(sim, 120)
	ok(absf(e["y"] - (sim.py - 210.0)) < 1e-6, "90 px/秒で寄る")
	eq(sim.bullets.size(), 0, "場の外へ出た弾は消える")
	return true


func test_shooter_warn_then_fire() -> bool:
	var sim := Sim.new(1)
	sim.enemies.clear()
	put(sim, F.SHOOTER, 360.0, 300.0)
	var ev := run(sim, B.SHOOTER_PERIOD_TICKS - B.SHOOTER_WARN_TICKS)
	eq(of_type(ev, "shoot_warn").size(), 1, "216 tick で予告")
	eq(sim.bullets.size(), 0, "まだ撃たない")
	run(sim, B.SHOOTER_WARN_TICKS)
	eq(sim.bullets.size(), 1, "288 tick で撃つ")
	var b: Dictionary = sim.bullets[0]
	ok(absf(b["vx"]) < 1e-9 and absf(b["vy"] - 2.0) < 1e-9, "自分の中心へ 240 px/秒")
	return true


func test_e15_bullet_cap() -> bool:
	var sim := Sim.new(1)
	sim.enemies.clear()
	put(sim, F.SHOOTER, 360.0, 300.0)
	for k in B.BULLET_CAP:
		sim.bullets.append({"x": 100.0, "y": 300.0 + k, "vx": 0.0, "vy": 0.0})
	run(sim, B.SHOOTER_PERIOD_TICKS)
	eq(sim.bullets.size(), B.BULLET_CAP, "30 個ある間は撃たない")
	return true


func test_e15_enemy_cap_holds_spawn() -> bool:
	var sim := Sim.new(1)
	wait_marks(sim)
	dash(sim, 0, -100)  # T1 を全部斬ると T2
	eq(sim.spawned, 2, "T2 が出た")
	for k in B.ENEMY_CAP:
		put(sim, F.STILL, 40.0 + (k % 16) * 40.0, 1100.0 - (k / 16) * 40.0)
	run(sim, B.SPAWN_FORCE_TICKS + 10)
	eq(sim.spawned, 2, "40 体以上なら出さない")
	while sim.enemies.size() >= B.ENEMY_CAP:
		sim.enemies.pop_back()
	run(sim, 1)
	eq(sim.spawned, 3, "40 体未満になった tick に出す")
	return true


func test_second_formation_after_t1_cleared() -> bool:
	var sim := Sim.new(1)
	wait_marks(sim)
	sim.queue_dash(0, -100)
	var spawned_at := -1
	var third_cut := -1
	for k in 20:
		sim.step()
		for e: Dictionary in sim.events():
			if e["type"] == "cut_mark" and int(e["k"]) == 2:
				third_cut = sim.tick
		if sim.spawned == 2 and spawned_at < 0:
			spawned_at = sim.tick
	ok(spawned_at > 0 and spawned_at == third_cut, "T1 の 3 体目を斬った tick に 2 番目(%d, %d)" % [spawned_at, third_cut])
	var t2: Array = sim.enemies.filter(func(e: Dictionary) -> bool: return int(e["mark"]) > 0).map(func(e: Dictionary) -> Array: return [e["x"], e["y"]])
	# T2 の (360, 480) は、T1 を上向きに斬り終えた位置 (360, 580) から 100 px なので、INV-10 で点対称の (360, 880) に出る(仕様の食い違い。報告済み)
	eq(t2, [[360.0, 880.0], [360.0, 400.0], [360.0, 320.0], [460.0, 260.0], [540.0, 260.0], [620.0, 260.0]], "T2 の出る位置")
	return true


func test_second_formation_720_after_clock() -> bool:
	var sim := Sim.new(1)
	wait_marks(sim)
	sim.enemies[0]["x"] = 600.0  # 1 体だけ横へずらして、上向きで 2 体だけ斬る
	dash(sim, 0, -100)
	eq(sim.spawned, 1, "T1 が残っている間は出ない")
	ok(sim.clock_running, "時計は動いた")
	while sim.spawned == 1 and sim.clock_ticks < 2000:
		sim.step()
	# 出た tick の step 8 で clock_ticks が 1 増えるので、出たのは動き出してから 720 tick たった tick
	eq(sim.clock_ticks - 1, B.SPAWN_FORCE_TICKS, "時計が動き出してから 720 tick で出る")
	return true


func test_inv10_spawn_keeps_distance() -> bool:
	var close := 0
	var spawns := 0
	for s in [1, 2, 3, 4, 5, 6]:
		var sim := Sim.new(Day.day_seed(s))
		var t := 0
		while not sim.is_over() and t < 9000:
			if t % 25 == 0 and sim.dash_left == 0 and sim.charges > 0:
				var e: Variant = null
				for c: Dictionary in sim.enemies:
					if int(c["mark"]) == 0:
						e = c
						break
				if e != null:
					sim.queue_dash(roundi(e["x"] - sim.px), roundi(e["y"] - sim.py))
			sim.step()
			for ev: Dictionary in sim.events():
				if ev["type"] == "spawn_mark":
					spawns += 1
					var dx: float = ev["x"] - sim.px
					var dy: float = ev["y"] - sim.py
					if dx * dx + dy * dy < 120.0 * 120.0:
						close += 1
			t += 1
	ok(spawns > 100, "並びが出続ける(%d 体)" % spawns)
	eq(close, 0, "自分から 120 px 未満に出ない")
	return true


func test_order_loops_to_13th() -> bool:
	var sim := Sim.new(5)
	sim.spawned = 60
	sim.enemies.clear()
	sim.px = 20.0
	sim.py = 220.0
	sim._spawn_next()
	var want := F.get_formation(sim.order[12]["id"])
	eq(sim.enemies.size(), want["members"].size(), "61 番目は 13 番目の並び")
	return true


func test_spawn_flip_and_symmetric_fallback() -> bool:
	var sim := Sim.new(1)
	sim.enemies.clear()
	sim.order[1] = {"id": "A2", "flip": true}  # (160..560, 500)
	sim.px = 560.0  # 反転で (160, 500) → (560, 500) が自分に重なる
	sim.py = 500.0
	sim._spawn_next()
	var pos: Array = sim.enemies.map(func(e: Dictionary) -> Array: return [e["x"], e["y"]])
	ok(pos.has([160.0, 860.0]), "近すぎる member は点対称へ(%s)" % [pos])
	eq(pos.size(), 5, "5 体とも出る")
	return true


func test_ac2_deterministic_100_runs() -> bool:
	var first: Variant = null
	var same := true
	for k in 100:
		var sim := Sim.new(1283077756)
		bot_play(sim, 17, 4000)
		var r := sim.result()
		var key := [r["points"], r["cuts"], sim.tick, sim.hp, sim.px, sim.py]
		if first == null:
			first = key
		same = same and key == first
	ok(same, "100 回とも同じ")
	ok(int(first[1]) > 10, "斬っている(%s)" % [first])
	return true


# 決定性の固定値(NFR-4)。Windows と Actions(Linux)の両方でこの値になること。値を変える時は決まりを変えた時だけ。
func test_golden_full_run() -> bool:
	var sim := Sim.new(1283077756)
	bot_play(sim, 23)
	var r := sim.result()
	eq([r["points"], r["cuts"], r["max_n"], r["max_chain"], r["reason"], r["ticks"]], GOLDEN, "固定の入力の結果")
	return true

const GOLDEN := [25920, 178, 3, 9, "hp", 6493]


func test_ac23_core_is_pure() -> bool:
	var bad: Array = []
	var re := RegEx.create_from_string("\\b(sin|cos|randf|randi|randf_range|randi_range)\\s*\\(|\\bTime\\.|extends\\s+Node|Node2D|Input\\.")
	for f: String in DirAccess.get_files_at("res://core"):
		if not f.ends_with(".gd"):
			continue
		var lines := FileAccess.get_file_as_string("res://core/" + f).split("\n")
		for k in lines.size():
			var code := lines[k].split("#")[0]
			if re.search(code) != null:
				bad.append("%s:%d" % [f, k + 1])
		ok(FileAccess.get_file_as_string("res://core/" + f).contains("extends RefCounted"), "%s は RefCounted" % f)
	eq(bad, [], "core に Node・sin・cos・乱数関数・Time が無い")
	return true


# AC-24 の一部: 文言(日本語の文字列)が strings.gd の外に無い。数値はレビューで見る。
func test_ac24_no_text_outside_strings() -> bool:
	var bad: Array = []
	var re := RegEx.create_from_string("\"[^\"]*[\\x{3040}-\\x{30FF}\\x{4E00}-\\x{9FFF}][^\"]*\"")
	for dir: String in ["res://core", "res://ui", "res://audio", "res://save"]:
		for f: String in DirAccess.get_files_at(dir):
			if not f.ends_with(".gd") or f == "strings.gd":
				continue
			var lines := FileAccess.get_file_as_string(dir.path_join(f)).split("\n")
			for k in lines.size():
				if re.search(lines[k].split("#")[0]) != null:
					bad.append("%s/%s:%d" % [dir, f, k + 1])
	eq(bad, [], "文言は strings.gd だけ")
	return true
