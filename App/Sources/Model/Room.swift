import Foundation

/// 部屋の種類（床の色・壁の色・物の顔ぶれが変わる）
enum RoomTheme: String, Codable, Sendable, CaseIterable {
    case studio, kids, kitchen, study, closet, living, bedroom, garage

    var pool: [ItemKind] {
        switch self {
        case .studio: [.book, .mug, .cushion, .pillow, .lamp, .clock, .laptop, .plate, .glass, .potPlant, .shoeBox, .comics]
        case .kids: [.blocks, .toyCar, .ball, .gameBox, .piggyBank, .comics, .boardGame, .pillow, .boots, .globe, .cushion]
        case .kitchen: [.plate, .bowl, .mug, .glass, .kettle, .pan, .pot, .riceCooker, .jar, .teapot]
        case .study: [.book, .dictionary, .comics, .lamp, .laptop, .globe, .radio, .clock, .records, .mug]
        case .closet: [.shoeBox, .boots, .hatBox, .toolbox, .ball, .ukulele, .blanket, .pillow]
        case .living: [.cushion, .records, .radio, .vase, .potPlant, .clock, .boardGame, .gameBox, .teapot, .glass]
        case .bedroom: [.pillow, .blanket, .cushion, .lamp, .clock, .book, .hatBox, .glass, .vase]
        case .garage: [.toolbox, .dumbbell, .ball, .boots, .records, .blanket, .radio, .ukulele, .potPlant]
        }
    }

    var keepsake: ItemKind {
        switch self {
        case .studio, .closet: .photoFrame
        case .kids, .bedroom: .teddy
        case .kitchen, .living: .snowGlobe
        case .study, .garage: .trophy
        }
    }

    var name: String {
        switch self {
        case .studio: tr("ワンルーム", "Studio")
        case .kids: tr("子ども部屋", "Kids' room")
        case .kitchen: tr("キッチン", "Kitchen")
        case .study: tr("書斎", "Study")
        case .closet: tr("物入れ", "Closet")
        case .living: tr("居間", "Living room")
        case .bedroom: tr("寝室", "Bedroom")
        case .garage: tr("物置", "Storeroom")
        }
    }

    /// 壁・床の色（朝の光の部屋。部屋ごとに少しだけ変える）
    var wall: UInt32 {
        switch self {
        case .studio: 0xF6EEDF
        case .kids: 0xEAF3EC
        case .kitchen: 0xF7EFE2
        case .study: 0xEFEADF
        case .closet: 0xF2ECE6
        case .living: 0xF8EDDC
        case .bedroom: 0xEEEBF4
        case .garage: 0xE9EBE7
        }
    }

    var floor: UInt32 {
        switch self {
        case .studio, .living: 0xD8B48A
        case .kids: 0xE2C29A
        case .kitchen: 0xCFC6B8
        case .study: 0xB98D63
        case .closet: 0xD3B38F
        case .bedroom: 0xCDAE8E
        case .garage: 0xBDB7AC
        }
    }
}

/// 1 面＝1 部屋
struct Room: Identifiable, Sendable, Equatable {
    /// 1〜60 は決まった部屋、0 は毎日の部屋
    var number: Int
    var theme: RoomTheme
    var title: String
    var story: String
    var items: [ItemKind]
    /// 毎日の部屋の日付（yyyy-MM-dd）
    var day: String? = nil

    var id: String { day.map { "daily-" + $0 } ?? "room-\(number)" }

    static let freeCount = 24
    var isPro: Bool { day == nil && number > Room.freeCount }
    var keepsake: ItemKind? { items.first { $0.spec.keepsake } }

    static func numbered(_ n: Int) -> Room { all[min(max(n, 1), all.count) - 1] }

    /// 毎日の部屋（日付の種で、部屋の種類と物の並びを決める。だれが開いても同じ）
    static func daily(_ day: String) -> Room {
        var seed: UInt64 = 1469598103934665603
        for b in day.utf8 { seed = (seed ^ UInt64(b)) &* 1099511628211 }
        var rng = SeededRNG(seed: seed)
        let themes = RoomTheme.allCases
        let theme = themes[Int(rng.next() % UInt64(themes.count))]
        let count = 12 + Int(rng.next() % 3)
        var items: [ItemKind] = (0..<count).map { _ in theme.pool[Int(rng.next() % UInt64(theme.pool.count))] }
        items.insert(theme.keepsake, at: 3 + Int(rng.next() % UInt64(count - 3)))
        return Room(number: 0, theme: theme, title: trf("今日の%@", "Today's %@", theme.name.lowercasedIfEnglish),
                    story: tr("毎日ひと部屋。だれが開いても同じ部屋。", "One room a day. Same room for everyone."), items: items, day: day)
    }
}

extension String {
    var lowercasedIfEnglish: String { Lang.isJapanese ? self : lowercased() }
}

/// 日付（端末の暦。キーは yyyy-MM-dd）
enum Days {
    static func key(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func offset(_ date: Date, days: Int, calendar: Calendar = .current) -> String {
        key(calendar.date(byAdding: .day, value: days, to: date) ?? date, calendar: calendar)
    }
}
