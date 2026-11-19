# 保存のテスト(仕様書 §9.9・AC-16・E-9・E-12・NFR-9)。テストでは user:// の別のファイルを使う。
extends "res://tests/suite.gd"

const Store := preload("res://save/save_store.gd")
const P := "user://test_save.json"


func _fresh(text: Variant = null) -> Store:
	if FileAccess.file_exists(P):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(P))
	if text != null:
		var f := FileAccess.open(P, FileAccess.WRITE)
		f.store_string(text)
		f.close()
	return Store.new(P)


func test_ac16_empty_broken_version() -> bool:
	var st := _fresh()
	eq(st.data, Store.defaults(), "空")
	ok(not st.load_failed, "空は失敗ではない")
	st = _fresh("{not json")
	eq(st.data, Store.defaults(), "壊れた JSON")
	ok(st.load_failed, "壊れた時は知らせる(E-9)")
	st = _fresh('{"version": 2, "practice_best": 100}')
	eq(st.data, Store.defaults(), "version が 2")
	ok(st.load_failed, "知らない version も知らせる")
	eq(Store.default_settings(), {"volume": 75, "shake": true, "reduce_flash": false}, "既定値は音量 75・揺れ 入・点滅を弱める 切")
	return true


func test_practice_best() -> bool:
	var st := _fresh()
	ok(not st.has_any_record(), "初めは記録なし")
	var r1 := st.record(1, 322, 8000)
	ok(r1["new_best"] and r1["prev_best"] == null, "初めての最高")
	var r2 := st.record(1, 322, 7000)
	ok(not r2["new_best"] and r2["prev_best"] == 8000, "低い点は最高にしない")
	eq(Store.new(P).practice_best(), 8000, "読み直しても残る")
	ok(Store.new(P).has_any_record(), "記録あり")
	return true


func test_daily_first_and_best() -> bool:
	var st := _fresh()
	var a := st.record(0, 322, 12400)
	ok(a["first_today"], "1 回目")
	var b := st.record(0, 322, 15100)
	ok(not b["first_today"] and b["new_best"] and b["prev_best"] == 12400, "2 回目で最高")
	var d := Store.new(P).daily(322)
	eq([d["first"], d["best"]], [12400, 15100], "1 回目と最高")
	var c := st.record(0, 323, 5000)
	ok(c["first_today"], "日付が変われば作り直す")
	eq(Store.new(P).daily(322)["first"], null, "前の日の記録は消える")
	return true


func test_e12_old_day_does_not_overwrite() -> bool:
	var st := _fresh()
	st.record(0, 323, 5000)
	var r := st.record(0, 322, 9999)
	ok(not r["first_today"] and not r["new_best"], "古い日の回は記録しない")
	eq(Store.new(P).daily(323)["best"], 5000, "新しい日のまま")
	return true


func test_settings_persist_and_bad_values() -> bool:
	var st := _fresh()
	st.set_setting("volume", 25)
	st.set_setting("shake", false)
	eq(Store.new(P).settings(), {"volume": 25, "shake": false, "reduce_flash": false}, "設定が残る")
	st = _fresh('{"version": 1, "settings": {"volume": 33, "shake": "yes"}, "practice_best": "x", "daily": {"day": 3, "first": 10}}')
	eq(st.settings(), Store.default_settings(), "おかしな値は既定値")
	eq(st.practice_best(), null, "おかしな記録は無し")
	eq(st.daily(3), {"day": 3, "first": 10, "best": null}, "読める所は読む")
	ok(not st.load_failed, "形は読めた")
	return true


func test_merge_keeps_other_tab_record() -> bool:
	var a := _fresh()
	var b := Store.new(P)
	a.record(1, 322, 9000)
	b.record(1, 322, 5000)
	eq(Store.new(P).practice_best(), 9000, "別のタブの高い記録を消さない")
	return true


func test_spec_example_round_trip() -> bool:
	var st := _fresh('{"version": 1, "practice_best": 18200, "daily": {"day": 315, "first": 12400, "best": 15100}, "settings": {"volume": 75, "shake": true, "reduce_flash": false}}')
	eq(st.practice_best(), 18200, "§9.9 の例を読める")
	eq(st.daily(315)["best"], 15100, "今日の最高")
	ok(st.save_data(), "書ける")
	ok(FileAccess.get_file_as_string(P).length() < 2048, "2 KB 以下")
	return true
