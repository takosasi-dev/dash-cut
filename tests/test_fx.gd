# 演出(ui/fx.gd)のテスト。磨きで足した物(v0.2.0)の分岐: 止めの間は割らない・割れる時の破片と輪・3 体以上だけの光・
# 点滅を弱める時の光の上限・点の表示を重ねない・つなぎが切れた印・斬って戻った回数の印・体力の印・終わりの理由・最初の矢印。
extends "res://tests/suite.gd"

const Fx := preload("res://ui/fx.gd")
const Score := preload("res://core/score.gd")
const MainScene := preload("res://ui/main.tscn")
const Store := preload("res://save/save_store.gd")


# 上向きの突進で n 体を斬り、突進が終わった所まで(止めの前)。
static func cut(fx: Fx, n: int, now: int) -> void:
	fx.on_event({"type": "dash_start", "x": 360.0, "y": 900.0, "ux": 0.0, "uy": -1.0}, now)
	for k in n:
		fx.on_event({"type": "cut_mark", "id": k + 1, "kind": 0, "x": 360.0, "y": 800.0 - 60.0 * k, "r": 18.0, "k": k}, now)
	fx.on_event({"type": "dash_end", "n": n, "points": 10 * n * n * 10, "mult10": 10, "chain": 1, "x": 360.0, "y": 580.0}, now)


func test_fx_shatter_waits_for_freeze() -> bool:
	var fx := Fx.new()
	cut(fx, 3, 1000)
	fx.update(1010, 7)
	ok(fx.freezing, "止めの間は斬った敵が白く光る")
	eq(fx.shards.size(), 0, "止めの間は割らない")
	eq(fx.corpses.size(), 3, "斬った敵は止まった絵のまま残る")
	fx.update(1060, 0)
	eq(fx.shards.size(), 3 * B.SHARDS_PER_ENEMY, "止めが明けたら 1 体ごとに破片 6 個")
	eq(fx.rings.size(), 3, "1 体ごとに輪 1 つ")
	ok(fx.rings.all(func(r: Dictionary) -> bool: return r["grow"] == B.RING_GROW_BIG), "3 体以上は大きい輪")
	eq(fx.flash_alpha(1060), B.FLASH_ALPHA, "3 体以上は場が光る")
	ok(fx.corpses.is_empty() and not fx.freezing, "割った後は残さない")
	ok(fx.shards.all(func(s: Dictionary) -> bool: return s["vy"] < 0.0 or absf(s["vx"]) > 0.0), "破片は動く")
	var up := fx.shards.filter(func(s: Dictionary) -> bool: return s["vy"] < 0.0).size()
	ok(up > B.SHARDS_PER_ENEMY * 3 / 2, "破片は突進の向き(上)へ多く流れる: %d" % up)
	fx.update(1060 + B.SHARD_MS, 0)
	ok(fx.shards.is_empty() and fx.rings.is_empty(), "300 ms で消える")
	eq(fx.flash_alpha(1060 + B.FLASH_MS), 0.0, "光は 120 ms で消える")
	return true


func test_fx_small_cut_is_quiet() -> bool:
	var fx := Fx.new()
	cut(fx, 2, 0)
	fx.update(100, 0)
	ok(fx.rings.all(func(r: Dictionary) -> bool: return r["grow"] == B.RING_GROW), "2 体までは小さい輪")
	eq(fx.flash_alpha(100), 0.0, "2 体までは場が光らない(派手なのは 3 体以上だけ)")
	ok(not fx.popups[0]["big"], "2 体の点の表示は大きくしない")
	return true


func test_fx_reduce_flash_caps_light() -> bool:
	ok(B.FLASH_ALPHA_REDUCED <= 0.2 and B.REDUCED_FLASH_ALPHA <= 0.2, "点滅を弱める時の値は 20% 以下")
	var fx := Fx.new()
	fx.reduce_flash = true
	cut(fx, 4, 0)
	fx.update(10, 0)
	var top := 0.0
	for t in range(10, 10 + B.FLASH_MS, 5):
		top = maxf(top, fx.flash_alpha(t))
	ok(top > 0.0 and top <= 0.2, "点滅を弱めると場の光は 0.2 以下: " + str(top))
	return true


