import Foundation
import Observation
import SwiftUI
import UIKit

enum ActiveSheet: String, Identifiable {
    case rooms, result, truck, settings, paywall
    var id: String { rawValue }
}

struct Banner: Equatable, Identifiable {
    enum Tint { case info, good, alert }
    let id = UUID()
    var title: String
    var detail: String
    var tint: Tint = .info
}

/// アプリの状態。決まりは Rules、物理は PackScene、ここは両方をつなぐ
@MainActor
@Observable
final class AppModel {
    // 保存するもの
    var save: SaveData
    var onboarded: Bool { didSet { if persists { UserDefaults.standard.set(onboarded, forKey: "onboarded") } } }
    var soundOn: Bool { didSet { if persists { UserDefaults.standard.set(soundOn, forKey: "sound") } } }
    var hapticsOn: Bool { didSet { if persists { UserDefaults.standard.set(hapticsOn, forKey: "haptics") } } }
    var paywallOffered: Bool { didSet { if persists { UserDefaults.standard.set(paywallOffered, forKey: "paywallOffered") } } }
    @ObservationIgnored let persists: Bool

    // 部屋
    private(set) var room: Room
    private(set) var par: Int
    private(set) var queue: [ItemKind] = []
    private(set) var queueIndex = 0
    private(set) var closedBoxes: [[ItemKind]] = []
    private(set) var broken = 0
    private(set) var keepsakeOnTop = false
    private(set) var packedItems: [ItemKind] = []
    private(set) var floorCount = 0
    private(set) var inBoxCount = 0
    private(set) var crane: PackScene.Crane = .idle
    private(set) var finished = false
    var result: Rules.Outcome?
    var resultRoom: Room?

    // 画面
    var activeSheet: ActiveSheet?
    var banner: Banner?
    var onboardingPage = 0
    var reduceMotion = false
    /// 撮影：絵を止める
    var still = false
    var frozen: UIImage?
    var scenePaused = false
    var now: Date
    let calendar = Calendar.current

    // 手応え（振動の引き金）
    var pressTick = 0
    var grabTick = 0
    var missTick = 0
    var landTick = 0
    var crashTick = 0
    var sealTick = 0
    var warnTick = 0
    var clearTick = 0

    // 課金
    let purchases: PurchaseStore
    var proOverride = false
    var isPro: Bool { proOverride || purchases.entitlements.isPro }
    @ObservationIgnored var forceGrab = false

    @ObservationIgnored let scene: PackScene
    @ObservationIgnored private var rng = SeededRNG(seed: 1)
    @ObservationIgnored private var bannerTask: Task<Void, Never>?

    static var bundleID: String { Bundle.main.bundleIdentifier ?? "com.enludus.daily.018" }
    static var proID: String { ProductID.pro(bundleID: bundleID) }

    init(persists: Bool = true, now: Date = Date()) {
        self.persists = persists
        self.now = now
        let d = UserDefaults.standard
        save = persists ? SaveData.load() : SaveData()
        onboarded = persists ? d.bool(forKey: "onboarded") : false
        soundOn = persists ? (d.object(forKey: "sound") as? Bool ?? true) : true
        hapticsOn = persists ? (d.object(forKey: "haptics") as? Bool ?? true) : true
        paywallOffered = persists ? d.bool(forKey: "paywallOffered") : false
        purchases = PurchaseStore(productIDs: [AppModel.proID], proProductIDs: [AppModel.proID])
        let first = Room.numbered(1)
        room = first
        par = Rules.par(first.items)
        scene = PackScene(size: PackScene.size)
        scene.model = self
        save.refreshStreak(today: today, yesterday: yesterday)
        start(Room.numbered(save.nextRoom(isPro: false)))
    }

    var today: String { Days.key(now, calendar: calendar) }
    var yesterday: String { Days.offset(now, days: -1, calendar: calendar) }
    var dailyRoom: Room { Room.daily(today) }
    var dailyDone: Bool { save.daily[today] != nil }
    var motionOff: Bool { reduceMotion }
    var steadyOn: Bool { isPro && save.steady }
    var remaining: Int { max(0, queue.count - queueIndex) + floorCount + (scene.isHolding ? 1 : 0) }
    /// 次に部屋へ来る物（3 つまで）
    var upcoming: [ItemKind] { Array(queue.dropFirst(queueIndex).prefix(3)) }
    var boxesUsed: Int { closedBoxes.count + (inBoxCount > 0 ? 1 : 0) }

