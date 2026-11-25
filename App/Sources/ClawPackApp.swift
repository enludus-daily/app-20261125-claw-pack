import SwiftUI

@main
struct ClawPackApp: App {
    /// アプリ全体で 1 つだけ（App の init は何度も呼ばれることがあるので、ここで作り直さない）
    private let model = Launch.shared

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
        }
    }
}

struct RootView: View {
    let model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        @Bindable var model = model
        ZStack {
            if !model.onboarded {
                OnboardingView().transition(.opacity)
            } else {
                PlayView().transition(.opacity)
            }
        }
        .environment(model)
        // 晴れた朝の部屋の色を自前で描くので、ライトに固定する
        .preferredColorScheme(.light)
        .sheet(item: $model.activeSheet, onDismiss: {
            if model.finished && model.result != nil && model.activeSheet == nil { model.resultClosed() }
        }) { sheet in
            SheetContent(sheet: sheet)
                .environment(model)
                .environment(\.locale, Lang.locale)
                .presentationCornerRadius(Radius.sheet)
                .presentationDetents(sheet == .settings ? [.medium, .large] : [.large])
        }
        // 手応えの表（README）：押す・つかむ・つかみ損ね・着地・割れる・箱を閉じる・はみ出し・片付いた
        .sensoryFeedback(trigger: model.pressTick) { _, _ in model.hapticsOn ? .selection : nil }
        .sensoryFeedback(trigger: model.grabTick) { _, _ in model.hapticsOn ? .impact(flexibility: .rigid, intensity: 0.7) : nil }
        .sensoryFeedback(trigger: model.missTick) { _, _ in model.hapticsOn ? .impact(flexibility: .soft, intensity: 0.4) : nil }
        .sensoryFeedback(trigger: model.landTick) { _, _ in model.hapticsOn ? .impact(weight: .light, intensity: 0.5) : nil }
        .sensoryFeedback(trigger: model.crashTick) { _, _ in model.hapticsOn ? .error : nil }
        .sensoryFeedback(trigger: model.sealTick) { _, _ in model.hapticsOn ? .impact(weight: .heavy) : nil }
        .sensoryFeedback(trigger: model.warnTick) { _, _ in model.hapticsOn ? .warning : nil }
        .sensoryFeedback(trigger: model.clearTick) { _, _ in model.hapticsOn ? .success : nil }
        .modifier(WideOverride(on: Launch.scene == "wide"))
        .task { await Launch.run(model) }
        .task { await model.purchases.load(); model.syncPro() }
        .onAppear { model.reduceMotion = reduceMotion }
        .onChange(of: reduceMotion) { _, v in model.reduceMotion = v }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, !model.still, !Launch.isDemo else { return }
            model.now = Date()
            model.save.refreshStreak(today: model.today, yesterday: model.yesterday)
        }
        .environment(\.locale, Lang.locale)
    }
}

/// 撮影の場面 wide だけ、広い画面の並べ方（size class regular）を強制する（Duo の内側は CI で描かれないため）
struct WideOverride: ViewModifier {
    let on: Bool
    func body(content: Content) -> some View {
        if on { content.environment(\.horizontalSizeClass, .regular) } else { content }
    }
}

struct SheetContent: View {
    let sheet: ActiveSheet

    var body: some View {
        switch sheet {
        case .rooms: RoomsSheet()
        case .result: ResultSheet()
        case .truck: TruckSheet()
        case .settings: SettingsSheet()
        case .paywall: PaywallSheet()
        }
    }
}

/// 起動の仕方：ふつう・撮影（-screenshotScene <名前>）・デモ（-demo）・UI テスト（-uiTestFresh）。
/// 撮影とデモは見本のデータで動かし、保存されたデータを書き換えない
@MainActor
enum Launch {
    /// 撮る画面の名前。後ろに _ja を付けると日本語で撮る（CI のシミュレータは英語のため）
    static var scene: String? {
        var value = UserDefaults.standard.string(forKey: "screenshotScene") ?? ""
        if value.hasSuffix("_ja") { value = String(value.dropLast(3)) }
        return value.isEmpty || value == "launch" ? nil : value
    }

    static var forcesJapanese: Bool {
        UserDefaults.standard.string(forKey: "screenshotScene")?.hasSuffix("_ja") ?? false
    }

    static var isDemo: Bool { ProcessInfo.processInfo.arguments.contains("-demo") }
    static var isFreshUITest: Bool { ProcessInfo.processInfo.arguments.contains("-uiTestFresh") }

    static let shared: AppModel = makeModel()

