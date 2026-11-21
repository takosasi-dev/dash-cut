# プレイ画面の描画(画面設計書 §3・§9・§11)。sim.snapshot() と狙いの予測と fx を受けて、形だけで描く(D-18)。
# 敵の種類は形で分ける: 止まる = 丸、追う = 三角、撃つ = 四角、弾 = ひし形、自分 = 白い丸と向きの印(FR-9・NFR-11)。
# v0.3.0: 上 200 px と下 120 px を濃墨の帯にし、場の枠の四隅に和紙色の鉤。数(残り時間・点・つなぎ)は明朝で 1 桁ずつ同じ幅に描く。
extends Control

const B := preload("res://core/balance.gd")
const F := preload("res://core/formations.gd")
const S := preload("res://core/strings.gd")
const Score := preload("res://core/score.gd")
const Kit := preload("res://ui/kit.gd")
const Fx := preload("res://ui/fx.gd")

const POINTS_SIZE := 56
const TIME_SIZE := 44
const CHAIN_SIZE := 28

var snap: Dictionary = {}
var fx: Fx
var aim: Dictionary = {}  # Geom.preview の戻り値(狙っていない時は空)
var guide := Vector2.INF  # 最初に斬るまで矢印で指す敵の位置(出さない時は INF)
var now := 0


func _draw() -> void:
	if snap.is_empty():
		return
	_bands()
	var me := Vector2(snap["x"], snap["y"])
	var hits: Array = aim.get("hit_ids", [])
	for e: Dictionary in snap["enemies"]:
		_enemy(e, me, hits.has(e["id"]))
	for b: Dictionary in snap["bullets"]:
		var p := Vector2(b["x"], b["y"])
		var r := B.BULLET_RADIUS + 1.0
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0)]), Kit.C_BULLET)
	fx.draw_world(self, now, me.x, me.y)
	if not aim.is_empty():
		var end := Vector2(aim["end_x"], aim["end_y"])
		draw_dashed_line(me, end, Color(Kit.C_LINE, 0.8), 3.0, 14.0, true, true)
		draw_arc(end, B.PLAYER_RADIUS, 0.0, TAU, 24, Color(Kit.C_LINE, 0.55), 2.0, true)  # 止まる所
	elif guide != Vector2.INF and not snap["dashing"]:
		fx.draw_guide(self, now, me, guide)
	# 自分(当たった後の当たらない間は半透明)
	var a := 0.4 if int(snap["hurt_left"]) > 0 else 1.0
	draw_circle(me, B.PLAYER_RADIUS, Color(Kit.C_PLAYER, a))
	var f := Vector2(snap["face_x"], snap["face_y"])
	var side := Vector2(-f.y, f.x)
	var tip := me + f * (B.PLAYER_RADIUS + 12.0)
	var base := me + f * (B.PLAYER_RADIUS + 3.0)
	draw_colored_polygon(PackedVector2Array([tip, base + side * 6.0, base - side * 6.0]), Color(Kit.C_PLAYER, a))
	_hud()
	fx.draw_top(self, now)


