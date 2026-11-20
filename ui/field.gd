# プレイ画面の描画(画面設計書 §3・§9)。sim.snapshot() と狙いの予測と fx を受けて、形だけで描く(D-18)。
# 敵の種類は形で分ける: 止まる = 丸、追う = 三角、撃つ = 四角、弾 = ひし形、自分 = 白い丸と向きの印(FR-9・NFR-11)。
extends Control

const B := preload("res://core/balance.gd")
const F := preload("res://core/formations.gd")
const Kit := preload("res://ui/kit.gd")
const Fx := preload("res://ui/fx.gd")

var snap: Dictionary = {}
var fx: Fx
var aim: Dictionary = {}  # Geom.preview の戻り値(狙っていない時は空)
var guide := Vector2.INF  # 最初に斬るまで矢印で指す敵の位置(出さない時は INF)
var now := 0


func _draw() -> void:
	if snap.is_empty():
		return
	draw_rect(Rect2(B.FIELD_X0, B.FIELD_Y0, B.FIELD_X1 - B.FIELD_X0, B.FIELD_Y1 - B.FIELD_Y0), Kit.C_FRAME, false, 2.0)
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


# 体力の丸(右上)・つなぎの残り時間の棒(上の右)・回数の四角(下の中央)。
func _hud() -> void:
	for k in B.HP_MAX:
		var p := Vector2(600.0 + 44.0 * k, 68.0)
		if k < int(snap["hp"]):
			draw_circle(p, 13.0, Kit.C_TEXT)
		else:
			draw_arc(p, 13.0, 0.0, TAU, 24, Color(Kit.C_DIM, 0.8), 2.0, true)
	var ht := Fx.phase(now, int(fx.hp_lost["at"]), B.HP_LOST_MS)
	if ht >= 0.0:
		# 消えた体力の丸が赤く弾ける
		var p := Vector2(600.0 + 44.0 * int(fx.hp_lost["index"]), 68.0)
		draw_circle(p, 13.0 * (1.0 - ht), Color(Kit.C_DANGER, 1.0 - ht))
		draw_arc(p, 13.0 + 18.0 * ht, 0.0, TAU, 24, Color(Kit.C_DANGER, 1.0 - ht), 3.0, true)
	var chain: int = snap["chain"]
	if chain > 0:
		# つなぎが切れるまでの残り(3 秒)。残りが 3 分の 1 を切ると赤く
		var left := 1.0 - float(snap["chain_idle"]) / B.CHAIN_KEEP_TICKS
		var bar := Rect2(496.0, 186.0, 200.0, 6.0)
		draw_rect(bar, Color(Kit.C_FRAME, 1.0))
		draw_rect(Rect2(bar.end.x - bar.size.x * left, bar.position.y, bar.size.x * left, bar.size.y), Kit.C_DANGER if left < 0.34 else Kit.C_TEXT)
	var lt := Fx.phase(now, int(fx.chain_lost["at"]), B.CHAIN_LOST_MS)
	if lt >= 0.0 and chain == 0:
		# 切れたつなぎを赤く残し、下へ落として消す
		var font := Kit.font(700)
		var pos := Vector2(360.0, 176.0 + 16.0 * lt)
		draw_string(font, pos, fx.chain_lost["text"], HORIZONTAL_ALIGNMENT_RIGHT, 336.0, 30, Color(Kit.C_DANGER, 1.0 - lt))
		draw_line(pos + Vector2(336.0 - _text_w(font, fx.chain_lost["text"]), -10.0), pos + Vector2(336.0, -10.0), Color(Kit.C_DANGER, 1.0 - lt), 3.0)
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
			var t := float(now - fx.whiff_at) / B.WHIFF_MS
			draw_rect(box.grow(-box.size.x / 2.0 * t), Color(Kit.C_TEXT, 1.0 - t))
		var rt := Fx.phase(now, fx.refill_at, B.REFILL_MS)
		if k == charges - 1 and rt >= 0.0:
			# 斬って戻った 1 個が光って広がる(D-3 を見せる)
			draw_rect(box.grow(14.0 * rt), Color(Kit.C_GOOD, 1.0 - rt), false, 3.0)


static func _text_w(font: Font, text: String) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
