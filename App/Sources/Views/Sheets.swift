import StoreKit
import SwiftUI

/// シートの上の見出し（マジックの見出しと、閉じるボタン）
struct SheetHeader: View {
    @Environment(AppModel.self) private var model
    let title: String
    var sub: String? = nil

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Type2.head(24))
                    .foregroundStyle(Color.ink)
                if let sub {
                    Text(sub)
                        .font(Type2.body(14))
                        .foregroundStyle(Color.ink.opacity(0.8))
                }
            }
            Spacer()
            Button {
                if model.activeSheet == .result { model.resultClosed() }
                model.activeSheet = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(Color.cardboardDeep)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.cardboardSoft.opacity(0.6)))
            }
            .accessibilityLabel(tr("閉じる", "Close"))
            .accessibilityIdentifier("main.close")
        }
    }
}

// MARK: 部屋の一覧

struct RoomsSheet: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                SheetHeader(title: tr("引っ越しの部屋", "Rooms to pack"), sub: trf("星 %d / %d", "%d of %d stars", model.save.totalStars, Room.all.count * 3))
                dailyCard
                Text(tr("決まった部屋", "Rooms"))
                    .font(Type2.head(17))
                    .foregroundStyle(Color.ink)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: Space.s)], spacing: Space.s) {
                    ForEach(Room.all) { room in
                        RoomTile(room: room, best: model.save.best[room.id], locked: room.isPro && !model.isPro)
                            .onTapGesture { model.play(room: room.number) }
                            .accessibilityAddTraits(.isButton)
                            .accessibilityIdentifier(room.number == 1 ? "main.room1" : "room.\(room.number)")
                    }
                }
                if !model.isPro {
                    Button { model.activeSheet = .paywall } label: {
                        Label(tr("Pro で部屋を 60 に", "Get 60 rooms with Pro"), systemImage: "lock.open.fill")
                    }
                    .buttonStyle(ChunkyButtonStyle())
                }
            }
            .padding(Space.l)
        }
        .background(Color(hex: Palette.skyBottom).ignoresSafeArea())
    }

    private var dailyCard: some View {
        let room = model.dailyRoom
        return Button(action: model.playDaily) {
            HStack(spacing: Space.m) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tr("今日の部屋", "Today's room"))
                        .font(Type2.head(19))
                    Text(room.title)
                        .font(Type2.body(15))
                    HStack(spacing: Space.s) {
                        Label(trf("%d 日つづいた", "%d-day streak", model.save.streak), systemImage: "flame.fill")
                        if let v = model.save.daily[model.today] {
                            Label(trf("今日 %@", "Today %@", yen(v)), systemImage: "checkmark.seal.fill")
                        }
                    }
                    .font(Type2.body(13, .bold))
                    .foregroundStyle(Color.cardboardDeep)
                }
                .foregroundStyle(Color.ink)
                Spacer()
                HStack(spacing: -8) {
                    ForEach(Array(room.items.prefix(3).enumerated()), id: \.offset) { _, k in ItemIcon(kind: k, height: 34) }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardboardPanel(Color(hex: 0xFFF1C9))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("main.daily")
    }
}

struct RoomTile: View {
    let room: Room
    let best: RoomBest?
    let locked: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text("\(room.number)")
                .font(Type2.marker(26))
                .foregroundStyle(locked ? Color.cardboardDeep.opacity(0.5) : Color.ink)
            Text(room.title)
                .font(Type2.body(11, .bold))
                .foregroundStyle(Color.ink.opacity(locked ? 0.5 : 0.9))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
                .frame(height: 28)
            if locked {
                Image(systemName: "lock.fill").font(.system(size: 13, weight: .bold)).foregroundStyle(Color.cardboardDeep.opacity(0.6))
            } else {
                Stars(count: best?.stars ?? 0, size: 12)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: Radius.tag, style: .continuous)
                .fill(best != nil ? Color.cardboardSoft : Color.paper)
                .overlay { RoundedRectangle(cornerRadius: Radius.tag).strokeBorder(Color.cardboardDeep.opacity(0.3), lineWidth: 1) }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: 結果

struct ResultSheet: View {
    @Environment(AppModel.self) private var model
    @State private var shown = 0

