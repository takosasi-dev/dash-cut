# 点数の式(仕様書 §9.7)と、点の見せ方(3 桁ごとのコンマ・倍率の小数 1 桁)。整数だけで計算する。
extends RefCounted

const B := preload("res://core/balance.gd")


# 倍率 × 10(つなぎ 0 → 10、つなぎ 7 → 17、20 以上 → 30)。
static func mult10(chain_before: int) -> int:
	return B.MULT_BASE + mini(chain_before, B.CHAIN_CAP)


# 1 回の突進の点。n は斬った数(1 以上)、chain_before はこの突進の前のつなぎ。
static func points(n: int, chain_before: int) -> int:
	return B.POINT_UNIT * n * n * mult10(chain_before)


# 17 → "1.7"
@warning_ignore("integer_division")
static func mult_text(m10: int) -> String:
	return "%d.%d" % [m10 / 10, m10 % 10]


# 12400 → "12,400"
static func comma(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if v < 0 else "") + s + out


# 残り時間(tick)→ "47.3"(小数 1 桁、切り上げ。0 は "0.0")
@warning_ignore("integer_division")
static func sec1(ticks: int) -> String:
	var t10 := (ticks * 10 + B.TICK_HZ - 1) / B.TICK_HZ
	return "%d.%d" % [t10 / 10, t10 % 10]