    // MARK: 部屋の始め

    func start(_ room: Room) {
        self.room = room
        par = Rules.par(room.items)
        queue = room.items
        closedBoxes = []
        broken = 0
        keepsakeOnTop = false
        packedItems = []
        finished = false
        floorCount = 0
        inBoxCount = 0
        result = nil
        var seed: UInt64 = 7
        for b in room.id.utf8 { seed = seed &* 31 &+ UInt64(b) }
        rng = SeededRNG(seed: seed &+ UInt64(save.roomsCleared))
        scene.reset()
        let first = Array(queue.prefix(4))
        queueIndex = first.count
        scene.placeOnFloor(first)
        crane = .idle
    }

    func restart() { start(room) }

    func play(room number: Int) {
        let r = Room.numbered(number)
        if r.isPro && !isPro {
            activeSheet = .paywall
            return
        }
        activeSheet = nil
        start(r)
        showBanner(r.title, r.story)
    }

    func playDaily() {
        activeSheet = nil
        start(dailyRoom)
        showBanner(tr("今日の部屋", "Today's room"), tr("だれが開いても同じ部屋。少ない箱で詰めよう", "Same room for everyone. Use as few boxes as you can"))
    }

    // MARK: 場面から

    func nextItemFromQueue() -> ItemKind? {
        guard queueIndex < queue.count, !finished else { return nil }
        defer { queueIndex += 1 }
        return queue[queueIndex]
    }

    func nextRoll() -> Double {
        if forceGrab { return 0 }
        return rng.unit()
    }

    func craneChanged() {
        crane = scene.crane
    }

    func sceneTick(floor: Int, inBox: Int) {
        let changed = floor != floorCount || inBox != inBoxCount
        if floor != floorCount { floorCount = floor }
        if inBox != inBoxCount { inBoxCount = inBox }
        if changed && floor == 0 && !still { checkFinished() }
    }

    func didGrab(_ kind: ItemKind) {
        grabTick += 1
        play(.grab)
    }

    func didMiss(near kind: ItemKind?) {
        missTick += 1
        play(.miss)
        if kind != nil {
            scene.floatText(tr("おしい", "Slipped"), at: CGPoint(x: scene.aimX, y: 300), color: UIColor(hex: Palette.craneDeep))
        }
    }

    func didRelease(_ kind: ItemKind) {}

    func didLand(_ kind: ItemKind, fall: Double) {
        landTick += 1
        play(.thud(kind.spec.weight))
    }

    func didBreak(_ kind: ItemKind) {
        broken += 1
        crashTick += 1
        play(.crash)
        showBanner(trf("%@が割れた", "The %@ broke", kind.name.lowercasedIfEnglish), tr("割れ物は低く下ろしてから放す。重い物の下にも入れない", "Lower fragile things before letting go, and keep them out from under heavy ones"), tint: .alert)
    }

    // MARK: ボタン

    func pressClaw() {
        pressTick += 1
        scene.press()
        crane = scene.crane
    }

    func releaseClaw() {
        scene.release()
        crane = scene.crane
    }

    func moveClaw(to x: CGFloat) { scene.setAim(x) }

    func sealBox() {
        pressTick += 1
        guard inBoxCount > 0 else {
            showBanner(tr("箱はまだ空っぽ", "The box is empty"), tr("物をつかんで、右の箱の上で放そう", "Grab something and let go over the box on the right"))
            return
        }
        guard crane == .idle else { return }
        guard let sealed = scene.seal() else {
            warnTick += 1
            play(.warn)
            scene.flashOverflow()
            showBanner(tr("ふたが閉まらない", "The lid won't close"), tr("縁からはみ出している物を、つかんで出そう", "Something sticks out above the rim. Grab it out"), tint: .alert)
            return
        }
        sealTick += 1
        play(.tape)
        closedBoxes.append(sealed.items)
        packedItems.append(contentsOf: sealed.items)
        if sealed.items.contains(where: { $0.spec.keepsake }) { keepsakeOnTop = sealed.keepsakeOnTop }
        inBoxCount = 0
        if sealed.keepsakeOnTop {
            showBanner(tr("たいせつな物が一番上", "Keepsake on top"), trf("ていねい賞 +%@", "Careful bonus +%@", yen(Rules.keepsakeBonus)), tint: .good)
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            self.play(.truck)
        }
        if persists { save.store() }
        checkFinished()
    }

