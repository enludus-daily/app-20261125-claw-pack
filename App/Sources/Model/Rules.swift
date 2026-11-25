import Foundation

/// 決まった乱数（同じ種なら毎回同じ。毎日の部屋・つかみのゆらぎ・テストに使う）
struct SeededRNG: RandomNumberGenerator, Sendable {
    private var state: UInt64

    init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// 0 以上 1 未満
    mutating func unit() -> Double { Double(next() >> 11) / Double(1 << 53) }
}

/// 遊びの決まり（SpriteKit から切り離して、テストで数字を確かめる）。
/// 座標は SpriteKit の場面と同じ点の数：場面 480 × 440、箱の中は幅 200 × 高さ 150。
enum Rules {
    static let sceneWidth: Double = 480
    static let sceneHeight: Double = 440
    static let boxWidth: Double = 200
    static let boxHeight: Double = 150
    /// 床の高さ（箱の底もここ）
    static let floorY: Double = 34
    /// クレーンのつめの、いちばん上の高さ（つかんだ物の下の端）
    static let carryY: Double = 360
    /// つかんだまま下ろす速さ（点/秒）
    static let lowerSpeed: Double = 210

    // MARK: うれしい：ぴったり詰めると箱が減る

    /// 名人の箱の数（大きい物から、いちばん低くなる所に置く）
    static func expertBoxes(_ items: [ItemKind]) -> Int {
        PackSim.run(items, policy: .expert)
    }

    /// 目安の箱の数（名人＋1。物理では転がって少しすき間ができるため）
    static func par(_ items: [ItemKind]) -> Int { expertBoxes(items) + 1 }

    // MARK: 惜しい：つかむ強さのゆらぎ

    /// 1 回でつかめる見込み。offset はつめと物の中心のずれ（物の幅の半分を 1 とする）。
    /// ずれが 1 を超えると、つめが物に掛からない。steady（Pro の練習）はゆらぎなし
    static func gripChance(_ item: ItemKind, offset: Double, steady: Bool = false) -> Double {
        let o = abs(offset)
        guard o <= 1 else { return 0 }
        if steady { return o <= 0.8 ? 1 : 0.5 }
        return item.spec.grip * (1 - 0.45 * o * o)
    }

    /// つかめたか（ゆらぎは乱数 1 つ）
    static func grabs(_ item: ItemKind, offset: Double, steady: Bool = false, roll: Double) -> Bool {
        roll < gripChance(item, offset: offset, steady: steady)
    }

    // MARK: 怖い：割れ物は高い所から落とすと割れる

    /// 割れる高さ（場面の高さの 3 割 ≒ 1.2m）
    static let breakFall: Double = sceneHeight * 0.3

    /// 割れ物が落ちた高さで割れるか
    static func breaks(_ item: ItemKind, fall: Double) -> Bool {
        item.spec.fragile && fall > breakFall
    }

    /// 重い物（重さ 3 以上）が上から落ちてきたら、下の割れ物は割れる（落ちた高さが場面の 1 割より大きいとき）
    static func crushes(_ heavy: ItemKind, fall: Double, onto fragile: ItemKind) -> Bool {
        fragile.spec.fragile && heavy.spec.weight >= 3 && fall > sceneHeight * 0.1
    }

    /// ボタンを押していた秒数から、放したときの落ちる高さ。
    /// start はつかんで持ち上げたときの、物の下の端から下の面までの高さ。押しているあいだ下がり、下の面の 4 点上で止まる
    static func fallAfterHolding(seconds: Double, start: Double) -> Double {
        max(4, start - max(0, seconds) * lowerSpeed)
    }

    // MARK: ふた：箱の縁より上にはみ出すと閉じられない

    static let lidTolerance: Double = 4

    /// 物の上の端（箱の底から）が全部縁の下なら閉じられる
    static func canClose(tops: [Double]) -> Bool {
        !tops.isEmpty && tops.allSatisfy { $0 <= boxHeight + lidTolerance }
    }

    // MARK: 点（浮いたトラック代）

    /// 箱 1 つのトラック代（円）
    static let yenPerBox = 600
    static let keepsakeBonus = 300
    static let breakPenalty = 200

    struct Outcome: Equatable, Sendable, Codable {
        var boxes: Int
        var par: Int
        var broken: Int
        var keepsakeOnTop: Bool

        /// 浮いたトラック代：何も考えずに詰めた箱の数（目安＋2）より少ないぶん × 600 円、たいせつな物が一番上なら +300、割れ物 1 つ −200
        var savedYen: Int {
            let base = max(0, par + 2 - boxes) * Rules.yenPerBox
            return max(0, base + (keepsakeOnTop ? Rules.keepsakeBonus : 0) - broken * Rules.breakPenalty)
        }

        /// 星 1〜3：目安以内で割れなし＝3、目安＋1 以内＝2、ほか＝1
        var stars: Int {
            if boxes <= par && broken == 0 { return 3 }
            if boxes <= par + 1 { return 2 }
            return 1
        }
    }
}

/// 箱詰めの見積もり（物を縦横そのままで、上から落として積む「スカイライン」の詰め方）。
/// 物理より少し上手に詰まるので、名人の箱の数の目安と、テストに使う
enum PackSim {
    enum Policy: Sendable {
        /// 何も考えずに落とす（落とす位置はでたらめ）
        case careless(seed: UInt64)
        /// 大きい物から、いちばん低くなる所へ
        case expert
    }

    static func run(_ items: [ItemKind], policy: Policy) -> Int {
        let width = Int(Rules.boxWidth)
        let height = Rules.boxHeight
        var sky = [Double](repeating: 0, count: width)
        var boxes = items.isEmpty ? 0 : 1
        var rng: SeededRNG?
        var order = items
        switch policy {
        case .careless(let seed): rng = SeededRNG(seed: seed)
        case .expert: order = items.enumerated().sorted { a, b in
                let sa = a.element.spec.w * a.element.spec.h
                let sb = b.element.spec.w * b.element.spec.h
                return sa == sb ? a.offset < b.offset : sa > sb
            }.map(\.element)
        }
        func land(_ x: Int, _ w: Int) -> Double { sky[x..<(x + w)].max() ?? 0 }
        for item in order {
            let w = min(width, Int(item.spec.w))
            let h = item.spec.h
            var x: Int
            if var r = rng {
                x = Int(r.unit() * Double(width - w + 1))
                rng = r
            } else {
                x = 0
                var best = Double.infinity
                for x0 in stride(from: 0, through: width - w, by: 3) {
                    let t = land(x0, w) + h
                    if t < best { best = t; x = x0 }
                }
            }
            if land(x, w) + h > height {
                boxes += 1
                sky = [Double](repeating: 0, count: width)
                if rng == nil { x = 0 }
            }
            let top = land(x, w) + h
            for i in x..<(x + w) { sky[i] = top }
        }
        return boxes
    }
}
