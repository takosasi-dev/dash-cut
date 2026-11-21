# 第三者の素材

同梱している第三者の素材は、次の字体 2 つだけです。効果音は `tools/gen_sfx.py` で合成した自作の物です。

## Noto Sans JP(画面の字)

- ファイル: `assets/fonts/NotoSansJP-Subset.ttf`(原本を、画面に出す文字だけに絞った物。`tools/subset_font.py` で作る)
- 原本: https://github.com/google/fonts/tree/main/ofl/notosansjp の `NotoSansJP[wght].ttf`(コミット `295d98a7a0c17c68f1341eaeea354e7960ea70d3`)
- 原本の SHA-256: `c2f3b4d463500a2ddcd3849cded1fceeb9fd6d1c32e6cbecd568453ba50fc68f`
- ライセンス: SIL Open Font License, Version 1.1。原文は [`assets/fonts/OFL_NotoSansJP.txt`](assets/fonts/OFL_NotoSansJP.txt)(入手元の `OFL.txt` をそのまま置いた)
- 著作権表示: Copyright 2014-2021 Adobe (http://www.adobe.com/), with Reserved Font Name 'Source'

## しっぽり明朝 B1(題字と数字、v0.3.0 から)

- ファイル: `assets/fonts/ShipporiMinchoB1-Subset.ttf`(原本を、ASCII と「斬」「新記録」と − だけに絞った物。`tools/subset_font.py` で作る)
- 原本: https://github.com/google/fonts/tree/main/ofl/shipporiminchob1 の `ShipporiMinchoB1-ExtraBold.ttf`(コミット `295d98a7a0c17c68f1341eaeea354e7960ea70d3`)
- 原本の SHA-256: `bee99a242f32128e8d6a4acff2b3f1742cd42ea90748758e6e10456871887e76`
- ライセンス: SIL Open Font License, Version 1.1。原文は [`assets/fonts/OFL_ShipporiMinchoB1.txt`](assets/fonts/OFL_ShipporiMinchoB1.txt)(入手元の `OFL.txt` をそのまま置いた)
- 著作権表示: Copyright 2021 The Shippori Mincho Project Authors (https://github.com/fontdasu/ShipporiMincho)

## 効果音

- ファイル: `assets/sfx/*.wav`(10 個)
- 出どころ: `tools/gen_sfx.py` で合成した自作の音。第三者の素材は使っていない。ライセンスはリポジトリと同じ MIT。