    var body: some View {
        let r = model.result ?? Rules.Outcome(boxes: 3, par: 3, broken: 0, keepsakeOnTop: true)
        let room = model.resultRoom ?? model.room
        ScrollView {
            VStack(spacing: Space.l) {
                SheetHeader(title: tr("部屋が空っぽになった", "Room cleared"), sub: room.title)
                Stars(count: shown, size: 40)
                    .scaleEffect(shown > 0 ? 1 : 0.6)
                VStack(spacing: 4) {
                    Text(tr("浮いたトラック代", "Saved on the truck"))
                        .font(Type2.body(15, .bold))
                        .foregroundStyle(Color.cardboardDeep)
                    Text(yen(r.savedYen))
                        .font(Type2.number(56))
                        .foregroundStyle(Color.good)
                        .contentTransition(.numericText())
                }
                VStack(spacing: Space.s) {
                    line(tr("使った箱", "Boxes used"), "\(r.boxes)", trf("目安 %d", "par %d", r.par), bad: r.boxes > r.par)
                    line(tr("割れた物", "Broken"), "\(r.broken)", r.broken == 0 ? tr("ひとつもない", "none") : trf("−%@", "−%@", yen(r.broken * Rules.breakPenalty)), bad: r.broken > 0)
                    line(tr("たいせつな物", "Keepsake"), r.keepsakeOnTop ? tr("一番上", "on top") : tr("埋もれた", "buried"), r.keepsakeOnTop ? trf("+%@", "+%@", yen(Rules.keepsakeBonus)) : "", bad: !r.keepsakeOnTop)
                }
                .cardboardPanel()
                Text(tr("箱 1 つで ¥600。何も考えずに詰めた箱の数（目安＋2）より少ないぶんが浮く", "Each box costs ¥600. You save on every box below a careless pack (par + 2)"))
                    .font(Type2.body(13))
                    .foregroundStyle(Color.ink.opacity(0.8))
                    .multilineTextAlignment(.center)
                HStack(spacing: Space.m) {
                    ShareLink(item: model.shareText) {
                        Label(tr("共有", "Share"), systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(ChunkyButtonStyle(fill: .paper, text: .ink))
                    .frame(maxWidth: .infinity)
                    Button {
                        model.resultClosed()
                        model.nextRoom()
                    } label: {
                        Label(tr("次の部屋", "Next room"), systemImage: "arrow.right")
                    }
                    .buttonStyle(ChunkyButtonStyle())
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("main.next")
                }
                Button(tr("もう一度この部屋", "Pack this room again")) {
                    model.activeSheet = nil
                    model.restart()
                }
                .font(Type2.body(15, .bold))
                .foregroundStyle(Color.cardboardDeep)
            }
            .padding(Space.l)
        }
        .background(Color(hex: Palette.skyBottom).ignoresSafeArea())
        .task {
            if model.still || model.reduceMotion { shown = r.stars; return }
            for i in 1...max(1, r.stars) where i <= r.stars {
                try? await Task.sleep(for: .milliseconds(260))
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { shown = i }
                model.play(.star)
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: shown)
    }

    private func line(_ title: String, _ value: String, _ sub: String, bad: Bool) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(Type2.body(16, .bold)).foregroundStyle(Color.ink)
            Spacer()
            Text(value).font(Type2.number(24)).foregroundStyle(bad ? Color.alert : Color.ink)
            Text(sub).font(Type2.body(13, .bold)).foregroundStyle(bad ? Color.alert : Color.good).frame(minWidth: 64, alignment: .trailing)
        }
    }
}

// MARK: トラックと記録・荷物の図鑑

struct TruckSheet: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let s = model.save
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                SheetHeader(title: tr("トラックと記録", "Truck & records"))
                if s.roomsCleared == 0 {
                    VStack(alignment: .leading, spacing: Space.s) {
                        Text(tr("まだ荷台は空っぽ", "The truck is still empty"))
                            .font(Type2.head(18))
                        Text(tr("部屋をひとつ片付けると、浮いたトラック代がここにたまる。まずは「つかむ」から", "Clear a room and your savings pile up here. Start with Grab"))
                            .font(Type2.body(15))
                        Button { model.activeSheet = nil } label: { Text(tr("部屋に戻る", "Back to the room")) }
                            .buttonStyle(ChunkyButtonStyle())
                    }
                    .foregroundStyle(Color.ink)
                    .cardboardPanel()
                }
                VStack(spacing: 2) {
                    Text(tr("浮いたトラック代の合計", "Total saved on trucks"))
                        .font(Type2.body(15, .bold))
                        .foregroundStyle(Color.cardboardDeep)
                    Text(yen(s.totalSaved))
                        .font(Type2.number(48))
                        .foregroundStyle(Color.good)
                }
                .frame(maxWidth: .infinity)
                .cardboardPanel(Color(hex: 0xF2FAF4))
                HStack(spacing: Space.s) {
                    bigNumber("\(s.roomsCleared)", tr("片付けた部屋", "rooms cleared"))
                    bigNumber("\(s.boxesSentTotal)", tr("送った箱", "boxes sent"))
                    bigNumber("\(s.streak)", tr("日つづいた", "day streak"))
                    bigNumber("\(s.brokenTotal)", tr("割れた", "broken"))
                }
                weekStrip
                Text(trf("荷物の図鑑 %d / %d", "Packed items %d / %d", s.packed.count, ItemKind.allCases.count))
                    .font(Type2.head(17))
                    .foregroundStyle(Color.ink)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: Space.s)], spacing: Space.s) {
                    ForEach(ItemKind.allCases) { k in
                        let got = s.packed.contains(k)
                        HStack(spacing: Space.s) {
                            ItemIcon(kind: k, height: 34, dimmed: !got)
                                .frame(width: 52)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(got ? k.name : "？？？")
                                    .font(Type2.body(14, .heavy))
                                    .foregroundStyle(Color.ink)
                                Text(got ? k.memory : tr("詰めると思い出が読める", "Pack it to read its story"))
                                    .font(Type2.body(12, .medium))
                                    .foregroundStyle(Color.ink.opacity(0.8))
                                    .fixedSize(horizontal: false, vertical: true)
                                if k.spec.fragile || k.spec.keepsake {
                                    Text(k.spec.keepsake ? tr("たいせつ", "Keepsake") : tr("割れ物", "Fragile"))
                                        .font(Type2.body(10, .heavy))
                                        .foregroundStyle(k.spec.keepsake ? Color.good : Color.alert)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: Radius.tag).fill(Color.paper))
                    }
                }
            }
            .padding(Space.l)
        }
        .background(Color(hex: Palette.skyBottom).ignoresSafeArea())
    }

    private func bigNumber(_ v: String, _ label: String) -> some View {
        VStack(spacing: 0) {
            Text(v).font(Type2.number(26)).foregroundStyle(Color.ink)
            Text(label).font(Type2.body(12, .bold)).foregroundStyle(Color.cardboardDeep).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: Radius.tag).fill(Color.paper))
    }

    /// この 7 日の毎日の部屋（浮いた額を箱の高さで）
    private var weekStrip: some View {
        let days = (0..<7).map { Days.offset(model.now, days: -(6 - $0), calendar: model.calendar) }
        let values = days.map { model.save.daily[$0] }
        let top = max(1, values.compactMap { $0 }.max() ?? 1)
        return VStack(alignment: .leading, spacing: Space.s) {
            Text(tr("この 7 日の「今日の部屋」", "Today's room, last 7 days"))
                .font(Type2.head(15))
                .foregroundStyle(Color.ink)
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(days.enumerated()), id: \.offset) { i, d in
                    VStack(spacing: 4) {
                        if let v = values[i] {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.cardboard)
                                .overlay(alignment: .top) { Rectangle().fill(Color.tape).frame(height: 5) }
                                .frame(height: 14 + 56 * CGFloat(v) / CGFloat(top))
                        } else {
                            RoundedRectangle(cornerRadius: 3)
                                .strokeBorder(Color.cardboardDeep.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                                .frame(height: 14)
                        }
                        Text(String(d.suffix(2)))
                            .font(Type2.body(12, .bold))
                            .foregroundStyle(Color.ink.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 96, alignment: .bottom)
            .accessibilityElement()
            .accessibilityLabel(trf("この 7 日で %d 日遊んだ", "Played %d of the last 7 days", values.compactMap { $0 }.count))
        }
        .cardboardPanel()
    }
}

