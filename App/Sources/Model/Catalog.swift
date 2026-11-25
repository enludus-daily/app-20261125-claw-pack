import Foundation

/// 当たり判定の形（SpriteKit の物理と、絵の輪郭の両方に使う）
enum ItemShape: String, Codable, Sendable {
    /// 長方形（本・箱・クッション）
    case box
    /// 円（ボール・時計・地球儀）
    case round
    /// 薄い円盤・板（皿・フライパン・ノートパソコン）
    case flat
    /// 台形（植木鉢・どんぶり。下がすぼまる）
    case pot
    /// 角の丸い縦長（びん・花びん・ランプ）
    case tall
}

/// 部屋の物の種類。大きさは箱の中の幅 200 × 高さ 150 に対する点の数（SpriteKit の座標と同じ）
enum ItemKind: String, CaseIterable, Codable, Sendable, Identifiable {
    case book, dictionary, comics, plate, bowl, mug, glass, vase, potPlant, kettle
    case pan, pot, riceCooker, jar, cushion, pillow, blanket, teddy, photoFrame, trophy
    case lamp, clock, ball, shoeBox, boots, blocks, toyCar, gameBox, records, radio
    case laptop, dumbbell, toolbox, globe, hatBox, ukulele, boardGame, piggyBank, teapot, snowGlobe

    var id: String { rawValue }

    struct Spec: Sendable {
        var w: Double
        var h: Double
        var shape: ItemShape
        /// 重さ 1〜4（3 以上は「重い物」。割れ物の上に落ちると割る）
        var weight: Int
        var fragile = false
        /// つかみやすさ（真ん中をつかんだときに 1 回でつかめる見込み）
        var grip: Double
        /// たいせつな物（部屋に 1 つ。最後に一番上に入れるとボーナス）
        var keepsake = false
        /// 色（本体・差し色）
        var body: UInt32
        var accent: UInt32
    }

