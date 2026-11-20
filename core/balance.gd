# 調整値(仕様書 §9.8・INV-8)。秒で書いた値は tick(1/120 秒)の整数で持つ。
# 演出の時間・音量の段・日替わりの種もここに置く。ほかのファイルに数値の調整値を書かない。
# DASH_DISTANCE は D-2 の案(240・320・400)から 320 を仮に選んだ(人が試して決め直す)。
extends RefCounted

const TICK_HZ := 120
const MAX_STEPS_PER_FRAME := 8

# 場(§9.1)
const SCREEN_W := 720
const SCREEN_H := 1280
const FIELD_X0 := 0.0
const FIELD_X1 := 720.0
const FIELD_Y0 := 200.0
const FIELD_Y1 := 1160.0
const PLAYER_START_X := 360.0
const PLAYER_START_Y := 900.0
const PLAYER_RADIUS := 14.0

# 突進(§9.4)
const MIN_DRAG := 24
const DASH_DISTANCE := 320.0
const DASH_TICKS := 12
const BLADE_HALF_WIDTH := 14.0
const CHARGE_MAX := 3
const CHARGE_REGEN_TICKS := 120
const FREEZE_BASE := 4
const FREEZE_PER := 1
const FREEZE_N_CAP := 4

# 体力・時間・点(§9.7)
const HP_MAX := 3
const HURT_INVINCIBLE_TICKS := 96
const ROUND_TICKS := 7200
const CHAIN_KEEP_TICKS := 360
const CHAIN_CAP := 20
const POINT_UNIT := 10
const MULT_BASE := 10  # 倍率 = (MULT_BASE + つなぎ) ÷ 10

# 並び(§9.6)
const SPAWN_MARK_TICKS := 60
const SPAWN_MIN_DIST := 120.0
const SPAWN_WHEN_LEFT := 2
const SPAWN_FORCE_TICKS := 720
const ENEMY_CAP := 40
const BULLET_CAP := 30
const ORDER_LEN := 60
const ORDER_LOOP_FROM := 12  # 60 番目の次は 13 番目(0 から数えて 12)
const FIELD_MARGIN := 40.0  # 並びの member を置ける、端からの距離
const LINE_MIN_CUTS := 3  # 1 本の線で斬れるはずの数
const TEACH_WAIT_MAX_TICKS := 600  # 教える並びを自機が離れるまで待つ上限(5 秒。仮の値)。超えたらほかの並びと同じ扱いで出す

# 敵と弾(§9.5)
const STILL_RADIUS := 18.0
const CHASER_RADIUS := 16.0
const SHOOTER_RADIUS := 20.0
const BULLET_RADIUS := 6.0
const CHASER_SPEED := 90.0  # px/秒
const SHOOTER_PERIOD_TICKS := 288
const SHOOTER_WARN_TICKS := 72
const BULLET_SPEED := 240.0  # px/秒

# 日替わりの種(§9.11)
const DAY_SEED_MUL := 2654435761
const EPOCH_YEAR := 2026

# 画面と演出(画面設計書 §3・§9、仕様書 §9.12)。ms
const OVER_MS := 400
const COUNT_MS := 600
const RETRY_LOCK_MS := 300
const TRAIL_MS := 120
const SHARD_MS := 300
const SHARDS_PER_ENEMY := 6
const SHARD_SPEED := 460.0  # px/秒(v0.2.0 で 260 から。破片が輪の内に留まって見えなかった)
const POPUP_MS := 600
const POPUP_RISE := 40.0
const POPUP_BIG := 1.6
const BIG_CUT := 3  # これ以上で揺れと大きい数字
const SHAKE_CUT_PX := 6.0
const SHAKE_CUT_MS := 120
const SHAKE_HURT_PX := 4.0
const SHAKE_HURT_MS := 100
const EDGE_MS := 150
const EDGE_ALPHA := 0.6
const REDUCED_FLASH_ALPHA := 0.2
const WHIFF_MS := 150
const NO_CHARGE_MS := 200
const CLOCK_BIG_SEC := 10  # 残りがこの秒数から字を大きく
const CLOCK_BIG := 1.3
const SEMITONE_CAP := 12
# 磨きで足した演出(v0.2.0。仕様書 §14「磨きで足した物」)。ms
const CUT_GROW_MS := 60  # 斬った線が伸びきるまで
const RING_MS := 220  # 割れた所に広がる輪
const RING_GROW := 26.0  # 輪が広がる幅(px)。3 体以上は RING_GROW_BIG
const RING_GROW_BIG := 46.0
const FLASH_MS := 120  # 3 体以上の時、場が白く光る
const FLASH_ALPHA := 0.22
const FLASH_ALPHA_REDUCED := 0.08  # 点滅を弱める時(画面全体の色の変化は 20% 以下)
const POP_IN_MS := 90  # 点の表示が大きく出て縮む
const POP_IN_SCALE := 0.35
const POPUP_GAP := 46.0  # 点の表示どうしを上へずらす幅
const BUMP_MS := 160  # 点・つなぎの字が跳ねる
const BUMP_SCALE := 0.18
const CHAIN_LOST_MS := 600  # 切れたつなぎを赤く残す
const REFILL_MS := 280  # 斬って戻った回数の四角が光る
const HP_LOST_MS := 320  # 消えた体力の丸が弾ける
const GUIDE_MS := 900  # 最初の突進の前に出す矢印の 1 周

# 設定(FR-23)
const VOLUMES := [0, 25, 50, 75, 100]
const DEFAULT_VOLUME := 75
