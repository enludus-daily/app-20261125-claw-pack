import SpriteKit
import SwiftUI

/// 遊ぶ画面。上に部屋の名前とトラック、まん中に部屋（SpriteKit）、下に大きなボタン 2 つを固定。
/// 広い画面（size class regular。iPhone Duo の内側など）は、左に部屋、右にトラックの荷台と記録を並べる
struct PlayView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var hSize

    private var wide: Bool { hSize == .regular }

    var body: some View {
        ZStack(alignment: .top) {
            MorningBackground()
            if wide {
                VStack(spacing: Space.m) {
                    header
                    GeometryReader { geo in
                        HStack(alignment: .top, spacing: Space.m) {
                            roomCard
                                .frame(width: geo.size.width * 0.6)
                            ScrollView {
                                VStack(spacing: Space.s) {
                                    VStack(spacing: Space.s) { stats }
                                    UpNext(items: model.upcoming)
                                    TruckBed(boxes: model.closedBoxes, vertical: true)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(.horizontal, Space.l)
                .padding(.top, Space.s)
            } else {
                VStack(spacing: Space.s) {
                    header
                    statsRow
                    roomCard
                    UpNext(items: model.upcoming)
                    Spacer(minLength: 0)
                    TruckBed(boxes: model.closedBoxes, vertical: false)
                }
                .padding(.horizontal, Space.m)
                .padding(.top, Space.s)
            }
            if let b = model.banner {
                BannerView(banner: b)
                    .padding(.horizontal, Space.l)
                    .padding(.top, wide ? 70 : 118)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .allowsHitTesting(false)
                    .zIndex(5)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { controls }
    }

    // MARK: 上

    private var header: some View {
        HStack(spacing: Space.s) {
            Button { model.activeSheet = .rooms } label: {
                Image(systemName: "square.grid.3x3.fill")
                    .font(.system(size: 18, weight: .bold))
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.paper).shadow(color: .cardboardDeep.opacity(0.25), radius: 0, y: 2))
            }
            .accessibilityLabel(tr("部屋の一覧", "Rooms"))
            .accessibilityIdentifier("main.rooms")
            Spacer(minLength: 0)
            TapeStrip {
                VStack(spacing: 0) {
                    Text(model.room.day == nil ? trf("部屋 %d", "Room %d", model.room.number) : tr("今日の部屋", "Today's room"))
                        .font(Type2.body(11, .bold))
                        .foregroundStyle(Color.cardboardDeep)
                    Text(model.room.title)
                        .font(Type2.head(17))
                        .foregroundStyle(Color.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 0)
            Button { model.activeSheet = .truck } label: {
                Image(systemName: "truck.box.fill")
                    .font(.system(size: 17, weight: .bold))
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.paper).shadow(color: .cardboardDeep.opacity(0.25), radius: 0, y: 2))
            }
            .accessibilityLabel(tr("トラックと記録", "Truck & records"))
            .accessibilityIdentifier("main.truck")
            Button { model.activeSheet = .settings } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 17, weight: .bold))
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.paper).shadow(color: .cardboardDeep.opacity(0.25), radius: 0, y: 2))
            }
            .accessibilityLabel(tr("設定", "Settings"))
            .accessibilityIdentifier("main.settings")
        }
        .foregroundStyle(Color.cardboardDeep)
    }

    private var statsRow: some View {
        HStack(spacing: Space.s) { stats }
    }

    @ViewBuilder
    private var stats: some View {
            StatSticker(title: tr("箱", "Boxes"), value: "\(model.boxesUsed)", sub: trf("目安 %d", "par %d", model.par), tint: model.boxesUsed > model.par ? .alert : .ink)
            StatSticker(title: tr("残り", "Left"), value: "\(model.remaining)", sub: tr("個", "items"), tint: .ink)
            StatSticker(title: tr("割れ", "Broken"), value: "\(model.broken)", sub: model.broken == 0 ? tr("なし", "none") : trf("−%@", "−%@", yen(model.broken * Rules.breakPenalty)), tint: model.broken > 0 ? .alert : .good)
    }

    // MARK: 部屋

    private var roomCard: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = w * Rules.sceneHeight / Rules.sceneWidth
            ZStack {
                if let frozen = model.frozen {
                    Image(uiImage: frozen).resizable()
                } else {
                    SpriteView(scene: model.scene, isPaused: model.scenePaused, options: [.allowsTransparency])
                }
            }
            .frame(width: w, height: h)
            .clipShape(RoundedRectangle(cornerRadius: Radius.room, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.room, style: .continuous)
                    .strokeBorder(Color.paper, lineWidth: 5)
                    .allowsHitTesting(false)
            }
            .shadow(color: .cardboardDeep.opacity(0.22), radius: 0, x: 0, y: 5)
            .contentShape(Rectangle())
            // 指でなぞってクレーンを左右に動かす
            .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                model.moveClaw(to: v.location.x / max(1, w) * Rules.sceneWidth)
            })
            .accessibilityElement()
            .accessibilityLabel(tr("部屋とクレーン。なぞるとクレーンが動く", "The room and the crane. Drag to move the crane"))
            .accessibilityValue(trf("床に %d 個、箱に %d 個", "%d on the floor, %d in the box", model.floorCount, model.inBoxCount))
            .accessibilityAdjustableAction { dir in
                model.moveClaw(to: model.scene.aimX + (dir == .increment ? 30 : -30))
            }
        }
        .aspectRatio(Rules.sceneWidth / Rules.sceneHeight, contentMode: .fit)
    }

    // MARK: 下

    private var controls: some View {
        HStack(spacing: Space.m) {
            Button(action: model.sealBox) {
                Label(tr("箱を閉じる", "Seal box"), systemImage: "shippingbox.fill")
                    .labelStyle(.titleAndIcon)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .buttonStyle(ChunkyButtonStyle(fill: .cardboard, text: .paper))
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("main.seal")
            ClawButton()
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, Space.l)
        .padding(.top, Space.m)
        .padding(.bottom, Space.s)
        .background {
            Color(hex: Palette.skyBottom).opacity(0.94)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }
}

/// クレーンのボタン：押すと下ろしてつかむ。持っているときは、押しているあいだ下がり、離すと放す
struct ClawButton: View {
    @Environment(AppModel.self) private var model
    @State private var down = false

    private var title: String {
        switch model.crane {
        case .idle: tr("つかむ", "Grab")
        case .descending, .lifting, .busy: tr("……", "…")
        case .holding: tr("押して下げる", "Hold to lower")
        case .lowering: tr("離して放す", "Let go to drop")
        }
    }

    private var icon: String {
        switch model.crane {
        case .holding, .lowering: "arrow.down.to.line"
        default: "hand.point.down.fill"
        }
    }

    var body: some View {
        Label(title, systemImage: icon)
            .labelStyle(.titleAndIcon)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .font(Type2.head(17))
            .foregroundStyle(Color.ink)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background {
                RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                    .fill(Color.crane)
                    .shadow(color: .craneDeep.opacity(0.7), radius: 0, x: 0, y: down ? 1 : 4)
            }
            .offset(y: down ? 3 : 0)
            .animation(.spring(response: 0.18, dampingFraction: 0.6), value: down)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !down else { return }
                    down = true
                    model.pressClaw()
                }
                .onEnded { _ in
                    down = false
                    model.releaseClaw()
                })
            .accessibilityElement()
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(title)
            .accessibilityIdentifier("main.claw")
            .accessibilityAction {
                model.pressClaw()
                if model.crane == .lowering {
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(900))
                        model.releaseClaw()
                    }
                }
            }
    }
}

