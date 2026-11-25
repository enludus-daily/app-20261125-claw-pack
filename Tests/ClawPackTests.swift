import Foundation
import Testing
@testable import ClawPack

/// うれしい：ぴったり詰めると箱が減る（何も考えずに落とすより 1 箱以上少ない）
struct PackingTests {
    @Test func expertPackingSavesBoxesOverCarelessDrops() {
        var careless: [Double] = []
        var expert: [Double] = []
        for room in Room.all.prefix(Room.freeCount) {
            let runs = (0..<100).map { PackSim.run(room.items, policy: .careless(seed: UInt64($0) &* 7919 &+ 13)) }
            careless.append(Double(runs.reduce(0, +)) / Double(runs.count))
            expert.append(Double(PackSim.run(room.items, policy: .expert)))
        }
        let c = careless.reduce(0, +) / Double(careless.count)
        let e = expert.reduce(0, +) / Double(expert.count)
        #expect((4.3...6.3).contains(c), "何も考えずに落とすと平均 5 箱前後: \(c)")
        #expect((2.8...4.2).contains(e), "大きい物から隅へで 3〜4 箱: \(e)")
        #expect(c - e >= 1, "差が 1 箱以上: \(c - e)")
    }

    @Test func parIsExpertPlusOne() {
        let room = Room.numbered(1)
        #expect(Rules.par(room.items) == Rules.expertBoxes(room.items) + 1)
    }

    @Test func everyItemFitsInTheBox() {
        for k in ItemKind.allCases {
            #expect(k.spec.w < Rules.boxWidth && k.spec.h < Rules.boxHeight, "\(k) が箱より大きい")
        }
    }

    @Test func roomsHaveOneKeepsakeEach() {
        #expect(Room.all.count == 60)
        for room in Room.all {
            #expect(room.items.filter { $0.spec.keepsake }.count == 1, "部屋 \(room.number)")
            #expect((11...17).contains(room.items.count), "部屋 \(room.number) の物の数 \(room.items.count)")
        }
        #expect(Room.all.prefix(Room.freeCount).allSatisfy { !$0.isPro })
        #expect(Room.all.dropFirst(Room.freeCount).allSatisfy { $0.isPro })
    }
}

/// 惜しい：つかむ強さのゆらぎ（1 回でつかめる割合が 6〜8 割）
struct GripTests {
    @Test func firstTryGrabRateIsBetweenSixtyAndEightyPercent() {
        var rng = SeededRNG(seed: 42)
        var tries = 0
        var got = 0
        for k in ItemKind.allCases {
            for _ in 0..<200 {
                // 人がだいたいで合わせる：物の幅の半分の中で、ずれはでたらめ
                let offset = rng.unit()
                tries += 1
                if Rules.grabs(k, offset: offset, roll: rng.unit()) { got += 1 }
            }
        }
        let rate = Double(got) / Double(tries)
        #expect((0.6...0.8).contains(rate), "1 回でつかめる割合: \(rate)")
    }

    @Test func centerGrabIsBetterThanEdge() {
        for k in ItemKind.allCases {
            #expect(Rules.gripChance(k, offset: 0) > Rules.gripChance(k, offset: 0.9))
            #expect(Rules.gripChance(k, offset: 1.2) == 0)
        }
    }

    @Test func steadyPracticeNeverSlipsNearTheCenter() {
        #expect(Rules.grabs(.ball, offset: 0.5, steady: true, roll: 0.999))
        #expect(!Rules.grabs(.ball, offset: 1.1, steady: true, roll: 0))
    }
}

/// 怖い：割れ物は高い所から落とすと割れる（でたらめに押すと 2〜4 割、低く下ろせば 0）
struct BreakTests {
    @Test func randomHoldingBreaksTwoToFourInTen() {
        var rng = SeededRNG(seed: 7)
        var drops = 0
        var broken = 0
        let fragile = ItemKind.allCases.filter { $0.spec.fragile }
        for _ in 0..<2_000 {
            let k = fragile[Int(rng.next() % UInt64(fragile.count))]
            // 持ち上げたときの、物の下の端から下の面までの高さ（箱の中身の高さで 200〜330 点）
            let start = 200 + rng.unit() * 130
            // 人がだいたい押す長さ：0〜2 秒のでたらめ
            let fall = Rules.fallAfterHolding(seconds: rng.unit() * 2, start: start)
            drops += 1
            if Rules.breaks(k, fall: fall) { broken += 1 }
        }
        let rate = Double(broken) / Double(drops)
        #expect((0.2...0.4).contains(rate), "割れる割合: \(rate)")
    }

    @Test func loweringAllTheWayNeverBreaks() {
        for k in ItemKind.allCases {
            let fall = Rules.fallAfterHolding(seconds: 5, start: 330)
            #expect(!Rules.breaks(k, fall: fall))
        }
    }

