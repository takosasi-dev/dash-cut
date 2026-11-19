# 画面の共通部品(色・字体・ラベル・ボタン・置き場所)。画面設計書 §9 の色はここに置く。
# 文言は持たない。各画面は文言を core/strings.gd から渡す。
extends RefCounted

const SANS := "res://assets/fonts/NotoSansJP-Subset.ttf"

const C_BG := Color("0E1116")
const C_FRAME := Color("2A313C")
const C_PLAYER := Color("FFFFFF")
const C_STILL := Color("FFB84D")
const C_CHASER := Color("FF6B6B")
const C_SHOOTER := Color("6BB8FF")
const C_BULLET := Color("FFE066")
const C_LINE := Color("FFFFFF")
const C_TEXT := Color("E6E6E6")
const C_DIM := Color("8B95A5")
const C_DANGER := Color("FF4D4D")
const C_GOOD := Color("7EE787")
const C_SEL := Color("6BB8FF")

static var _fonts := {}


static func font(weight: int = 400) -> Font:
	if not _fonts.has(weight):
		var fv := FontVariation.new()
		fv.base_font = load(SANS)
		fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
		_fonts[weight] = fv
	return _fonts[weight]


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


static func box(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(8)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.anti_aliasing = true
	return s


# ボタン。node_name は自動の確認が押す時の目印。キーは main が受けるので、フォーカスは使わない。
static func button(node_name: String, text: String, size: int = 32) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", font(700))
	b.add_theme_font_size_override("font_size", size)
	set_selected(b, false)
	b.add_theme_stylebox_override("pressed", box(Color(C_SEL, 0.3), C_SEL, 3))
	b.add_theme_stylebox_override("disabled", box(Color(1, 1, 1, 0.02), Color(C_DIM, 0.3), 2))
	for c: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, C_TEXT)
	b.add_theme_color_override("font_disabled_color", Color(C_DIM, 0.5))
	return b


# 選んでいる値のボタン(設定の音量・入切)は縁を青く塗る。
static func set_selected(b: Button, on: bool) -> void:
	var edge := C_SEL if on else Color(C_TEXT, 0.5)
	var fill := Color(C_SEL, 0.22) if on else Color(1, 1, 1, 0.04)
	b.add_theme_stylebox_override("normal", box(fill, edge, 3 if on else 2))
	b.add_theme_stylebox_override("hover", box(Color(C_SEL, 0.14), C_SEL, 3))


static func place(c: Control, x: float, y: float, w: float, h: float) -> Control:
	c.position = Vector2(x, y)
	c.size = Vector2(w, h)
	if c is Button:
		c.custom_minimum_size = Vector2(w, h)
	return c