    var spec: Spec {
        switch self {
        case .book: Spec(w: 96, h: 27, shape: .box, weight: 2, grip: 0.92, body: 0x3E7CB1, accent: 0xF2E8D5)
        case .dictionary: Spec(w: 87, h: 45, shape: .box, weight: 3, grip: 0.9, body: 0x8C2F39, accent: 0xE9C46A)
        case .comics: Spec(w: 69, h: 51, shape: .box, weight: 2, grip: 0.9, body: 0xF4A259, accent: 0x5B8E7D)
        case .plate: Spec(w: 93, h: 15, shape: .flat, weight: 1, fragile: true, grip: 0.82, body: 0xFFFFFF, accent: 0x6CA6C1)
        case .bowl: Spec(w: 72, h: 36, shape: .pot, weight: 1, fragile: true, grip: 0.84, body: 0xF7F3EA, accent: 0xC0504D)
        case .mug: Spec(w: 45, h: 45, shape: .box, weight: 1, fragile: true, grip: 0.88, body: 0xF2C14E, accent: 0xFFFFFF)
        case .glass: Spec(w: 33, h: 51, shape: .tall, weight: 1, fragile: true, grip: 0.8, body: 0xBFE3EE, accent: 0xFFFFFF)
        case .vase: Spec(w: 39, h: 78, shape: .tall, weight: 2, fragile: true, grip: 0.82, body: 0x4F9D9A, accent: 0xF6D8AE)
        case .potPlant: Spec(w: 66, h: 72, shape: .pot, weight: 2, fragile: true, grip: 0.86, body: 0xC8693F, accent: 0x5FA05A)
        case .kettle: Spec(w: 75, h: 63, shape: .round, weight: 2, grip: 0.86, body: 0xE0E4E6, accent: 0x2F3A40)
        case .pan: Spec(w: 126, h: 24, shape: .flat, weight: 3, grip: 0.9, body: 0x2F3A40, accent: 0xA0522D)
        case .pot: Spec(w: 84, h: 54, shape: .box, weight: 3, grip: 0.88, body: 0xD9534F, accent: 0x2F3A40)
        case .riceCooker: Spec(w: 78, h: 66, shape: .box, weight: 3, grip: 0.88, body: 0xF5F5F0, accent: 0x7A8B99)
        case .jar: Spec(w: 42, h: 60, shape: .tall, weight: 1, fragile: true, grip: 0.84, body: 0xD7EBD6, accent: 0xE07A5F)
        case .cushion: Spec(w: 108, h: 45, shape: .box, weight: 1, grip: 0.95, body: 0xE9A3B4, accent: 0xFFF3E0)
        case .pillow: Spec(w: 120, h: 42, shape: .box, weight: 1, grip: 0.95, body: 0xFFFFFF, accent: 0x9DB4C0)
        case .blanket: Spec(w: 135, h: 45, shape: .box, weight: 2, grip: 0.95, body: 0x7FB77E, accent: 0xF2E8D5)
        case .teddy: Spec(w: 66, h: 75, shape: .tall, weight: 1, grip: 0.93, keepsake: true, body: 0xB07A4F, accent: 0xF2D0A9)
        case .photoFrame: Spec(w: 60, h: 75, shape: .box, weight: 1, grip: 0.88, keepsake: true, body: 0xC9A66B, accent: 0x8FC1E3)
        case .trophy: Spec(w: 51, h: 78, shape: .tall, weight: 2, grip: 0.84, keepsake: true, body: 0xE9B949, accent: 0x6B4F2A)
        case .lamp: Spec(w: 51, h: 99, shape: .tall, weight: 2, grip: 0.82, body: 0xF6E27F, accent: 0x5C6B73)
        case .clock: Spec(w: 63, h: 63, shape: .round, weight: 2, grip: 0.8, body: 0x2A9D8F, accent: 0xFFFFFF)
        case .ball: Spec(w: 51, h: 51, shape: .round, weight: 1, grip: 0.72, body: 0xF28F3B, accent: 0xFFFFFF)
        case .shoeBox: Spec(w: 99, h: 45, shape: .box, weight: 1, grip: 0.92, body: 0xF1E3C8, accent: 0xD1495B)
        case .boots: Spec(w: 60, h: 69, shape: .box, weight: 2, grip: 0.86, body: 0x8D6346, accent: 0x3B2F2F)
        case .blocks: Spec(w: 45, h: 45, shape: .box, weight: 1, grip: 0.9, body: 0xEF476F, accent: 0x118AB2)
        case .toyCar: Spec(w: 78, h: 36, shape: .box, weight: 2, grip: 0.86, body: 0x06A77D, accent: 0x2F3A40)
        case .gameBox: Spec(w: 90, h: 57, shape: .box, weight: 1, grip: 0.92, body: 0x5E60CE, accent: 0xFFD166)
        case .records: Spec(w: 105, h: 75, shape: .box, weight: 4, grip: 0.86, body: 0xA47148, accent: 0x1D1D1D)
        case .radio: Spec(w: 90, h: 54, shape: .box, weight: 3, grip: 0.88, body: 0xE76F51, accent: 0xF4EBD0)
        case .laptop: Spec(w: 120, h: 15, shape: .flat, weight: 2, fragile: true, grip: 0.84, body: 0xB8C0C8, accent: 0x5C6B73)
        case .dumbbell: Spec(w: 96, h: 33, shape: .box, weight: 4, grip: 0.84, body: 0x3D405B, accent: 0x9AA0A6)
        case .toolbox: Spec(w: 105, h: 51, shape: .box, weight: 4, grip: 0.9, body: 0xE63946, accent: 0xF1FAEE)
        case .globe: Spec(w: 66, h: 72, shape: .round, weight: 2, grip: 0.76, body: 0x4EA8DE, accent: 0x80B918)
        case .hatBox: Spec(w: 75, h: 51, shape: .box, weight: 1, grip: 0.9, body: 0xF7CAD0, accent: 0x6D597A)
        case .ukulele: Spec(w: 45, h: 105, shape: .tall, weight: 1, grip: 0.86, body: 0xDDA15E, accent: 0x6B4226)
        case .boardGame: Spec(w: 114, h: 21, shape: .box, weight: 1, grip: 0.9, body: 0x2A9D8F, accent: 0xF4A261)
        case .piggyBank: Spec(w: 60, h: 51, shape: .round, weight: 2, fragile: true, grip: 0.8, body: 0xF4ACB7, accent: 0x9D8189)
        case .teapot: Spec(w: 69, h: 54, shape: .round, weight: 2, fragile: true, grip: 0.82, body: 0x9BC1BC, accent: 0x3E5C76)
        case .snowGlobe: Spec(w: 51, h: 60, shape: .round, weight: 2, fragile: true, grip: 0.8, keepsake: true, body: 0xCDEBF6, accent: 0x7B4B2A)
        }
    }

