# ui/theme.tres を作る(v0.3.0 の墨と朱。project の gui/theme/custom で全部の Control に付く)。色や形を変えたら回し直してコミットする。
#     python tools/gd.py run res://tools/make_theme.gd
# ボタンは normal / hover / focus / pressed / disabled と、設定の選んでいる値の型の変種 OnButton。
# 入力欄・右クリックのメニュー・ツールチップ・スクロールバー・つまみ・チェックも作る(今の画面に無い物も、後から足した時に既定の見た目に戻らないように)。
extends SceneTree

const Kit := preload("res://ui/kit.gd")
const OUT := "res://ui/theme.tres"


func _initialize() -> void:
	var err := ResourceSaver.save(build(), OUT)
	print("theme: %s -> %s" % [OUT, error_string(err)])
	quit(0 if err == OK else 1)


# 払いの向きに傾いた、角の立った箱。
static func _sb(bg: Color, edge: Color, w: int, skew: float = Kit.SKEW) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.set_border_width_all(w)
	s.skew = Vector2(skew, 0)
	s.anti_aliasing = true
	s.content_margin_left = 24
	s.content_margin_right = 24
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s


# 小さな絵(つまみとチェック)。圧縮しない生の画素で持つ(圧縮の形は Web だけで読めないことがある)。
# shape: "slant" 傾いた四角 / "diamond" ひし形の枠 / "diamond_on" 塗ったひし形
static func _icon(size: int, shape: String, color: Color) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := (size - 1) / 2.0
	for y in size:
		for x in size:
			var on := false
			match shape:
				"slant":
					var dx := (c - y) * Kit.SKEW
					on = x - dx >= size * 0.25 and x - dx <= size * 0.75
				"diamond":
					var d := absf(x - c) + absf(y - c)
					on = d <= c and d >= c - 2.5
				"diamond_on":
					var d2 := absf(x - c) + absf(y - c)
					on = d2 <= c and (d2 >= c - 2.5 or d2 <= c - 5.0)
			if on:
				img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)


