"""Godot をヘッドレスで回す入口(取り込み・テスト・書き出し・スクリプト実行)。窓を出さず、音も出さない。
Godot の場所は環境変数 GODOT(無ければ PATH の godot)。user:// は build/appdata に分ける(環境変数 DC_APPDATA で変えられる)。

    python tools/gd.py import
    python tools/gd.py test [test_core ...]
    python tools/gd.py export
    python tools/gd.py smoke [frames]
    python tools/gd.py perf
    python tools/gd.py run res://tools/<スクリプト>.gd [引数 ...]
"""

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GODOT = os.environ.get("GODOT", "godot")


def godot(args: list[str], timeout: int = 600, need: bytes = b"") -> int:
    env = dict(os.environ)
    # user:// を手元の本物と分ける(既定は build/appdata)
    appdata = Path(env.get("DC_APPDATA") or ROOT / "build" / "appdata")
    appdata.mkdir(parents=True, exist_ok=True)
    env["APPDATA"] = str(appdata)
    flags = getattr(subprocess, "CREATE_NO_WINDOW", 0)
    try:
        done = subprocess.run([GODOT, "--headless", "--path", str(ROOT), *args], env=env, timeout=timeout,
                              stdout=subprocess.PIPE, stderr=subprocess.STDOUT, creationflags=flags)
    except subprocess.TimeoutExpired as e:
        sys.stdout.buffer.write(e.stdout or b"")
        print(f"\n{timeout} 秒で終わらなかった(スクリプトの構文エラーで本体が立ち上がった時に起きる)")
        return 124
    sys.stdout.buffer.write(done.stdout)
    sys.stdout.flush()
    # テストが呼んだ先のスクリプトエラーは、ランナーからは見えない(その関数が黙って止まる)。出力で拾って失敗にする
    if b"SCRIPT ERROR" in done.stdout and done.returncode == 0:
        print("出力に SCRIPT ERROR がある")
        return 1
    if need and need not in done.stdout:
        print(f"出力に {need.decode()} が無い(途中で止まった)")
        return 1
    return done.returncode


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    cmd, rest = sys.argv[1], sys.argv[2:]
    if cmd == "import":
        return godot(["--import"])
    if cmd == "test":
        return godot(["--script", "res://tests/run_tests.gd", "--", *rest], timeout=900)
    if cmd == "export":
        (ROOT / "build" / "web").mkdir(parents=True, exist_ok=True)
        return godot(["--export-release", "Web", "build/web/index.html"])
    if cmd == "smoke":  # 本体を窓なしで動かし、タイトル → プレイ → 結果 → もう1回 を自動で通す。SMOKE_OK が出なければ失敗
        frames = rest[0] if rest else "300000"  # 窓なしは 1 秒に数千フレーム回るので、ms で待つ所(400・300 ms)に多めに要る
        return godot(["--fixed-fps", "60", "--quit-after", frames, "--", "--auto", *rest[1:]], need=b"SMOKE_OK")
    if cmd == "perf":  # 敵 40・弾 30・破片 240 で 3600 フレーム(NFR-1・R-4。窓なしなので描く時間は入らない)
        return godot(["--fixed-fps", "60", "--script", "res://tools/perf.gd"], need=b"PERF ")
    if cmd == "run" and rest:
        return godot(["--script", rest[0], "--", *rest[1:]])
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main())