    /// 部屋が片付いたか（床も箱も空で、もう出てくる物がない）
    func checkFinished() {
        guard !finished, queueIndex >= queue.count, floorCount == 0, !scene.isHolding else { return }
        if scene.boxItems.isEmpty {
            finish()
        } else {
            showBanner(tr("最後の箱を閉じよう", "Seal the last box"), tr("床が空になった。下の「箱を閉じる」でトラックへ", "The floor is clear. Tap Seal box to send it off"), tint: .good)
        }
    }

    func finish() {
        guard !finished else { return }
        finished = true
        let outcome = Rules.Outcome(boxes: closedBoxes.count, par: par, broken: broken, keepsakeOnTop: keepsakeOnTop)
        save.record(outcome, room: room, packedItems: packedItems, today: today, yesterday: yesterday)
        if persists { save.store() }
        result = outcome
        resultRoom = room
        clearTick += 1
        play(.clear)
        activeSheet = .result
    }

    /// 結果のあと：次の部屋へ（無料の 24 部屋を全部片付けたら Pro の案内）
    func nextRoom() {
        let n = save.nextRoom(isPro: isPro)
        if !isPro && save.best["room-\(n)"] != nil {
            activeSheet = .paywall
            return
        }
        play(room: n)
    }

    /// 結果を閉じたとき：はじめて片付けた直後に一度だけ Pro を見せる（価値を感じた直後）
    func resultClosed() {
        if !isPro && !paywallOffered && save.roomsCleared >= 2 {
            paywallOffered = true
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(400))
                self.activeSheet = .paywall
            }
        }
    }

    // MARK: 撮影・デモ

    /// 撮影：閉じた箱と割れた数を置く
    func stage(closed: [[ItemKind]], broken: Int = 0, queueUsed: Int? = nil) {
        closedBoxes = closed
        packedItems = closed.flatMap { $0 }
        self.broken = broken
        if let queueUsed { queueIndex = min(queue.count, queueUsed) }
    }

    /// 撮影・デモ：結果を出す
    func stageResult(_ outcome: Rules.Outcome) {
        finished = true
        result = outcome
        resultRoom = room
        activeSheet = .result
    }

    // MARK: 見た目・音

    func setSkin(_ skin: ClawSkin) {
        guard !skin.isPro || isPro else { activeSheet = .paywall; return }
        save.skin = skin
        if persists { save.store() }
        // まだ何も詰めていなければ、すぐにつめの色を変える（途中なら次の部屋から）
        if closedBoxes.isEmpty && inBoxCount == 0 && !scene.isHolding { start(room) }
    }

    func play(_ cue: SoundBox.Cue) {
        guard soundOn, !still else { return }
        SoundBox.shared.play(cue)
    }

    func showBanner(_ title: String, _ detail: String, tint: Banner.Tint = .info) {
        bannerTask?.cancel()
        withAnimation(motionOff ? nil : .spring(response: 0.35, dampingFraction: 0.8)) {
            banner = Banner(title: title, detail: detail, tint: tint)
        }
        guard !still else { return }
        bannerTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3.2))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) { self.banner = nil }
        }
    }

    func syncPro() {
        if !isPro, save.steady { save.steady = false }
    }

    // MARK: 共有カード

    var shareText: String {
        guard let r = result, let room = resultRoom else { return "" }
        let boxes = String(repeating: "📦", count: r.boxes)
        let crashes = String(repeating: "💥", count: r.broken)
        return trf("つかんで荷造り「%@」%@%@ 箱 %d（目安 %d）浮いた代金 %@", "Claw & Pack \"%@\" %@%@ %d boxes (par %d), saved %@", room.title, boxes, crashes, r.boxes, r.par, yen(r.savedYen))
    }
}