/// 数字のシール（大きな数字。小さな灰色の文字を明るい地に置かない）
struct StatSticker: View {
    let title: String
    let value: String
    let sub: String
    var tint: Color = .ink

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(title)
                .font(Type2.body(13, .heavy))
                .foregroundStyle(Color.cardboardDeep)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(value)
                .font(Type2.number(28))
                .foregroundStyle(tint)
                .contentTransition(.numericText())
                .lineLimit(1)
                .fixedSize()
            Text(sub)
                .font(Type2.body(12, .bold))
                .foregroundStyle(Color.ink.opacity(0.75))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: Radius.tag, style: .continuous)
                .fill(Color.paper)
                .shadow(color: .cardboardDeep.opacity(0.18), radius: 0, y: 2)
                .allowsHitTesting(false)
        }
        .accessibilityElement(children: .combine)
    }
}

/// トラックの荷台（閉じた箱が並ぶ）
struct TruckBed: View {
    let boxes: [[ItemKind]]
    var vertical: Bool

    var body: some View {
        Group {
            if vertical {
                VStack(alignment: .leading, spacing: Space.s) {
                    Text(tr("トラックの荷台", "Truck bed"))
                        .font(Type2.head(15))
                        .foregroundStyle(Color.ink)
                    if boxes.isEmpty {
                        Text(tr("閉じた箱がここに並ぶ。少ないほどトラック代が浮く", "Sealed boxes line up here. Fewer boxes, cheaper truck"))
                            .font(Type2.body(14))
                            .foregroundStyle(Color.ink.opacity(0.8))
                    }
                    ForEach(Array(boxes.enumerated()), id: \.offset) { i, items in
                        HStack(spacing: Space.s) {
                            SealedBox(number: i + 1, label: BoxLabel.dominant(items), size: 54)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 4) { ForEach(Array(items.enumerated()), id: \.offset) { _, k in ItemIcon(kind: k, height: 26) } }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardboardPanel()
            } else {
                HStack(spacing: Space.s) {
                    Image(systemName: "truck.box")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.cardboardDeep)
                    if boxes.isEmpty {
                        Text(tr("閉じた箱はトラックへ。少ないほど代金が浮く", "Sealed boxes go to the truck. Fewer is cheaper"))
                            .font(Type2.body(13))
                            .foregroundStyle(Color.ink.opacity(0.8))
                            .lineLimit(2)
                    } else {
                        ForEach(Array(boxes.enumerated()), id: \.offset) { i, items in
                            SealedBox(number: i + 1, label: BoxLabel.dominant(items), size: 40)
                                .transition(.move(edge: .leading).combined(with: .opacity))
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, Space.m)
                .padding(.vertical, 8)
                .background {
                    RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                        .fill(Color.paper.opacity(0.85))
                        .allowsHitTesting(false)
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: boxes.count)
    }
}

/// テープを貼った箱（小さい絵）
struct SealedBox: View {
    let number: Int
    let label: BoxLabel
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.cardboard)
                .overlay { RoundedRectangle(cornerRadius: 4).strokeBorder(Color.cardboardDeep, lineWidth: 1.5) }
            Rectangle().fill(Color.tape).frame(width: size * 0.22)
            VStack(spacing: 0) {
                Text(label.text)
                    .font(Type2.marker(size * 0.24))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text("#\(number)")
                    .font(Type2.marker(size * 0.22))
            }
            .foregroundStyle(Color.ink)
            .padding(.horizontal, 2)
        }
        .frame(width: size, height: size * 0.8)
        .accessibilityElement()
        .accessibilityLabel(trf("箱 %d %@", "Box %d %@", number, label.text))
    }
}

struct BannerView: View {
    let banner: Banner

    var body: some View {
        let color: Color = switch banner.tint {
        case .info: .ink
        case .good: .good
        case .alert: .alert
        }
        VStack(spacing: 2) {
            Text(banner.title)
                .font(Type2.head(17))
                .foregroundStyle(color)
            Text(banner.detail)
                .font(Type2.body(14))
                .foregroundStyle(Color.ink)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, Space.l)
        .padding(.vertical, Space.m)
        .frame(maxWidth: 420)
        .background {
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .fill(Color.paper)
                .overlay { RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(color.opacity(0.5), lineWidth: 2) }
                .shadow(color: .cardboardDeep.opacity(0.25), radius: 0, y: 3)
        }
        .accessibilityElement(children: .combine)
    }
}

/// 次に部屋へ来る物（3 つ先まで。大きい物を待つか、いま詰めるかを考えるため）
struct UpNext: View {
    let items: [ItemKind]

    var body: some View {
        HStack(spacing: Space.s) {
            Text(tr("次に来る物", "Coming next"))
                .font(Type2.body(13, .heavy))
                .foregroundStyle(Color.cardboardDeep)
                .lineLimit(1)
                .fixedSize()
            if items.isEmpty {
                Text(tr("もう出てこない。床の物で最後", "Nothing more. The floor is all that's left"))
                    .font(Type2.body(13, .bold))
                    .foregroundStyle(Color.ink.opacity(0.8))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            } else {
                ForEach(Array(items.enumerated()), id: \.offset) { i, k in
                    VStack(spacing: 2) {
                        ItemIcon(kind: k, height: 30)
                            .frame(height: 32)
                        HStack(spacing: 2) {
                            if k.spec.fragile { Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Color.alert) }
                            if k.spec.keepsake { Image(systemName: "heart.fill").foregroundStyle(Color.good) }
                            if k.spec.weight >= 3 { Image(systemName: "scalemass.fill").foregroundStyle(Color.cardboardDeep) }
                        }
                        .font(.system(size: 10, weight: .bold))
                        .frame(height: 11)
                    }
                    .frame(maxWidth: .infinity)
                    .opacity(1 - Double(i) * 0.2)
                }
            }
        }
        .padding(.horizontal, Space.m)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .fill(Color.paper.opacity(0.85))
                .allowsHitTesting(false)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tr("次に来る物", "Coming next"))
        .accessibilityValue(items.map(\.name).joined(separator: ", "))
    }
}