# 上と下の帯、場の枠と四隅の鉤。帯は窓の横いっぱい(720 より広い窓でも切れ目を出さない)。
func _bands() -> void:
	var wide := 4000.0
	draw_rect(Rect2(-wide, -wide, B.SCREEN_W + wide * 2.0, B.FIELD_Y0 + wide), Kit.C_SUMI)
	draw_rect(Rect2(-wide, B.FIELD_Y1, B.SCREEN_W + wide * 2.0, wide), Kit.C_SUMI)
	draw_line(Vector2(-wide, B.FIELD_Y0), Vector2(B.SCREEN_W + wide, B.FIELD_Y0), Kit.C_USU, 2.0)
	draw_line(Vector2(-wide, B.FIELD_Y1), Vector2(B.SCREEN_W + wide, B.FIELD_Y1), Kit.C_USU, 2.0)
	# 横に余りが出る窓では、場の左右も濃墨で塗って縦の罫を引く(場の端が見えないと、突進が見えない壁で止まる)
	draw_rect(Rect2(B.FIELD_X0 - wide, B.FIELD_Y0, wide, B.FIELD_Y1 - B.FIELD_Y0), Kit.C_SUMI)
	draw_rect(Rect2(B.FIELD_X1, B.FIELD_Y0, wide, B.FIELD_Y1 - B.FIELD_Y0), Kit.C_SUMI)
	draw_line(Vector2(B.FIELD_X0, B.FIELD_Y0), Vector2(B.FIELD_X0, B.FIELD_Y1), Kit.C_USU, 2.0)
	draw_line(Vector2(B.FIELD_X1, B.FIELD_Y0), Vector2(B.FIELD_X1, B.FIELD_Y1), Kit.C_USU, 2.0)
	var r := Rect2(B.FIELD_X0, B.FIELD_Y0, B.FIELD_X1 - B.FIELD_X0, B.FIELD_Y1 - B.FIELD_Y0).grow(-6.0)
	var c := Color(Kit.C_WASHI, 0.35)
	var k := 26.0
	for corner: Array in [[r.position, 1, 1], [Vector2(r.end.x, r.position.y), -1, 1], [Vector2(r.position.x, r.end.y), 1, -1], [r.end, -1, -1]]:
		var p: Vector2 = corner[0]
		draw_polyline(PackedVector2Array([p + Vector2(0, k * corner[2]), p, p + Vector2(k * corner[1], 0)]), c, 2.0)


func _enemy(e: Dictionary, me: Vector2, targeted: bool) -> void:
	var p := Vector2(e["x"], e["y"])
	var r: float = e["r"]
	var kind: int = e["kind"]
	var c := Kit.kind_color(kind)
	var mark: int = e["mark"]
	if mark > 0:
		# 出る場所に縮む輪(60 tick)と、薄い形
		var t := float(mark) / B.SPAWN_MARK_TICKS
		draw_arc(p, r + 6.0 + 40.0 * t, 0.0, TAU, 32, Color(c, 0.9 - 0.5 * t), 2.0, true)
		Kit.draw_shape(self, kind, p, r, Color(c, 0.25), me)
		return
	Kit.draw_shape(self, kind, p, r, c, me)
	var warn := kind == F.SHOOTER and int(e["t"]) % B.SHOOTER_PERIOD_TICKS >= B.SHOOTER_PERIOD_TICKS - B.SHOOTER_WARN_TICKS
	if warn:
		draw_rect(Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), Kit.C_LINE, false, 4.0)
	if targeted:
		draw_arc(p, r + 6.0, 0.0, TAU, 32, Kit.C_LINE, 3.0, true)