func test_fx_popups_do_not_overlap() -> bool:
	var fx := Fx.new()
	cut(fx, 1, 0)
	cut(fx, 1, 0)
	cut(fx, 1, 50)
	var ys := fx.popups.map(func(p: Dictionary) -> float: return p["y"] - B.POPUP_RISE * (50.0 - p["at"]) / B.POPUP_MS)
	ok(absf(ys[0] - ys[1]) >= B.POPUP_GAP - 0.01 and absf(ys[1] - ys[2]) >= B.POPUP_GAP - 0.01 and absf(ys[0] - ys[2]) >= B.POPUP_GAP - 0.01, "同じ所の点の表示は上へずらす: %s" % [ys])
	var fx2 := Fx.new()
	fx2.on_event({"type": "dash_end", "n": 1, "points": 100, "mult10": 10, "chain": 1, "x": 360.0, "y": 214.0}, 0)
	ok(fx2.popups[0]["y"] >= B.FIELD_Y0 + 40.0, "上の表示に重ねない")
	return true


func test_fx_chain_bump_and_lost() -> bool:
	var fx := Fx.new()
	fx.on_chain(1, 100)
	fx.on_chain(3, 200)
	eq(fx.chain_bump_at, 200, "つなぎが増えたら字が跳ねる")
	ok(Fx.bump(200, 200) > 1.0 and Fx.bump(200 + B.BUMP_MS, 200) == 1.0, "跳ねるのは 160 ms")
	fx.on_chain(0, 300)
	eq(fx.chain_lost["at"], 300, "つなぎが切れた時刻")
	eq(fx.chain_lost["text"], S.HUD_CHAIN % [3, Score.mult_text(Score.mult10(3))], "切れたつなぎの数を残す")
	fx.on_chain(0, 400)
	eq(fx.chain_lost["at"], 300, "0 のままなら何もしない")
	return true


func test_fx_refill_hp_over() -> bool:
	var fx := Fx.new()
	cut(fx, 1, 500)
	eq(fx.refill_at, 500, "斬った突進で戻った回数の四角が光る")
	eq(fx.points_bump_at, 500, "点の字が跳ねる")
	fx.on_event({"type": "dash_end", "n": 0, "points": 0, "mult10": 10, "chain": 0, "x": 0.0, "y": 0.0}, 900)
	ok(fx.refill_at == 500 and fx.whiff_at == 900, "外した突進では光らず、欠ける")
	fx.on_event({"type": "hurt", "by": "bullet", "hp": 1}, 1000)
	ok(fx.hp_lost["at"] == 1000 and fx.hp_lost["index"] == 1, "消えた体力の丸(2 個目)が弾ける")
	fx.on_event({"type": "over", "reason": "hp"}, 1200)
	eq(fx.over["text"], S.REASON_HP, "終わりの理由を場に出す")
	fx.on_event({"type": "over", "reason": "time"}, 1300)
	eq(fx.over["text"], S.REASON_TIME, "時間切れ")
	return true


# プレイ画面: 最初に斬るまで、矢印は一番近い敵を指し、キーボードの手がかりを出す。斬ったら消す。
func test_play_guide_until_first_cut() -> bool:
	if FileAccess.file_exists(Store.PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Store.PATH))
	var m := MainScene.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(m)
	m.find_child("daily", true, false).pressed.emit()
	m.play._refresh()
	eq(m.play.field.guide, Vector2.INF, "印の間は指さない")
	for k in 31:
		m.play._process(1.0 / 60.0)
	eq(m.play.field.guide, Vector2(360, 770), "T1 の一番近い 1 体を指す")
	ok(m.play._l["keys"].visible and m.play._l["hint"].visible, "払うと突進・キーボードの手がかり")
	m.play.sim.queue_dash(0, -100)
	for k in 30:
		m.play._process(1.0 / 60.0)
	eq(m.play.sim.cuts, 3, "T1 を斬る")
	eq(m.play.field.guide, Vector2.INF, "斬ったら矢印を消す")
	ok(not m.play._l["keys"].visible, "斬ったら手がかりを消す")
	m.get_parent().remove_child(m)
	m.free()
	return true
