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
		draw_dashed_line(me, Vector2(aim["end_x"], aim["end_y"]), Color(Kit.C_LINE, 0.8), 3.0, 14.0, true, true)
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


# 体力の丸(右上)と回数の四角(下の中央)。
func _hud() -> void:
	for k in B.HP_MAX:
		var p := Vector2(600.0 + 44.0 * k, 68.0)
		if k < int(snap["hp"]):
			draw_circle(p, 13.0, Kit.C_TEXT)
		else:
			draw_arc(p, 13.0, 0.0, TAU, 24, Color(Kit.C_DIM, 0.8), 2.0, true)
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
