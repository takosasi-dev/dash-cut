# 画面の共通部品(色・字体・ラベル・ボタン・置き場所・数字・キーの印)。色は画面設計書 §9(場の意味の色)と §11(墨と朱の板)。
# 見た目の既定は ui/theme.tres(tools/make_theme.gd が作る。project の gui/theme/custom で全部の Control に付く)。
# 文言は持たない。各画面は文言を core/strings.gd から渡す。
extends RefCounted

const F := preload("res://core/formations.gd")

const SANS := "res://assets/fonts/NotoSansJP-Subset.ttf"
const DISPLAY := "res://assets/fonts/ShipporiMinchoB1-Subset.ttf"  # 題字・数字・判(ASCII と数文字だけ。ほかは Noto へ落とす)

# 墨と朱の板(§11)
const C_INK := Color("12100E")  # 墨: 地
const C_SUMI := Color("1D1A16")  # 濃墨: 板・ボタン・HUD の帯
const C_USU := Color("4A4339")  # 薄墨: 罫・枠
const C_WASHI := Color("EEE6D3")  # 和紙: 字
const C_NEZU := Color("A89F8C")  # 鼠: 弱い字
const C_SHU := Color("D8432C")  # 朱: 印(落款・選んでいる所・新しい記録)だけ

# 場の意味の色(§9。v0.2.0 のまま)
const C_PLAYER := Color("FFFFFF")
const C_STILL := Color("FFB84D")
const C_CHASER := Color("FF6B6B")
const C_SHOOTER := Color("6BB8FF")
const C_BULLET := Color("FFE066")
const C_LINE := Color("FFFFFF")
const C_DANGER := Color("FF4D4D")
const C_GOOD := Color("7EE787")

# 画面のコードが使う名前
const C_BG := C_INK
const C_FRAME := C_USU
const C_TEXT := C_WASHI
const C_DIM := C_NEZU

const SKEW := 0.18  # ボタンと回数の四角の傾き(払いの向き)

static var _fonts := {}
static var _num: Font = null


static func font(weight: int = 400) -> Font:
	if not _fonts.has(weight):
		var fv := FontVariation.new()
		fv.base_font = load(SANS)
		fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
		_fonts[weight] = fv
	return _fonts[weight]


# 題字と数字の明朝。部分集合に無い字(点・体・つなぎ など)は Noto Sans JP の 700 で描く。
static func num_font() -> Font:
	if _num == null:
		var fv := FontVariation.new()
		fv.base_font = load(DISPLAY)
		fv.fallbacks = [font(700)]
		_num = fv
	return _num


static func kind_color(kind: int) -> Color:
	return [C_STILL, C_CHASER, C_SHOOTER][kind]


static func label(text: String, size: int, color: Color = C_TEXT, weight: int = 400) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", font(weight))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


# ボタン。形と 5 つの状態は theme.tres。node_name は自動の確認が押す時の目印。
# キーは main が受けて ui/menu.gd が選びを動かす(Godot のフォーカスの移動は使わないが、選んだ印に focus を使う)。
static func button(node_name: String, text: String, size: int = 32) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", size)
	return b


# 選んでいる値のボタン(設定の音量・入切)は和紙で塗る(型の変種 OnButton)。
static func set_selected(b: Button, on: bool) -> void:
	b.theme_type_variation = &"OnButton" if on else &""


static func place(c: Control, x: float, y: float, w: float, h: float) -> Control:
	c.position = Vector2(x, y)
	c.size = Vector2(w, h)
	if c is Button:
		c.custom_minimum_size = Vector2(w, h)
	return c


static func ease_out(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return 1.0 - (1.0 - t) * (1.0 - t) * (1.0 - t)


# 数を明朝で描く。数字は 1 桁ずつ同じ幅の枠に置く(明朝は桁の幅が揃わないので、毎フレーム変わる数が横に震えないように)。
# pos は基線の左端、w を渡すと w の中で align(0 左・1 真ん中・2 右)に寄せる。戻り値は描いた幅。
static func draw_num(ci: CanvasItem, pos: Vector2, text: String, size: int, color: Color, w: float = 0.0, align: int = 0, outline: int = 0, outline_color: Color = C_INK) -> float:
	var f := num_font()
	var cell := f.get_string_size("0", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var widths: Array[float] = []
	var total := 0.0
	for ch in text:
		var cw := cell if ch >= "0" and ch <= "9" else f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		widths.append(cw)
		total += cw
	var x := pos.x + ((w - total) / 2.0 if align == 1 else (w - total) if align == 2 else 0.0)
	for k in text.length():
		var ch := text[k]
		var gx := x + (widths[k] - f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x) / 2.0
		if outline > 0:
			ci.draw_string_outline(f, Vector2(gx, pos.y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, outline_color)
		ci.draw_string(f, Vector2(gx, pos.y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
		x += widths[k]
	return total


# 平行四辺形(下の辺を左へ、上の辺を右へずらす。払いの向き)。
static func slant(r: Rect2, k: float = SKEW) -> PackedVector2Array:
	var d := r.size.y * k / 2.0
	return PackedVector2Array([r.position + Vector2(d, 0), Vector2(r.end.x + d, r.position.y), r.end - Vector2(d, 0), Vector2(r.position.x - d, r.end.y)])


# キーの印(角の立った枠と字)。矢印は "up" "down" "left" "right" を渡すと三角を描く。戻り値は印の幅。
static func draw_key(ci: CanvasItem, at: Vector2, key: String, h: float = 40.0) -> float:
	var f := font(700)
	var fs := int(h * 0.5)
	var arrows := {"up": Vector2.UP, "down": Vector2.DOWN, "left": Vector2.LEFT, "right": Vector2.RIGHT}
	var w := h if arrows.has(key) else maxf(h, f.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + h * 0.6)
	var r := Rect2(at, Vector2(w, h))
	ci.draw_rect(r, C_SUMI)
	ci.draw_rect(r, C_USU.lightened(0.25), false, 2.0)
	ci.draw_line(Vector2(r.position.x + 3, r.end.y - 3), Vector2(r.end.x - 3, r.end.y - 3), C_USU, 2.0)  # 下の厚み
	if arrows.has(key):
		var d: Vector2 = arrows[key]
		var c := r.get_center() - Vector2(0, 1)
		var s := Vector2(-d.y, d.x)
		ci.draw_colored_polygon(PackedVector2Array([c + d * h * 0.2, c - d * h * 0.14 + s * h * 0.2, c - d * h * 0.14 - s * h * 0.2]), C_WASHI)
	else:
		ci.draw_string(f, Vector2(r.position.x, r.position.y + h * 0.5 + fs * 0.36), key, HORIZONTAL_ALIGNMENT_CENTER, w, fs, C_WASHI)
	return w


# 敵の形(止まる = 丸、追う = 自分の方を向く三角、撃つ = 四角)。
static func draw_shape(ci: CanvasItem, kind: int, p: Vector2, r: float, c: Color, me: Vector2) -> void:
	match kind:
		F.STILL:
			ci.draw_circle(p, r, c)
		F.CHASER:
			# 半径 r の円に内接する三角。自分の方を向く
			var d := (me - p).normalized()
			if d == Vector2.ZERO:
				d = Vector2.UP
			var s := Vector2(-d.y, d.x)
			ci.draw_colored_polygon(PackedVector2Array([p + d * r, p + (-d * 0.5 + s * 0.866) * r, p + (-d * 0.5 - s * 0.866) * r]), c)
		F.SHOOTER:
			ci.draw_rect(Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), c)
