"""同梱する字体を、画面に出す文字だけに絞る。

- Noto Sans JP(SlingArc・ParryDuel と同じ): core/strings.gd の文字列リテラルの全文字と ASCII と画面で使う記号
- しっぽり明朝 B1 ExtraBold(v0.3.0 の題字と数字): ASCII と − と、strings.gd の SEAL・STAMP_BEST の字だけ

原本は google/fonts の固定コミットから取り、sha256 を照らす。tools/font_src/ に置き、git には入れない。文言を足したら回し直す。

    pip install fonttools
    python tools/subset_font.py
"""

import hashlib
import re
import sys
import urllib.request
from pathlib import Path

from fontTools import subset
from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parents[1]
BASE = "https://raw.githubusercontent.com/google/fonts/295d98a7a0c17c68f1341eaeea354e7960ea70d3/ofl/"
FONTS = [
    # (原本の URL, sha256, 原本の置き場所, 書き出す先, 文字を選ぶ関数の名前)
    (BASE + "notosansjp/NotoSansJP%5Bwght%5D.ttf", "c2f3b4d463500a2ddcd3849cded1fceeb9fd6d1c32e6cbecd568453ba50fc68f",
     "NotoSansJP.ttf", "NotoSansJP-Subset.ttf", "sans"),
    (BASE + "shipporiminchob1/ShipporiMinchoB1-ExtraBold.ttf", "bee99a242f32128e8d6a4acff2b3f1742cd42ea90748758e6e10456871887e76",
     "ShipporiMinchoB1-ExtraBold.ttf", "ShipporiMinchoB1-Subset.ttf", "display"),
]
ASCII = "".join(chr(c) for c in range(0x20, 0x7F))
EXTRA = "−"  # 最高まで −800 の負の記号
DISPLAY_CONSTS = ["SEAL", "STAMP_BEST"]


def strings_chars() -> set[str]:
    text = (ROOT / "core" / "strings.gd").read_text(encoding="utf-8")
    return set("".join(re.findall(r'"((?:[^"\\\n]|\\.)*)"', text)))


def chars_for(kind: str) -> set[str]:
    if kind == "sans":
        return set(ASCII) | set(EXTRA) | strings_chars()
    text = (ROOT / "core" / "strings.gd").read_text(encoding="utf-8")
    out = set(ASCII) | set(EXTRA)
    for name in DISPLAY_CONSTS:
        out |= set(re.search(r'const %s := "([^"]*)"' % name, text).group(1))
    return out


def make(url: str, sha: str, src_name: str, out_name: str, kind: str) -> None:
    src = ROOT / "tools" / "font_src" / src_name
    out = ROOT / "assets" / "fonts" / out_name
    chars = chars_for(kind)
    if not src.exists():
        src.parent.mkdir(parents=True, exist_ok=True)
        print(f"取得: {url}")
        urllib.request.urlretrieve(url, src)
    digest = hashlib.sha256(src.read_bytes()).hexdigest()
    if digest != sha:
        sys.exit(f"{src} の sha256 が違う: {digest}(消して取り直す)")
    font = TTFont(src)
    options = subset.Options()
    # 明朝は置き換えの表(全角・異体字など)を入れると使わない字形が 4 倍に増えるので、表を持たない
    options.layout_features = ["*"] if kind == "sans" else []
    subsetter = subset.Subsetter(options)
    subsetter.populate(unicodes=[ord(c) for c in chars])
    subsetter.subset(font)
    out.parent.mkdir(parents=True, exist_ok=True)
    font.save(out)
    missing = sorted(c for c in chars if ord(c) not in font.getBestCmap())
    print(f"{out.name}: {src.stat().st_size:,} -> {out.stat().st_size:,} バイト、{len(chars)} 文字")
    if missing:
        print(f"  原本に無い文字: {''.join(missing)}")


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    for f in FONTS:
        make(*f)


if __name__ == "__main__":
    main()