    @Test func onlyFragileThingsBreak() {
        #expect(Rules.breaks(.plate, fall: 200))
        #expect(!Rules.breaks(.cushion, fall: 400))
        #expect(!Rules.breaks(.plate, fall: Rules.breakFall - 1))
    }

    @Test func heavyThingsCrushFragileOnes() {
        #expect(Rules.crushes(.dumbbell, fall: 60, onto: .glass))
        #expect(!Rules.crushes(.dumbbell, fall: 20, onto: .glass))
        #expect(!Rules.crushes(.pillow, fall: 200, onto: .glass))
        #expect(!Rules.crushes(.dumbbell, fall: 200, onto: .book))
    }
}

struct LidAndScoreTests {
    @Test func lidClosesOnlyWhenNothingSticksOut() {
        #expect(Rules.canClose(tops: [40, 120, 150]))
        #expect(Rules.canClose(tops: [Rules.boxHeight + Rules.lidTolerance]))
        #expect(!Rules.canClose(tops: [40, 160]))
        #expect(!Rules.canClose(tops: []))
    }

    @Test func fewerBoxesSaveMoreYen() {
        let good = Rules.Outcome(boxes: 3, par: 3, broken: 0, keepsakeOnTop: true)
        let ok = Rules.Outcome(boxes: 4, par: 3, broken: 0, keepsakeOnTop: false)
        let bad = Rules.Outcome(boxes: 6, par: 3, broken: 2, keepsakeOnTop: false)
        #expect(good.savedYen == 2 * 600 + 300)
        #expect(ok.savedYen == 600)
        #expect(bad.savedYen == 0)
        #expect(good.stars == 3 && ok.stars == 2 && bad.stars == 1)
        #expect(Rules.Outcome(boxes: 3, par: 3, broken: 1, keepsakeOnTop: false).stars == 2)
    }
}

struct RecordTests {
    @Test func dailyRoomIsTheSameForEveryoneAndHasAKeepsake() {
        let a = Room.daily("2026-11-25")
        let b = Room.daily("2026-11-25")
        let c = Room.daily("2026-11-26")
        #expect(a.items == b.items && a.theme == b.theme)
        #expect(a.items != c.items)
        #expect(a.items.filter { $0.spec.keepsake }.count == 1)
        #expect(!a.isPro)
    }

    @Test func streakGrowsOnConsecutiveDailyRoomsOnly() {
        var s = SaveData()
        let o = Rules.Outcome(boxes: 3, par: 3, broken: 0, keepsakeOnTop: true)
        s.record(o, room: Room.daily("2026-11-24"), packedItems: [.book], today: "2026-11-24", yesterday: "2026-11-23")
        #expect(s.streak == 1)
        s.record(o, room: Room.daily("2026-11-25"), packedItems: [.mug], today: "2026-11-25", yesterday: "2026-11-24")
        #expect(s.streak == 2)
        // 同じ日の 2 回目は数えない
        s.record(o, room: Room.daily("2026-11-25"), packedItems: [], today: "2026-11-25", yesterday: "2026-11-24")
        #expect(s.streak == 2)
        // 決まった部屋は数えない
        s.record(o, room: Room.numbered(1), packedItems: [], today: "2026-11-25", yesterday: "2026-11-24")
        #expect(s.streak == 2)
        #expect(s.packed == [.book, .mug])
        #expect(s.totalSaved == o.savedYen * 4)
        s.refreshStreak(today: "2026-11-28", yesterday: "2026-11-27")
        #expect(s.streak == 0 && s.bestStreak == 2)
    }

    @Test func bestKeepsTheBetterResultAndNextRoomAdvances() {
        var s = SaveData()
        let room = Room.numbered(1)
        s.record(Rules.Outcome(boxes: 5, par: 3, broken: 0, keepsakeOnTop: false), room: room, packedItems: [], today: "x", yesterday: "y")
        s.record(Rules.Outcome(boxes: 3, par: 3, broken: 0, keepsakeOnTop: true), room: room, packedItems: [], today: "x", yesterday: "y")
        s.record(Rules.Outcome(boxes: 6, par: 3, broken: 2, keepsakeOnTop: false), room: room, packedItems: [], today: "x", yesterday: "y")
        #expect(s.best[room.id]?.stars == 3)
        #expect(s.best[room.id]?.boxes == 3)
        #expect(s.nextRoom(isPro: false) == 2)
    }

    @Test func saveRoundTrips() throws {
        var s = SaveData()
        s.packed = [.teddy, .plate]
        s.skin = .gold
        s.daily["2026-11-25"] = 1200
        let data = try JSONEncoder().encode(s)
        #expect(try JSONDecoder().decode(SaveData.self, from: data) == s)
    }

    @Test func boxLabelFollowsTheMostCommonKind() {
        #expect(BoxLabel.dominant([.plate, .bowl, .book]) == .kitchen)
        #expect(BoxLabel.dominant([.book, .dictionary, .teddy]) == .books)
        #expect(BoxLabel.dominant([]) == .things)
    }
}
