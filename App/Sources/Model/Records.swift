import Foundation

/// クレーンのつめの見た目（Pro で金・木）
enum ClawSkin: String, Codable, Sendable, CaseIterable, Identifiable {
    case sunny, gold, oak
    var id: String { rawValue }
    var isPro: Bool { self != .sunny }
    var name: String {
        switch self {
        case .sunny: tr("ひまわり色", "Sunflower")
        case .gold: tr("金のつめ", "Gold claw")
        case .oak: tr("木のつめ", "Oak claw")
        }
    }
    var color: UInt32 {
        switch self {
        case .sunny: 0xF7C531
        case .gold: 0xD4A537
        case .oak: 0xA8754A
        }
    }
}

/// 部屋ごとのいちばんの記録
struct RoomBest: Codable, Equatable, Sendable {
    var stars: Int
    var boxes: Int
    var savedYen: Int
}

/// 端末に残すもの（保存は箱を閉じたときと部屋の終わりだけ）
struct SaveData: Codable, Equatable, Sendable {
    var best: [String: RoomBest] = [:]
    /// 浮いたトラック代の合計（円）
    var totalSaved = 0
    var boxesSent = 0
    var roomsCleared = 0
    var brokenTotal = 0
    /// 一度でも詰めた物（荷物の図鑑）
    var packed: Set<ItemKind> = []
    /// 毎日の部屋：日付 → 浮いた額
    var daily: [String: Int] = [:]
    var streak = 0
    var bestStreak = 0
    var lastDaily: String?
    var skin: ClawSkin = .sunny
    var steady = false

    var totalStars: Int { best.values.reduce(0) { $0 + $1.stars } }

    /// 次に遊ぶ決まった部屋（まだ星のない最初の部屋。無料は 24 まで）
    func nextRoom(isPro: Bool) -> Int {
        let limit = isPro ? Room.all.count : Room.freeCount
        return (1...limit).first { best["room-\($0)"] == nil } ?? limit
    }

    /// 部屋が終わったときに記録する。today は今日のキー、yesterday は昨日のキー
    mutating func record(_ outcome: Rules.Outcome, room: Room, packedItems: [ItemKind], today: String, yesterday: String) {
        roomsCleared += 1
        brokenTotal += outcome.broken
        totalSaved += outcome.savedYen
        packed.formUnion(packedItems)
        let new = RoomBest(stars: outcome.stars, boxes: outcome.boxes, savedYen: outcome.savedYen)
        if let old = best[room.id] {
            if (new.stars, -new.boxes, new.savedYen) > (old.stars, -old.boxes, old.savedYen) { best[room.id] = new }
        } else {
            best[room.id] = new
        }
        // 毎日の部屋は、その日に遊んだときだけ続いた日数に数える（同じ日の 2 回目は数えない）
        if room.day == today {
            daily[today] = max(daily[today] ?? 0, outcome.savedYen)
            if lastDaily != today {
                streak = lastDaily == yesterday ? streak + 1 : 1
                bestStreak = max(bestStreak, streak)
                lastDaily = today
            }
        }
    }

    /// 開いた日に、続いた日数が切れていたら 0 に戻す（昨日も今日も遊んでいない）
    mutating func refreshStreak(today: String, yesterday: String) {
        if let last = lastDaily, last != today, last != yesterday { streak = 0 }
    }

    // MARK: 保存

    static let key = "save"

    static func load(_ defaults: UserDefaults = .standard) -> SaveData {
        guard let data = defaults.data(forKey: key), let s = try? JSONDecoder().decode(SaveData.self, from: data) else { return SaveData() }
        return s
    }

    func store(_ defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) { defaults.set(data, forKey: SaveData.key) }
    }
}