    var name: String {
        switch self {
        case .book: tr("文庫本", "Paperback")
        case .dictionary: tr("辞書", "Dictionary")
        case .comics: tr("まんがの束", "Comic stack")
        case .plate: tr("お皿", "Plate")
        case .bowl: tr("どんぶり", "Bowl")
        case .mug: tr("マグカップ", "Mug")
        case .glass: tr("グラス", "Glass")
        case .vase: tr("花びん", "Vase")
        case .potPlant: tr("植木鉢", "Potted plant")
        case .kettle: tr("やかん", "Kettle")
        case .pan: tr("フライパン", "Frying pan")
        case .pot: tr("両手なべ", "Stockpot")
        case .riceCooker: tr("炊飯器", "Rice cooker")
        case .jar: tr("梅干しのびん", "Pickle jar")
        case .cushion: tr("クッション", "Cushion")
        case .pillow: tr("まくら", "Pillow")
        case .blanket: tr("たたんだ毛布", "Folded blanket")
        case .teddy: tr("くまのぬいぐるみ", "Teddy bear")
        case .photoFrame: tr("写真立て", "Photo frame")
        case .trophy: tr("トロフィー", "Trophy")
        case .lamp: tr("スタンドライト", "Desk lamp")
        case .clock: tr("置き時計", "Desk clock")
        case .ball: tr("サッカーボール", "Football")
        case .shoeBox: tr("靴の箱", "Shoe box")
        case .boots: tr("長ぐつ", "Rain boots")
        case .blocks: tr("積み木", "Toy blocks")
        case .toyCar: tr("ミニカー", "Toy car")
        case .gameBox: tr("ゲーム機の箱", "Game console box")
        case .records: tr("レコードの木箱", "Record crate")
        case .radio: tr("ラジオ", "Radio")
        case .laptop: tr("ノートパソコン", "Laptop")
        case .dumbbell: tr("ダンベル", "Dumbbell")
        case .toolbox: tr("工具箱", "Toolbox")
        case .globe: tr("地球儀", "Globe")
        case .hatBox: tr("帽子の箱", "Hat box")
        case .ukulele: tr("ウクレレ", "Ukulele")
        case .boardGame: tr("ボードゲーム", "Board game")
        case .piggyBank: tr("ぶたの貯金箱", "Piggy bank")
        case .teapot: tr("ティーポット", "Teapot")
        case .snowGlobe: tr("スノードーム", "Snow globe")
        }
    }

