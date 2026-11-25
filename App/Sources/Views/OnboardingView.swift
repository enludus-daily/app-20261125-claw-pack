import SwiftUI

/// 遊び方（3 ページ）。絵は部屋の物とクレーンの部品で描く
struct OnboardingView: View {
    @Environment(AppModel.self) private var model

    private struct Page {
        let title: String
        let body: String
    }

    private var pages: [Page] {
        [
            Page(title: tr("引っ越しの朝。部屋の物をクレーンでつかむ", "Moving day. Grab the room with a crane"),
                 body: tr("部屋をなぞってクレーンを動かし、「つかむ」。真ん中をつかむほど落としにくい。", "Drag across the room to move the crane, then tap Grab. Grab near the middle so it won't slip.")),
            Page(title: tr("箱の上で、押して下げて、離して放す", "Over the box: hold to lower, let go to drop"),
                 body: tr("割れ物は高い所から落とすと割れる。重い物の下にも入れない。縁からはみ出すと、ふたが閉まらない。", "Fragile things break if dropped from high up or crushed by heavy ones. Anything above the rim keeps the lid from closing.")),
            Page(title: tr("少ない箱で、トラック代が浮く", "Fewer boxes, cheaper truck"),
                 body: tr("大きい物から隅へ。たいせつな物は最後に一番上へ。毎日ひと部屋、だれが開いても同じ部屋が届く。記録は端末の中だけ。", "Big things first, into the corners. Keepsakes go on top, last. A new room every day, the same for everyone. Records stay on your device.")),
        ]
    }

    var body: some View {
        @Bindable var model = model
        let page = min(model.onboardingPage, pages.count - 1)
        ZStack {
            MorningBackground()
            VStack(spacing: Space.l) {
                HStack(spacing: 6) {
                    ForEach(0..<pages.count, id: \.self) { i in
                        Capsule().fill(i == page ? Color.cardboardDeep : Color.cardboardDeep.opacity(0.25))
                            .frame(width: i == page ? 26 : 8, height: 8)
                    }
                }
                .padding(.top, Space.l)
                .accessibilityHidden(true)
                Spacer(minLength: 0)
                illustration(page)
                    .frame(height: 230)
                    .id(page)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                VStack(spacing: Space.m) {
                    TapeStrip {
                        Text(pages[page].title)
                            .font(Type2.head(21))
                            .foregroundStyle(Color.ink)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(pages[page].body)
                        .font(Type2.body(16, .medium))
                        .foregroundStyle(Color.ink)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, Space.l)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Space.l)
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: Space.m) {
                if page < pages.count - 1 {
                    Button(tr("とばす", "Skip")) { finish() }
                        .buttonStyle(ChunkyButtonStyle(fill: .paper, text: .cardboardDeep))
                        .frame(maxWidth: .infinity)
                    Button(tr("次へ", "Next")) {
                        withAnimation(model.reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85)) { model.onboardingPage = page + 1 }
                    }
                    .buttonStyle(ChunkyButtonStyle())
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("main.onboardNext")
                } else {
                    Button(tr("部屋を片付けはじめる", "Start packing")) { finish() }
                        .buttonStyle(ChunkyButtonStyle())
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("main.onboardStart")
                }
            }
            .padding(.horizontal, Space.l)
            .padding(.bottom, Space.s)
        }
    }

    private func finish() {
        withAnimation(model.reduceMotion ? nil : .easeOut(duration: 0.35)) { model.onboarded = true }
        model.showBanner(model.room.title, model.room.story)
    }

    @ViewBuilder
    private func illustration(_ page: Int) -> some View {
        switch page {
        case 0:
            ZStack(alignment: .bottom) {
                MiniRoom()
                HStack(alignment: .bottom, spacing: 4) {
                    ItemIcon(kind: .records, height: 48)
                    ItemIcon(kind: .teddy, height: 56)
                    ItemIcon(kind: .potPlant, height: 54)
                    ItemIcon(kind: .book, height: 20)
                }
                .padding(.bottom, 16)
                ClawGlyph()
                    .frame(width: 60, height: 150)
                    .offset(x: 18, y: -66)
            }
        case 1:
            ZStack(alignment: .bottom) {
                MiniRoom()
                OpenBoxGlyph()
                    .frame(width: 170, height: 96)
                    .padding(.bottom, 14)
                VStack(spacing: 0) {
                    ClawGlyph().frame(width: 60, height: 60)
                    ItemIcon(kind: .plate, height: 14)
                    Image(systemName: "arrow.down")
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundStyle(Color.alert)
                        .padding(.top, 6)
                }
                .offset(y: -110)
            }
        default:
            ZStack(alignment: .bottom) {
                MiniRoom()
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(Array([BoxLabel.books, .kitchen, .toys].enumerated()), id: \.offset) { i, l in
                        SealedBox(number: i + 1, label: l, size: 78)
                    }
                }
                .padding(.bottom, 16)
                Text(yen(1_800))
                    .font(Type2.number(40))
                    .foregroundStyle(Color.good)
                    .offset(y: -140)
            }
        }
    }
}