extension SaveData {
    var boxesSentTotal: Int { best.values.reduce(0) { $0 + $1.boxes } }
}

// MARK: 設定

struct SettingsSheet: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                SheetHeader(title: tr("設定", "Settings"))
                VStack(spacing: Space.m) {
                    Toggle(tr("効果音", "Sound effects"), isOn: $model.soundOn)
                    Toggle(tr("振動", "Haptics"), isOn: $model.hapticsOn)
                    Toggle(isOn: Binding(get: { model.save.steady }, set: { v in
                        if model.isPro { model.save.steady = v; if model.persists { model.save.store() } } else { model.activeSheet = .paywall }
                    })) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tr("ゆらぎなしの練習（Pro）", "Steady claw practice (Pro)"))
                            Text(tr("真ん中をつかめば必ずつかめる", "Center grabs never slip"))
                                .font(Type2.body(12, .medium))
                                .foregroundStyle(Color.ink.opacity(0.75))
                        }
                    }
                }
                .font(Type2.body(16))
                .tint(Color.good)
                .foregroundStyle(Color.ink)
                .cardboardPanel()

                VStack(alignment: .leading, spacing: Space.s) {
                    Text(tr("クレーンのつめ", "Claw color"))
                        .font(Type2.head(16))
                    HStack(spacing: Space.s) {
                        ForEach(ClawSkin.allCases) { skin in
                            Button { model.setSkin(skin) } label: {
                                VStack(spacing: 4) {
                                    Circle().fill(Color(hex: skin.color)).frame(width: 34, height: 34)
                                        .overlay { if model.save.skin == skin { Image(systemName: "checkmark").font(.system(size: 14, weight: .heavy)).foregroundStyle(Color.ink) } }
                                    Text(skin.name).font(Type2.body(12, .bold)).lineLimit(1).minimumScaleFactor(0.7)
                                    if skin.isPro && !model.isPro { Image(systemName: "lock.fill").font(.system(size: 10)) }
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .foregroundStyle(Color.ink)
                .cardboardPanel()

                VStack(alignment: .leading, spacing: Space.m) {
                    Button(tr("遊び方をもう一度見る", "Show how to play again")) {
                        model.activeSheet = nil
                        model.onboardingPage = 0
                        model.onboarded = false
                    }
                    Button(tr("この部屋をやり直す", "Restart this room")) {
                        model.activeSheet = nil
                        model.restart()
                    }
                    Button(model.isPro ? tr("Pro を持っています", "You have Pro") : tr("Pro を見る", "See Pro")) { model.activeSheet = .paywall }
                }
                .font(Type2.body(16, .bold))
                .foregroundStyle(Color.cardboardDeep)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardboardPanel()

                Text(tr("記録はこの端末の中だけに残ります。外に送るデータはありません。", "Your records stay on this device. Nothing is sent anywhere."))
                    .font(Type2.body(13))
                    .foregroundStyle(Color.ink.opacity(0.8))
            }
            .padding(Space.l)
        }
        .background(Color(hex: Palette.skyBottom).ignoresSafeArea())
    }
}

// MARK: Pro

struct PaywallSheet: View {
    @Environment(AppModel.self) private var model
    @State private var buying = false
    @State private var message: String?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.l) {
                    SheetHeader(title: tr("つかんで荷造り Pro", "Claw & Pack Pro"), sub: tr("一度買えば、ずっと。", "Buy once, keep forever."))
                    HStack(spacing: -6) {
                        ForEach([ItemKind.records, .teapot, .globe, .ukulele, .snowGlobe], id: \.self) { ItemIcon(kind: $0, height: 46) }
                    }
                    .frame(maxWidth: .infinity)
                    VStack(alignment: .leading, spacing: Space.m) {
                        perk("square.grid.3x3.fill", tr("部屋が 24 → 60 に", "Rooms 24 → 60"), tr("陶芸家の台所、ガラス作家の棚、船の倉庫…割れ物の多い 36 部屋", "Potter's kitchen, glassmaker's shelf, boat shed… 36 trickier rooms"))
                        perk("hand.raised.fill", tr("ゆらぎなしの練習", "Steady claw practice"), tr("真ん中をつかめば必ずつかめる。詰め方だけを考えたい日に", "Center grabs never slip, so you can focus on packing"))
                        perk("paintpalette.fill", tr("つめの色 2 つ", "2 claw finishes"), tr("金のつめ・木のつめ", "Gold and oak"))
                        perk("heart.fill", tr("毎日の部屋はずっと無料", "Today's room stays free"), tr("無料の 24 部屋と毎日の部屋は、Pro なしで遊べる", "All 24 base rooms and the daily room stay free"))
                    }
                    .cardboardPanel()
                    Text(tr("1 部屋あたり約 13 円。似た箱詰め・クレーンのゲームの買い切り（$2.99〜$9.99）より安くしています。", "About ¥13 per room. Priced below similar packing and claw games ($2.99–$9.99)."))
                        .font(Type2.body(13))
                        .foregroundStyle(Color.ink.opacity(0.85))
                    if let message {
                        Text(message).font(Type2.body(14, .bold)).foregroundStyle(Color.alert)
                    }
                }
                .padding(Space.l)
            }
            VStack(spacing: Space.s) {
                Button {
                    Task { await buy() }
                } label: {
                    Text(buyTitle)
                }
                .buttonStyle(ChunkyButtonStyle())
                .disabled(buying || model.isPro)
                .accessibilityIdentifier("main.buy")
                Button(tr("購入を復元", "Restore purchase")) {
                    Task {
                        await model.purchases.restore()
                        model.syncPro()
                        message = model.isPro ? nil : tr("復元できる購入が見つかりませんでした", "No purchase to restore was found")
                    }
                }
                .font(Type2.body(14, .bold))
                .foregroundStyle(Color.cardboardDeep)
            }
            .padding(.horizontal, Space.l)
            .padding(.vertical, Space.m)
            .background(Color(hex: Palette.skyBottom))
        }
        .background(Color(hex: Palette.skyBottom).ignoresSafeArea())
    }

    private var product: Product? { model.purchases.products.first { $0.id == AppModel.proID } }

    private var buyTitle: String {
        if model.isPro { return tr("Pro を持っています", "You have Pro") }
        if let p = product { return trf("%@ で Pro にする", "Get Pro for %@", p.displayPrice) }
        switch model.purchases.loadState {
        case .unavailable where !model.still: return tr("いまは買えません（あとで）", "Not available right now")
        default: return tr("¥480 で Pro にする", "Get Pro for ¥480")
        }
    }

    private func perk(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: Space.m) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.craneDeep)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Type2.head(16)).foregroundStyle(Color.ink)
                Text(detail).font(Type2.body(13, .medium)).foregroundStyle(Color.ink.opacity(0.8))
            }
        }
    }

    private func buy() async {
        guard let p = product else {
            message = tr("App Store につながりませんでした。電波のよい所で開き直してください", "Couldn't reach the App Store. Try again with a better connection")
            await model.purchases.load()
            return
        }
        buying = true
        let outcome = await model.purchases.purchase(p)
        buying = false
        model.syncPro()
        switch outcome {
        case .purchased: model.activeSheet = nil
        case .pending: message = tr("承認を待っています", "Waiting for approval")
        case .failed: message = tr("購入できませんでした。もう一度お試しください", "The purchase didn't go through. Please try again")
        case .cancelled: break
        }
    }
}
