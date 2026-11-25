# App Store 提出の準備

> 名前・説明・キーワードなどの正本は `docs/app-store.json`（`.github/workflows/asc.yml` の metadata が App Store Connect に API で入れる）。ここは審査の危険と、本人がすることの記録。

| 項目 | 内容 |
|---|---|
| Bundle ID | com.enludus.daily.018 |
| アプリ名 | つかんで荷造り：引っ越しクレーン / Claw & Pack: Moving Day（表示名 つかんで荷造り / Claw & Pack） |
| サポート URL | https://github.com/enludus-daily/app-20261125-claw-pack/issues |
| プライバシーポリシー URL | https://github.com/enludus-daily/app-20261125-claw-pack/blob/main/PRIVACY.md |
| 年齢区分の答え | すべて「なし」の見込み（暴力・ギャンブル・Web 閲覧・生成 AI・ユーザー生成コンテンツなし。物が割れる表現は皿などのかけらだけ）。API では入れないので本人が入力 |
| 輸出コンプライアンス | `ITSAppUsesNonExemptEncryption = NO`（標準の暗号だけ。ビルドの答えは asc が NO で入れる） |

## 審査の危険

- 4.3(b) の種類に当たらない理由：懐中電灯・効果音・占いなどではなく、物理の箱詰めパズル（40 種の物・60 部屋・毎日の部屋）
- 既存のアプリとの意味のある違い：クレーンでつかむ × 物理で箱に詰める × 割れ物、の組み合わせ（Unpacking は荷ほどき、Pack It Up!! は家具を滑らせる、Claw Machine はクレーンそのもの）
- 長く使える価値（4.2）：毎日の部屋（日付で同じ部屋）、続けた日数、浮いた額の積み上げ、荷物の図鑑
- 他社の名前・商標・見た目を使っていないか：使っていない。名前は「つかんで荷造り / Claw & Pack」。クレーンゲームの筐体の見た目は真似せず、天井のレールと黄色いつめにした
- Apple Intelligence：使わない

## 収益の道筋（本人が選ぶ）

- 買い切りの Pro ¥480（StoreKit 2、`com.enludus.daily.018.pro`）。広告なし
- 理由：README の「課金」（比べた 4 本の表と勝算の表）

## App プライバシーの答え（下書き。申告は本人。公開 API がない）

- データの収集：**なし**（根拠：通信しない、解析・広告 SDK なし、保存は端末の UserDefaults だけ）
- トラッキング：なし
- Privacy manifest：`App/Resources/PrivacyInfo.xcprivacy`（UserDefaults: CA92.1）

## スクリーンショット

CI の artifact `screenshots`（iPhone Duo のシミュレータ）。足りない画面は本人と相談。

## 本人がすること

- [ ] App プライバシーを申告する（API がない）
- [ ] 年齢区分を答える
- [ ] TestFlight で動作を確かめる（内部テストのグループ `daily-internal` に自動で配信される）
- [ ] スクリーンショットを確かめる
- [ ] 審査に提出する