/// 小さな部屋の断面（窓と床）
struct MiniRoom: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: Radius.room, style: .continuous).fill(Color(hex: 0xF6EEDF))
            RoundedRectangle(cornerRadius: 6).fill(Color(hex: 0xCFE6F5))
                .frame(width: 90, height: 70)
                .overlay { RoundedRectangle(cornerRadius: 6).strokeBorder(.white, lineWidth: 4) }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(24)
            Rectangle().fill(Color(hex: 0xD8B48A)).frame(height: 18)
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.room, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: Radius.room, style: .continuous).strokeBorder(Color.paper, lineWidth: 5) }
        .accessibilityHidden(true)
    }
}

/// クレーンのつめ（線の絵）
struct ClawGlyph: View {
    var body: some View {
        Canvas { ctx, size in
            let mid = size.width / 2
            var cable = Path()
            cable.move(to: CGPoint(x: mid, y: 0))
            cable.addLine(to: CGPoint(x: mid, y: size.height - 30))
            ctx.stroke(cable, with: .color(Color(hex: 0x5C6B73)), lineWidth: 2)
            let hub = CGRect(x: mid - 14, y: size.height - 32, width: 28, height: 12)
            ctx.fill(Path(roundedRect: hub, cornerRadius: 4), with: .color(.crane))
            for dir in [-1.0, 1.0] {
                var p = Path()
                p.move(to: CGPoint(x: mid + dir * 9, y: size.height - 22))
                p.addLine(to: CGPoint(x: mid + dir * 20, y: size.height - 10))
                p.addLine(to: CGPoint(x: mid + dir * 12, y: size.height))
                ctx.stroke(p, with: .color(.craneDeep), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            }
        }
        .accessibilityHidden(true)
    }
}

/// 開いた段ボール箱（横から）
struct OpenBoxGlyph: View {
    var body: some View {
        Canvas { ctx, size in
            let body = CGRect(x: 10, y: 18, width: size.width - 20, height: size.height - 18)
            ctx.fill(Path(roundedRect: body, cornerRadius: 3), with: .color(.cardboard))
            ctx.stroke(Path(roundedRect: body, cornerRadius: 3), with: .color(.cardboardDeep), lineWidth: 2)
            var rim = Path()
            rim.move(to: CGPoint(x: body.minX, y: body.minY))
            rim.addLine(to: CGPoint(x: body.maxX, y: body.minY))
            ctx.stroke(rim, with: .color(.cardboardDeep), style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
            for (x, dir) in [(body.minX, -1.0), (body.maxX, 1.0)] {
                var flap = Path()
                flap.move(to: CGPoint(x: x, y: body.minY))
                flap.addLine(to: CGPoint(x: x + dir * 18, y: 0))
                ctx.stroke(flap, with: .color(.cardboardDeep), style: StrokeStyle(lineWidth: 6, lineCap: .round))
            }
        }
        .accessibilityHidden(true)
    }
}