    /// 撮影の日（決まった日にして、今日の部屋が毎回同じになるように）
    static func stageDate() -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 25, hour: 8, minute: 30)) ?? Date()
    }

    static func makeModel() -> AppModel {
        Lang.forcedJapanese = forcesJapanese
        if isFreshUITest {
            for key in [SaveData.key, "onboarded", "sound", "haptics", "paywallOffered"] {
                UserDefaults.standard.removeObject(forKey: key)
            }
            let model = AppModel(persists: false, now: stageDate())
            model.soundOn = false
            model.forceGrab = true
            return model
        }
        guard isDemo || scene != nil else { return AppModel() }
        let model = AppModel(persists: false, now: stageDate())
        model.still = scene != nil
        let name = scene ?? ""
        model.onboarded = !name.hasPrefix("onboarding")
        model.onboardingPage = name == "onboarding2" ? 1 : (name == "onboarding3" ? 2 : 0)
        if name != "empty" && !name.hasPrefix("onboarding") {
            model.save = sampleSave(model)
        }
        return model
    }

    /// 見本：遊んで 5 日目くらい
    static func sampleSave(_ model: AppModel) -> SaveData {
        var s = SaveData()
        for (n, stars, boxes, saved) in [(1, 3, 3, 1500), (2, 2, 4, 900), (3, 3, 3, 1500), (4, 1, 6, 300), (5, 2, 5, 1100), (6, 3, 4, 1500), (7, 2, 5, 600)] {
            s.best["room-\(n)"] = RoomBest(stars: stars, boxes: boxes, savedYen: saved)
        }
        s.totalSaved = 8_400
        s.roomsCleared = 11
        s.brokenTotal = 4
        s.packed = Set(ItemKind.allCases.prefix(23))
        s.streak = 4
        s.bestStreak = 6
        s.lastDaily = model.yesterday
        for (i, v) in [900, 1500, 0, 1100, 1800, 1200].enumerated() where v > 0 {
            s.daily[Days.offset(model.now, days: -(6 - i), calendar: model.calendar)] = v
        }
        return s
    }

    static func run(_ model: AppModel) async {
        if isDemo {
            await Demo.play(model)
            return
        }
        guard let scene else { return }
        let sc = model.scene
        func wait(_ ms: Int) async { try? await Task.sleep(for: .milliseconds(ms)) }
        if scene.hasPrefix("onboarding") { return }
        // ふつうは部屋 3（狭い台所）で、箱 1 つ閉じたあと
        let room = Room.numbered(3)
        if scene == "daily" { model.start(model.dailyRoom) } else { model.start(room) }
        await wait(300)
        switch scene {
        case "play", "wide", "gold":
            if scene == "gold" { model.proOverride = true; model.save.skin = .gold; model.start(Room.numbered(30)) }
            model.stage(closed: [[.pot, .riceCooker, .kettle, .glass]], queueUsed: 6)
            sc.placeInBox([.plate, .bowl, .bowl])
            sc.setAim(150)
        case "holding":
            model.stage(closed: [[.pot, .riceCooker, .kettle, .glass]], queueUsed: 6)
            sc.placeInBox([.riceCooker, .pot])
            await wait(500)
            sc.stageHold(.teapot, x: 330, lowered: 60)
            model.craneChanged()
        case "overflow":
            sc.placeInBox([.riceCooker, .pot, .kettle])
            await wait(500)
            sc.stageHold(.lamp, x: 305, lowered: 0)
            model.releaseClaw()
            await wait(900)
            model.sealBox()
        case "crash":
            sc.placeInBox([.pot, .riceCooker])
            await wait(400)
            sc.stageHold(.teapot, x: 400, lowered: 0)
            model.releaseClaw()
        case "sealed":
            sc.placeInBox([.pot, .riceCooker, .glass, .mug])
            await wait(900)
            model.stage(closed: [[.kettle, .pan, .plate, .plate]], queueUsed: 8)
            model.sealBox()
        case "result":
            model.stage(closed: [[.pot, .riceCooker, .kettle], [.teapot, .glass, .mug, .plate], [.bowl, .jar, .snowGlobe]], broken: 1)
            model.stageResult(Rules.Outcome(boxes: 3, par: 3, broken: 1, keepsakeOnTop: true))
        case "rooms": model.activeSheet = .rooms
        case "truck", "empty": model.activeSheet = .truck
        case "settings": model.activeSheet = .settings
        case "paywall": model.activeSheet = .paywall
        case "daily": break
        default: break
        }
        // 物理が落ち着いたら描画を止める（撮影の絵を止める。動き続ける描画が右上の黒い丸の原因になる）
        await wait(1800)
        model.frozen = sc.freezeImage()
        model.scenePaused = true
    }
}

/// デモの再生（YouTube の録画用。人の操作なしで約 18 秒）
/// 部屋 1 → ノートパソコンを低く下ろす → 靴の箱を隣へ → マグを高い所から放して割れる → 箱を閉じてトラックへ → 結果
@MainActor
enum Demo {
    static func play(_ model: AppModel) async {
        func wait(_ s: Double) async { try? await Task.sleep(for: .milliseconds(Int(s * 1000))) }
        model.soundOn = true
        model.onboarded = true
        model.forceGrab = true
        model.start(Room.numbered(1))
        await wait(0.8)
        model.showBanner(Room.numbered(1).title, Room.numbered(1).story)
        let sc = model.scene

        func glide(from: CGFloat, to: CGFloat) async {
            for i in 1...10 {
                model.moveClaw(to: from + (to - from) * CGFloat(i) / 10)
                await wait(0.05)
            }
        }
        func carry(_ kind: ItemKind, to x: CGFloat, hold: Double) async {
            guard let from = sc.position(of: kind) else { return }
            await glide(from: sc.aimX, to: from)
            model.pressClaw()
            model.releaseClaw()
            await wait(1.9)
            await glide(from: sc.aimX, to: x)
            model.pressClaw()
            await wait(hold)
            model.releaseClaw()
            await wait(1.0)
        }
        await carry(.laptop, to: 330, hold: 1.4)
        await carry(.shoeBox, to: 400, hold: 1.0)
        await carry(.mug, to: 300, hold: 0)
        await wait(0.8)
        // 割れた後は落ち着いてから閉じる
        model.sealBox()
        await wait(2.0)
        model.stageResult(Rules.Outcome(boxes: 2, par: 3, broken: 1, keepsakeOnTop: true))
        await wait(3.0)
    }
}
