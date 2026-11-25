import SwiftUI

/// 晴れた朝の、空っぽになっていく部屋。段ボールの茶色・ガムテープ・マジックの黒・クレーンの黄色。
/// 色は 1 系統（段ボール）を 5 段階で持ち、黄色と赤は「操作」と「危ない」にだけ使う
enum Palette {
    // 段ボール（主役の 5 段階）
    static let cardboard: UInt32 = 0xC99A62
    static let cardboardSoft: UInt32 = 0xE6CBA4
    static let cardboardDeep: UInt32 = 0x8A6236
    static let paper: UInt32 = 0xFFF8EC
    static let tape: UInt32 = 0xE9D6A8
    // マジック
    static let ink: UInt32 = 0x2E2A26
    // クレーン（押せる物の色）
    static let crane: UInt32 = 0xF7C531
    static let craneDeep: UInt32 = 0x9C7406
    // 危ない（割れる・はみ出す）
    static let alert: UInt32 = 0xE4572E
    // よかった（星・浮いたお金）
    static let good: UInt32 = 0x2F9E6B
    // 朝の空と光
    static let skyTop: UInt32 = 0xE3F1FA
    static let skyBottom: UInt32 = 0xFFF2DC
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255, opacity: opacity)
    }

    static let cardboard = Color(hex: Palette.cardboard)
    static let cardboardSoft = Color(hex: Palette.cardboardSoft)
    static let cardboardDeep = Color(hex: Palette.cardboardDeep)
    static let paper = Color(hex: Palette.paper)
    static let tape = Color(hex: Palette.tape)
    static let ink = Color(hex: Palette.ink)
    static let crane = Color(hex: Palette.crane)
    static let craneDeep = Color(hex: Palette.craneDeep)
    static let alert = Color(hex: Palette.alert)
    static let good = Color(hex: Palette.good)
}

/// 書体は 2 つ：見出しと数字は丸ゴシックの太字、箱やラベルの手書きはマジック（Marker Felt）
enum Type2 {
    static func head(_ size: CGFloat) -> Font { .system(size: size, weight: .heavy, design: .rounded) }
    static func body(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font { .system(size: size, weight: weight, design: .rounded) }
    static func number(_ size: CGFloat) -> Font { .system(size: size, weight: .black, design: .rounded).monospacedDigit() }
    /// マジックの手書き（英数字は Marker Felt、日本語は丸ゴシックの太字に落ちる）
    static func marker(_ size: CGFloat) -> Font { .custom("MarkerFelt-Wide", size: size, relativeTo: .headline) }
}

/// 角丸と余白の段階
enum Radius {
    static let tag: CGFloat = 6
    static let card: CGFloat = 14
    static let room: CGFloat = 20
    static let button: CGFloat = 18
    static let sheet: CGFloat = 26
}

enum Space {
    static let s: CGFloat = 6
    static let m: CGFloat = 12
    static let l: CGFloat = 18
    static let xl: CGFloat = 26
}

/// 朝の空の背景（上は淡い空色、下は朝日の黄色み）
struct MorningBackground: View {
    var body: some View {
        LinearGradient(colors: [Color(hex: Palette.skyTop), Color(hex: Palette.skyBottom)], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }
}

/// ガムテープの帯（少し傾けて貼る。端はギザギザ）
struct TapeStrip<Content: View>: View {
    var tilt: Double = -1.5
    var color: Color = .tape
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background {
                TornTape().fill(color).shadow(color: .cardboardDeep.opacity(0.18), radius: 1, y: 1)
            }
            .rotationEffect(.degrees(tilt))
    }
}

/// 端がギザギザのテープの形
struct TornTape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let teeth = 5
        let step = r.height / CGFloat(teeth)
        p.move(to: CGPoint(x: r.minX + 3, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - 3, y: r.minY))
        for i in 0..<teeth {
            p.addLine(to: CGPoint(x: r.maxX - (i % 2 == 0 ? 0 : 4), y: r.minY + step * (CGFloat(i) + 0.5)))
        }
        p.addLine(to: CGPoint(x: r.maxX - 3, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + 3, y: r.maxY))
        for i in 0..<teeth {
            p.addLine(to: CGPoint(x: r.minX + (i % 2 == 0 ? 0 : 4), y: r.maxY - step * (CGFloat(i) + 0.5)))
        }
        p.closeSubpath()
        return p
    }
}

/// 段ボールの板（カードの代わり。上にテープの線、角は少しだけ丸い）
struct CardboardPanel: ViewModifier {
    var tone: Color = .paper

    func body(content: Content) -> some View {
        content
            .padding(Space.m)
            .background {
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .fill(tone)
                    .overlay {
                        RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                            .strokeBorder(Color.cardboardDeep.opacity(0.35), lineWidth: 1.5)
                    }
                    .shadow(color: .cardboardDeep.opacity(0.16), radius: 0, x: 0, y: 3)
                    .allowsHitTesting(false)
            }
    }
}

extension View {
    func cardboardPanel(_ tone: Color = .paper) -> some View { modifier(CardboardPanel(tone: tone)) }
}

/// 大きな丸いボタン（下に 4pt の段ボールの影。押すと沈む）
struct ChunkyButtonStyle: ButtonStyle {
    var fill: Color = .crane
    var text: Color = .ink

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Type2.head(17))
            .foregroundStyle(text)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background {
                RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                    .fill(fill)
                    .shadow(color: .cardboardDeep.opacity(0.55), radius: 0, x: 0, y: configuration.isPressed ? 1 : 4)
            }
            .offset(y: configuration.isPressed ? 3 : 0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// 星 3 つ
struct Stars: View {
    let count: Int
    var size: CGFloat = 16

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { i in
                Image(systemName: i < count ? "star.fill" : "star")
                    .font(.system(size: size, weight: .bold))
                    .foregroundStyle(i < count ? Color.crane : Color.cardboardDeep.opacity(0.35))
            }
        }
        .accessibilityElement()
        .accessibilityLabel(trf("星 %d", "%d stars", count))
    }
}

/// 円の金額（日本語は「¥1,200」、英語も同じ表記）
func yen(_ v: Int) -> String {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    return "¥" + (f.string(from: NSNumber(value: v)) ?? "\(v)")
}