static func build() -> Theme:
	var t := Theme.new()
	t.default_font = Kit.font(500)
	t.default_font_size = 24
	var ink := Kit.C_INK
	var sumi := Kit.C_SUMI
	var usu := Kit.C_USU
	var washi := Kit.C_WASHI
	var shu := Kit.C_SHU

	# ボタン: 傾いた札。選んでいる時(focus)は朱の縁と左の太い帯を普段の形の上に重ねる
	t.set_font("font", "Button", Kit.font(700))
	t.set_font_size("font_size", "Button", 30)
	t.set_stylebox("normal", "Button", _sb(sumi, usu, 2))
	t.set_stylebox("hover", "Button", _sb(sumi.lerp(washi, 0.06), Color(washi, 0.55), 2))
	var focus := _sb(Color(0, 0, 0, 0), shu, 3)
	focus.border_width_left = 12
	focus.expand_margin_left = 2
	focus.expand_margin_right = 2
	focus.expand_margin_top = 2
	focus.expand_margin_bottom = 2
	t.set_stylebox("focus", "Button", focus)
	t.set_stylebox("pressed", "Button", _sb(shu, shu, 2))
	t.set_stylebox("disabled", "Button", _sb(ink, Color(usu, 0.6), 2))
	for c: String in ["font_color", "font_hover_color", "font_focus_color"]:
		t.set_color(c, "Button", washi)
	t.set_color("font_pressed_color", "Button", ink)
	t.set_color("font_hover_pressed_color", "Button", ink)
	t.set_color("font_disabled_color", "Button", Color(Kit.C_NEZU, 0.6))
	t.set_constant("outline_size", "Button", 0)
	# 設定の選んでいる値: 和紙で塗って字は墨(色だけでなく塗りの反転で分かる)
	t.set_type_variation("OnButton", "Button")
	t.set_stylebox("normal", "OnButton", _sb(washi, washi, 2))
	t.set_stylebox("hover", "OnButton", _sb(washi, washi, 2))
	t.set_stylebox("pressed", "OnButton", _sb(washi.darkened(0.1), washi, 2))
	for c: String in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		t.set_color(c, "OnButton", ink)

	# 字・板
	t.set_color("font_color", "Label", washi)
	t.set_stylebox("panel", "Panel", _sb(sumi, usu, 2, 0.0))
	t.set_stylebox("panel", "PanelContainer", _sb(sumi, usu, 2, 0.0))

	# 入力欄(結果の共有する文字の枠)
	for type: String in ["TextEdit", "LineEdit"]:
		var n := _sb(Color(sumi, 0.7), usu, 2, 0.0)
		n.border_width_left = 4
		n.content_margin_left = 18
		n.content_margin_right = 18
		n.content_margin_top = 12
		var f := n.duplicate() as StyleBoxFlat
		f.border_color = Color(washi, 0.6)
		t.set_stylebox("normal", type, n)
		t.set_stylebox("read_only", type, n)
		t.set_stylebox("focus", type, f)
		t.set_font("font", type, Kit.font(500))
		t.set_font_size("font_size", type, 22)
		t.set_color("font_color", type, washi)
		t.set_color("font_readonly_color", type, washi)
		t.set_color("font_selected_color", type, ink)
		t.set_color("selection_color", type, Color(washi, 0.85))
		t.set_color("caret_color", type, washi)
		t.set_color("font_placeholder_color", type, Kit.C_NEZU)

	# 右クリックのメニュー・ツールチップ(今は出さないが、出た時に既定の見た目にしない)
	var pop := _sb(sumi, usu, 2, 0.0)
	pop.content_margin_left = 8
	pop.content_margin_right = 8
	t.set_stylebox("panel", "PopupMenu", pop)
	t.set_stylebox("hover", "PopupMenu", _sb(Color(washi, 0.14), Color(0, 0, 0, 0), 0, 0.0))
	t.set_font("font", "PopupMenu", Kit.font(500))
	t.set_font_size("font_size", "PopupMenu", 20)
	t.set_color("font_color", "PopupMenu", washi)
	t.set_color("font_hover_color", "PopupMenu", washi)
	t.set_color("font_disabled_color", "PopupMenu", Kit.C_NEZU)
	t.set_color("font_separator_color", "PopupMenu", Kit.C_NEZU)
	var line := StyleBoxLine.new()
	line.color = usu
	line.thickness = 2
	t.set_stylebox("separator", "PopupMenu", line)
	t.set_stylebox("panel", "TooltipPanel", _sb(sumi, usu, 2, 0.0))
	t.set_color("font_color", "TooltipLabel", washi)
	t.set_font_size("font_size", "TooltipLabel", 20)

	# スクロールバー: 細い墨の溝と薄墨のつまみ。触ると和紙
	for type: String in ["VScrollBar", "HScrollBar"]:
		var track := StyleBoxFlat.new()
		track.bg_color = Color(ink, 0.6)
		track.content_margin_left = 4
		track.content_margin_right = 4
		track.content_margin_top = 4
		track.content_margin_bottom = 4
		var grab := StyleBoxFlat.new()
		grab.bg_color = usu.lightened(0.15)
		var grab_hi := grab.duplicate() as StyleBoxFlat
		grab_hi.bg_color = Color(washi, 0.7)
		var grab_on := grab.duplicate() as StyleBoxFlat
		grab_on.bg_color = washi
		t.set_stylebox("scroll", type, track)
		t.set_stylebox("scroll_focus", type, track)
		t.set_stylebox("grabber", type, grab)
		t.set_stylebox("grabber_highlight", type, grab_hi)
		t.set_stylebox("grabber_pressed", type, grab_on)

	# つまみ: 薄墨の溝、和紙の傾いた札。選んでいると朱
	var rail := StyleBoxFlat.new()
	rail.bg_color = usu
	rail.content_margin_top = 3
	rail.content_margin_bottom = 3
	var rail_on := rail.duplicate() as StyleBoxFlat
	rail_on.bg_color = washi
	for type: String in ["HSlider", "VSlider"]:
		t.set_stylebox("slider", type, rail)
		t.set_stylebox("grabber_area", type, rail_on)
		t.set_stylebox("grabber_area_highlight", type, rail_on)
		t.set_icon("grabber", type, _icon(24, "slant", washi))
		t.set_icon("grabber_highlight", type, _icon(24, "slant", shu))
		t.set_icon("grabber_disabled", type, _icon(24, "slant", Kit.C_NEZU))

	# チェック: ひし形の枠。入るとひし形の中を塗る
	var off := _icon(24, "diamond", Kit.C_NEZU)
	var on := _icon(24, "diamond_on", washi)
	for type: String in ["CheckBox", "CheckButton"]:
		t.set_icon("unchecked", type, off)
		t.set_icon("checked", type, on)
		t.set_icon("unchecked_disabled", type, off)
		t.set_icon("checked_disabled", type, on)
		t.set_font("font", type, Kit.font(700))
		t.set_color("font_color", type, washi)
		t.set_color("font_hover_color", type, washi)
		t.set_color("font_pressed_color", type, washi)
		t.set_color("font_focus_color", type, washi)
		for st: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			t.set_stylebox(st, type, StyleBoxEmpty.new())
		t.set_stylebox("focus", type, _sb(Color(0, 0, 0, 0), shu, 3, 0.0))
	return t
