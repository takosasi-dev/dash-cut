# 画面に出す文言(画面設計書 §7・INV-8)。ほかのファイルに文言を書かない。
# 文言を足したら tools/subset_font.py を回し直す(同梱の字体はここの文字に絞ってある)。
extends RefCounted

const NAME := "DashCut"
const VERSION := "v0.1.2"
const URL := "https://takosasi-dev.github.io/dash-cut/"

# S1 タイトル
const TAGLINE := "突進の線で、まとめて斬る"
const B_DAILY := "今日の並び"
const B_PRACTICE := "練習(毎回ちがう並び)"
const B_SETTINGS := "設定"
const REC_FIRST := "1回目 %s点"
const REC_TODAY_BEST := "今日の最高 %s点"
const REC_BEST := "最高 %s点"
const REC_NONE := "まだ遊んでいない"
const LOAD_FAILED := "保存を読めなかったので、記録を初めからにした"

# S2 プレイ
const HINT := "払うと突進"
const HUD_TIME := "残り %s"
const HUD_HP := "体力"
const HUD_POINTS := "%s点"
const HUD_CHAIN := "つなぎ %d  x%s"
const HUD_CHARGE := "突進"
const POP := "%d体 x%s +%s"
const PAUSE_MARK := "II"

# S3 結果
const REASON_TIME := "時間切れ"
const REASON_HP := "体力切れ"
const RES_POINTS := "%s点"
const RES_NEW_BEST := "最高 +%s(新しい記録)"
const RES_TO_BEST := "最高まで −%s"
const RES_CUTS := "斬った数 %d"
const RES_MAX_N := "最大同時 %d"
const RES_MAX_CHAIN := "最大つなぎ %d"
const B_RETRY := "もう1回"
const B_COPY := "コピー"
const B_TITLE := "タイトルへ"
const COPIED := "コピーを試した。貼れない時は枠から写す"
const SAVE_FAILED := "このブラウザでは記録を残せない"

# 共有する文字(§9.10)
const SHARE_HEAD := "%s %s(%s)"
const SHARE_BODY := "%s点 / 斬った数 %d / 最大同時 %d / 最大つなぎ %d"
const LABEL_DAILY_FIRST := "今日の並び・1回目"
const LABEL_DAILY := "今日の並び"
const LABEL_PRACTICE := "練習"

# S4 設定
const SETTINGS := "設定"
const SET_VOLUME := "音量"
const SET_SHAKE := "画面の揺れ"
const SET_FLASH := "点滅を弱める"
const ON := "入"
const OFF := "切"
const B_BACK := "戻る"

# S5 一時停止
const PAUSE := "一時停止"
const B_RESUME := "続ける"
const B_RESTART := "やり直す"