    /// 荷物の図鑑の一言（持ち主の思い出）
    var memory: String {
        switch self {
        case .book: tr("しおりが3冊ぶん挟まったまま。", "Three bookmarks, none of them finished.")
        case .dictionary: tr("押し花が1枚出てきた。", "A pressed flower fell out.")
        case .comics: tr("最終巻だけ2冊ある。", "Two copies of the last volume.")
        case .plate: tr("祖母の家から来た、青い縁の皿。", "Blue-rimmed, from grandma's kitchen.")
        case .bowl: tr("ラーメンの日はこれ一択。", "The only bowl for ramen night.")
        case .mug: tr("取っ手が少し欠けている。まだ使う。", "A chipped handle. Still in use.")
        case .glass: tr("夏祭りの景品。", "A prize from a summer fair.")
        case .vase: tr("花を入れたのは一度だけ。", "Held flowers exactly once.")
        case .potPlant: tr("水やりを忘れても生きのびた。", "Survived every forgotten watering.")
        case .kettle: tr("ピーッと鳴る。朝はうるさい。", "It whistles. Loudly. Every morning.")
        case .pan: tr("こげ付かない、と書いてあった。", "It said non-stick on the box.")
        case .pot: tr("カレーは3日もつ。", "Curry for three days.")
        case .riceCooker: tr("ふたを開ける音が好き。", "The lid makes a happy pop.")
        case .jar: tr("毎年6月に漬ける。", "Pickled every June.")
        case .cushion: tr("猫のほうが長く座っていた。", "The cat sat here more than anyone.")
        case .pillow: tr("ちょうどいい高さは、これだけ。", "The only one at the right height.")
        case .blanket: tr("冬の夜のこたつの相棒。", "Every winter night's partner.")
        case .teddy: tr("名前は「むぎ」。一番上に入れてあげて。", "Her name is Mugi. Put her on top.")
        case .photoFrame: tr("この部屋に来た日の写真。", "A photo from moving-in day.")
        case .trophy: tr("町内の綱引き大会、準優勝。", "Runner-up, neighborhood tug-of-war.")
        case .lamp: tr("試験前の夜をぜんぶ知っている。", "Knows every night before an exam.")
        case .clock: tr("5分すすめてある。", "Set five minutes fast, on purpose.")
        case .ball: tr("空気は少し抜けている。", "A little soft. Still kicks fine.")
        case .shoeBox: tr("中身は靴ではなく手紙。", "Letters inside, not shoes.")
        case .boots: tr("水たまりは、わざと踏む。", "Made for stepping in puddles on purpose.")
        case .blocks: tr("いつも塔を作ってから崩す。", "Every tower ends in a crash.")
        case .toyCar: tr("ドアが開く。それが大事。", "The doors open. That's the point.")
        case .gameBox: tr("説明書はなくした。", "The manual is long gone.")
        case .records: tr("針を落とす前の、あの音。", "That crackle before the song starts.")
        case .radio: tr("雨の日は野球中継。", "Baseball on rainy days.")
        case .laptop: tr("卒論はここで書いた。", "Wrote the thesis on this.")
        case .dumbbell: tr("3日だけ使った。", "Used for three whole days.")
        case .toolbox: tr("ドライバーが1本足りない。", "One screwdriver is missing.")
        case .globe: tr("国の名前が少し古い。", "Some country names are out of date.")
        case .hatBox: tr("結婚式で一度だけかぶった。", "Worn once, at a wedding.")
        case .ukulele: tr("弾けるのは2曲。", "Knows exactly two songs.")
        case .boardGame: tr("駒が1つだけボタン。", "One piece is now a button.")
        case .piggyBank: tr("振るとまだ鳴る。", "Still rattles when shaken.")
        case .teapot: tr("お客さんの日だけ出す。", "Only for guests.")
        case .snowGlobe: tr("初めての旅行のおみやげ。", "A souvenir from the first trip.")
        }
    }

    /// 箱にマジックで書くときの分類
    var label: BoxLabel {
        switch self {
        case .book, .dictionary, .comics, .boardGame, .records: .books
        case .plate, .bowl, .mug, .glass, .kettle, .pan, .pot, .riceCooker, .jar, .teapot: .kitchen
        case .cushion, .pillow, .blanket: .linens
        case .teddy, .blocks, .toyCar, .ball, .gameBox, .piggyBank: .toys
        case .vase, .potPlant, .photoFrame, .trophy, .lamp, .clock, .globe, .snowGlobe: .room
        case .shoeBox, .boots, .hatBox: .closet
        case .radio, .laptop, .dumbbell, .toolbox, .ukulele: .things
        }
    }
}

/// 箱に書く言葉（中身の多い分類を書く）
enum BoxLabel: String, Codable, Sendable, CaseIterable {
    case books, kitchen, linens, toys, room, closet, things

    var text: String {
        switch self {
        case .books: tr("本", "BOOKS")
        case .kitchen: tr("台所", "KITCHEN")
        case .linens: tr("布もの", "LINENS")
        case .toys: tr("おもちゃ", "TOYS")
        case .room: tr("部屋", "DECOR")
        case .closet: tr("くつ・服", "CLOSET")
        case .things: tr("いろいろ", "MISC")
        }
    }

    /// 箱の中身の分類のうち、いちばん多いもの（同じ数なら並びが前のもの）
    static func dominant(_ items: [ItemKind]) -> BoxLabel {
        guard !items.isEmpty else { return .things }
        var counts: [BoxLabel: Int] = [:]
        for i in items { counts[i.label, default: 0] += 1 }
        return BoxLabel.allCases.max { (counts[$0] ?? 0, -index($0)) < (counts[$1] ?? 0, -index($1)) } ?? .things
    }

    private static func index(_ l: BoxLabel) -> Int { allCases.firstIndex(of: l) ?? 0 }
}
