# 画面の下のキーの手がかり(v0.3.0、画面設計書 §11)。items は [[キーの並び, 言葉], …]。キーは "Enter" などの字か、"up" "down" などの矢印。
# 右寄せ(center が真なら真ん中)で 1 行に並べる。字は Noto の 22(弱い字の色)。
extends Control

const Kit := preload("res://ui/kit.gd")

const KEY_H := 40.0
const GAP := 8.0
const ITEM_GAP := 28.0
const FONT_SIZE := 22

var items: Array = []
var center := false


func _init(p_items: Array = []) -> void:
	items = p_items
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _width() -> float:
	var f := Kit.font(500)
	var w := 0.0
	for it: Array in items:
		for k: String in it[0]:
			w += _key_w(k) + GAP * 0.5
		w += GAP + f.get_string_size(it[1], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x + ITEM_GAP
	return w - ITEM_GAP


func _key_w(k: String) -> float:
	if k in ["up", "down", "left", "right"]:
		return KEY_H
	return maxf(KEY_H, Kit.font(700).get_string_size(k, HORIZONTAL_ALIGNMENT_LEFT, -1, int(KEY_H * 0.5)).x + KEY_H * 0.6)


func _draw() -> void:
	var f := Kit.font(500)
	var x := (size.x - _width()) / 2.0 if center else size.x - _width()
	var y := (size.y - KEY_H) / 2.0
	for it: Array in items:
		for k: String in it[0]:
			x += Kit.draw_key(self, Vector2(x, y), k, KEY_H) + GAP * 0.5
		x += GAP
		draw_string(f, Vector2(x, y + KEY_H / 2.0 + FONT_SIZE * 0.36), it[1], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Kit.C_DIM)
		x += f.get_string_size(it[1], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x + ITEM_GAP