# 残り時間(上の真ん中)・体力の丸(右上)・点(左、一番大きく)・つなぎと残りの棒(右)・回数の四角(下の中央)。
func _hud() -> void:
	# 残り時間: 時計が動く前は薄く、残り 10 秒から赤く 1.3 倍
	var t: int = snap["time_left"]
	var running: bool = snap["clock_running"]
	var last := t <= B.CLOCK_BIG_SEC * B.TICK_HZ
	var tc := (Kit.C_DANGER if last else Kit.C_TEXT) if running else Color(Kit.C_DIM, 0.7)
	var ts := int(TIME_SIZE * (B.CLOCK_BIG if last else 1.0))
	Kit.draw_num(self, Vector2(160, 98 + (ts - TIME_SIZE) * 0.35), Score.sec1(t), ts, tc, 400, 1)
	# 体力
	for k in B.HP_MAX:
		var p := Vector2(600.0 + 44.0 * k, 76.0)
		if k < int(snap["hp"]):
			draw_circle(p, 13.0, Kit.C_TEXT)
		else:
			draw_arc(p, 13.0, 0.0, TAU, 24, Color(Kit.C_DIM, 0.8), 2.0, true)
	var ht := Fx.phase(now, int(fx.hp_lost["at"]), B.HP_LOST_MS)
	if ht >= 0.0:
		# 消えた体力の丸が赤く弾ける
		var p := Vector2(600.0 + 44.0 * int(fx.hp_lost["index"]), 76.0)
		draw_circle(p, 13.0 * (1.0 - ht), Color(Kit.C_DANGER, 1.0 - ht))
		draw_arc(p, 13.0 + 18.0 * ht, 0.0, TAU, 24, Color(Kit.C_DANGER, 1.0 - ht), 3.0, true)
	# 点: 左の基線を中心に跳ねる
	var pb := Fx.bump(now, fx.points_bump_at)
	var base := Vector2(28, 176)
	draw_set_transform(base, 0.0, Vector2.ONE * pb)
	var w := Kit.draw_num(self, Vector2.ZERO, Score.comma(int(snap["points"])), POINTS_SIZE, Kit.C_TEXT)
	draw_string(Kit.font(700), Vector2(w + 6.0, 0), S.RES_UNIT, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Kit.C_DIM)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# つなぎ: 右の基線を中心に跳ねる
	var chain: int = snap["chain"]
	var right := Vector2(696, 160)
	if chain > 0:
		var text := S.HUD_CHAIN % [chain, Score.mult_text(Score.mult10(chain))]
		draw_set_transform(right, 0.0, Vector2.ONE * Fx.bump(now, fx.chain_bump_at))
		draw_string(Kit.num_font(), Vector2(-336, 0), text, HORIZONTAL_ALIGNMENT_RIGHT, 336.0, CHAIN_SIZE, Kit.C_TEXT)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# つなぎが切れるまでの残り(3 秒)。残りが 3 分の 1 を切ると赤く
		var left := 1.0 - float(snap["chain_idle"]) / B.CHAIN_KEEP_TICKS
		var bar := Rect2(496.0, 176.0, 200.0, 6.0)
		draw_rect(bar, Kit.C_USU)
		draw_rect(Rect2(bar.end.x - bar.size.x * left, bar.position.y, bar.size.x * left, bar.size.y), Kit.C_DANGER if left < 0.34 else Kit.C_TEXT)
	var lt := Fx.phase(now, int(fx.chain_lost["at"]), B.CHAIN_LOST_MS)
	if lt >= 0.0 and chain == 0:
		# 切れたつなぎを赤く残し、下へ落として消す
		var font := Kit.num_font()
		var pos := Vector2(360.0, right.y + 16.0 * lt)
		draw_string(font, pos, fx.chain_lost["text"], HORIZONTAL_ALIGNMENT_RIGHT, 336.0, CHAIN_SIZE, Color(Kit.C_DANGER, 1.0 - lt))
		var tw := font.get_string_size(fx.chain_lost["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, CHAIN_SIZE).x
		draw_line(pos + Vector2(336.0 - tw, -9.0), pos + Vector2(336.0, -9.0), Color(Kit.C_DANGER, 1.0 - lt), 3.0)
	# 回数
	var charges: int = snap["charges"]
	var red := fx.is_no_charge(now)
	for k in B.CHARGE_MAX:
		var box := Rect2(320.0 + 64.0 * k, 1200.0, 44.0, 44.0)
		var edge := Kit.C_DANGER if red else Color(Kit.C_TEXT, 0.8)
		if k < charges:
			draw_rect(box, Kit.C_TEXT)
		elif k == charges:
			# 戻る途中の 1 個は、下から上へ塗りが増える
			var h := box.size.y * int(snap["regen"]) / B.CHARGE_REGEN_TICKS
			draw_rect(Rect2(box.position.x, box.end.y - h, box.size.x, h), Color(Kit.C_TEXT, 0.45))
		draw_rect(box, edge, false, 2.0)
		if k == charges and fx.is_whiffing(now):
			# 外した突進で欠けた 1 個(150 ms で縮んで消える)
			var wt := float(now - fx.whiff_at) / B.WHIFF_MS
			draw_rect(box.grow(-box.size.x / 2.0 * wt), Color(Kit.C_TEXT, 1.0 - wt))
		var rt := Fx.phase(now, fx.refill_at, B.REFILL_MS)
		if k == charges - 1 and rt >= 0.0:
			# 斬って戻った 1 個が光って広がる(D-3 を見せる)
			draw_rect(box.grow(14.0 * rt), Color(Kit.C_GOOD, 1.0 - rt), false, 3.0)
