# 人に見せる結果の文字(仕様書 §9.10)。3 行。
extends RefCounted

const S := preload("res://core/strings.gd")
const Score := preload("res://core/score.gd")


# mode: 0 = 今日の並び、1 = 練習。first_today は今日の並びの 1 回目か。date は遊び始めた日("2026-11-12")。
static func make(date: String, mode: int, first_today: bool, result: Dictionary) -> String:
	var label: String = S.LABEL_PRACTICE
	if mode == 0:
		label = S.LABEL_DAILY_FIRST if first_today else S.LABEL_DAILY
	var body := S.SHARE_BODY % [Score.comma(int(result["points"])), int(result["cuts"]), int(result["max_n"]), int(result["max_chain"])]
	return "\n".join([S.SHARE_HEAD % [S.NAME, date, label], body, S.URL])
