import SwiftUI
import UIKit

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }

    /// 暗くする（0〜1）
    func darker(_ amount: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return UIColor(red: r * (1 - amount), green: g * (1 - amount), blue: b * (1 - amount), alpha: a)
    }

    func lighter(_ amount: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return UIColor(red: r + (1 - r) * amount, green: g + (1 - g) * amount, blue: b + (1 - b) * amount, alpha: a)
    }
}

/// 部屋の物の絵（やわらかい平面のイラスト。陰影は 1 段、輪郭は本体を 35% 暗くした線）。
/// 絵は当たり判定の大きさ（spec の w × h）ぴったりに描く
@MainActor
enum ItemArt {
    private static var cache: [String: UIImage] = [:]

    /// 当たり判定の輪郭（物理と絵で同じものを使う）。原点は左下、上が +y（SpriteKit の向き）
    static func outline(_ kind: ItemKind, scale: CGFloat = 1) -> CGPath {
        let s = kind.spec
        let w = CGFloat(s.w) * scale, h = CGFloat(s.h) * scale
        let p = CGMutablePath()
        switch s.shape {
        case .box, .flat, .tall:
            p.addRect(CGRect(x: -w / 2, y: -h / 2, width: w, height: h))
        case .round:
            let n = 14
            for i in 0..<n {
                let a = CGFloat(i) / CGFloat(n) * 2 * .pi
                let pt = CGPoint(x: cos(a) * w / 2 * 0.98, y: sin(a) * h / 2 * 0.98)
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            p.closeSubpath()
        case .pot:
            // 下がすぼまる台形（下の幅は上の 68%）
            p.move(to: CGPoint(x: -w * 0.34, y: -h / 2))
            p.addLine(to: CGPoint(x: w * 0.34, y: -h / 2))
            p.addLine(to: CGPoint(x: w / 2, y: h / 2))
            p.addLine(to: CGPoint(x: -w / 2, y: h / 2))
            p.closeSubpath()
        }
        return p
    }

    static func image(_ kind: ItemKind, scale: CGFloat = 2, broken: Bool = false) -> UIImage {
        let key = "\(kind.rawValue)-\(scale)-\(broken)"
        if let c = cache[key] { return c }
        let s = kind.spec
        let size = CGSize(width: s.w, height: s.h)
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        let img = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            draw(kind, in: ctx.cgContext, size: size)
        }
        cache[key] = img
        return img
    }

    // MARK: 描く（UIKit の向き：原点は左上）

    private static func draw(_ kind: ItemKind, in c: CGContext, size: CGSize) {
        let s = kind.spec
        let body = UIColor(hex: s.body)
        let accent = UIColor(hex: s.accent)
        let line = body.darker(0.38)
        let shade = body.darker(0.12)
        let w = size.width, h = size.height
        let lw: CGFloat = 1.6
        c.setLineJoin(.round)
        c.setLineCap(.round)

        func fill(_ path: UIBezierPath, _ color: UIColor, stroke: UIColor? = nil) {
            color.setFill()
            path.fill()
            if let stroke {
                stroke.setStroke()
                path.lineWidth = lw
                path.stroke()
            }
        }
        func rr(_ r: CGRect, _ radius: CGFloat) -> UIBezierPath { UIBezierPath(roundedRect: r, cornerRadius: radius) }
        func oval(_ r: CGRect) -> UIBezierPath { UIBezierPath(ovalIn: r) }
        /// 陰影 1 段：右下に本体を少し暗くした帯
        func shadeRight(_ clip: UIBezierPath, fraction: CGFloat = 0.28) {
            c.saveGState()
            clip.addClip()
            shade.setFill()
            UIRectFill(CGRect(x: w * (1 - fraction), y: 0, width: w * fraction, height: h))
            c.restoreGState()
        }
        let inset = CGRect(x: lw, y: lw, width: w - lw * 2, height: h - lw * 2)

        switch kind {
        case .book, .dictionary, .gameBox, .shoeBox, .hatBox, .boardGame, .comics:
            let p = rr(inset, kind == .hatBox ? 10 : 3)
            fill(p, body)
            shadeRight(p, fraction: 0.18)
            switch kind {
            case .book:
                accent.setFill()
                UIRectFill(CGRect(x: w * 0.1, y: h * 0.2, width: w * 0.06, height: h * 0.6))
                UIRectFill(CGRect(x: w * 0.25, y: h * 0.42, width: w * 0.5, height: h * 0.14))
            case .dictionary:
                accent.setFill()
                UIRectFill(CGRect(x: 0, y: h * 0.2, width: w, height: h * 0.1))
                UIRectFill(CGRect(x: 0, y: h * 0.7, width: w, height: h * 0.1))
                UIRectFill(CGRect(x: w * 0.35, y: h * 0.42, width: w * 0.3, height: h * 0.12))
            case .comics:
                for i in 0..<4 {
                    (i % 2 == 0 ? accent : body.lighter(0.25)).setFill()
                    UIRectFill(CGRect(x: lw, y: h * (0.05 + CGFloat(i) * 0.24), width: w - lw * 2, height: h * 0.04))
                }
            case .gameBox:
                accent.setFill()
                oval(CGRect(x: w * 0.12, y: h * 0.25, width: h * 0.5, height: h * 0.5)).fill()
                UIRectFill(CGRect(x: w * 0.5, y: h * 0.35, width: w * 0.36, height: h * 0.1))
                UIRectFill(CGRect(x: w * 0.5, y: h * 0.55, width: w * 0.24, height: h * 0.08))
            case .shoeBox:
                accent.setFill()
                UIRectFill(CGRect(x: lw, y: lw, width: w - lw * 2, height: h * 0.28))
                UIColor.white.withAlphaComponent(0.8).setFill()
                UIRectFill(CGRect(x: w * 0.38, y: h * 0.5, width: w * 0.24, height: h * 0.22))
            case .hatBox:
                accent.setFill()
                UIRectFill(CGRect(x: lw, y: h * 0.18, width: w - lw * 2, height: h * 0.12))
                accent.withAlphaComponent(0.5).setFill()
                for i in 0..<4 { oval(CGRect(x: w * (0.12 + CGFloat(i) * 0.2), y: h * 0.5, width: h * 0.22, height: h * 0.22)).fill() }
            case .boardGame:
                for i in 0..<6 {
                    (i % 2 == 0 ? accent : UIColor.white).setFill()
                    UIRectFill(CGRect(x: w * (0.1 + CGFloat(i) * 0.12), y: h * 0.3, width: w * 0.09, height: h * 0.4))
                }
            default: break
            }
            line.setStroke(); p.lineWidth = lw; p.stroke()

        case .plate:
            let p = oval(inset)
            fill(p, body)
            accent.setStroke()
            let rim = oval(inset.insetBy(dx: w * 0.08, dy: h * 0.22))
            rim.lineWidth = 1.5; rim.stroke()
            line.setStroke(); p.lineWidth = lw; p.stroke()

        case .laptop:
            let p = rr(inset, 3)
            fill(p, body)
            accent.setFill()
            UIRectFill(CGRect(x: lw, y: h * 0.55, width: w - lw * 2, height: h * 0.18))
            UIColor.white.withAlphaComponent(0.6).setFill()
            oval(CGRect(x: w * 0.48, y: h * 0.18, width: h * 0.3, height: h * 0.3)).fill()
            line.setStroke(); p.lineWidth = lw; p.stroke()

        case .pan:
            let pan = rr(CGRect(x: lw, y: h * 0.15, width: w * 0.62, height: h * 0.7), h * 0.3)
            fill(pan, body, stroke: line)
            let handle = rr(CGRect(x: w * 0.6, y: h * 0.38, width: w * 0.38, height: h * 0.26), h * 0.13)
            fill(handle, accent, stroke: accent.darker(0.35))

        case .bowl, .potPlant:
            let top = kind == .potPlant ? h * 0.42 : lw
            let pot = UIBezierPath()
            pot.move(to: CGPoint(x: lw, y: top))
            pot.addLine(to: CGPoint(x: w - lw, y: top))
            pot.addLine(to: CGPoint(x: w * 0.84, y: h - lw))
            pot.addLine(to: CGPoint(x: w * 0.16, y: h - lw))
            pot.close()
            if kind == .potPlant {
                // 葉（差し色）
                for (i, dx) in [-0.22, 0.0, 0.22].enumerated() {
                    let leaf = oval(CGRect(x: w * (0.5 + dx) - w * 0.14, y: h * (i == 1 ? 0.0 : 0.1), width: w * 0.28, height: h * 0.4))
                    fill(leaf, accent, stroke: accent.darker(0.35))
                }
            }
            fill(pot, body)
            shadeRight(pot, fraction: 0.3)
            if kind == .bowl {
                accent.setFill()
                UIRectFill(CGRect(x: w * 0.12, y: h * 0.28, width: w * 0.76, height: h * 0.12))
            } else {
                body.darker(0.2).setFill()
                UIRectFill(CGRect(x: lw, y: top, width: w - lw * 2, height: h * 0.1))
            }
            line.setStroke(); pot.lineWidth = lw; pot.stroke()

        case .mug:
            let handle = UIBezierPath(arcCenter: CGPoint(x: w * 0.76, y: h * 0.5), radius: h * 0.2, startAngle: -.pi / 2, endAngle: .pi / 2, clockwise: true)
            line.setStroke(); handle.lineWidth = 5; handle.stroke()
            body.setStroke(); handle.lineWidth = 3; handle.stroke()
            let p = rr(CGRect(x: lw, y: lw, width: w * 0.74, height: h - lw * 2), 5)
            fill(p, body)
            accent.setFill()
            oval(CGRect(x: w * 0.22, y: h * 0.35, width: w * 0.3, height: w * 0.3)).fill()
            line.setStroke(); p.lineWidth = lw; p.stroke()

        case .glass, .jar, .vase:
            let p: UIBezierPath
            if kind == .vase {
                p = UIBezierPath()
                p.move(to: CGPoint(x: w * 0.32, y: lw))
                p.addLine(to: CGPoint(x: w * 0.68, y: lw))
                p.addCurve(to: CGPoint(x: w - lw, y: h * 0.62), controlPoint1: CGPoint(x: w * 0.6, y: h * 0.3), controlPoint2: CGPoint(x: w - lw, y: h * 0.38))
                p.addCurve(to: CGPoint(x: w * 0.72, y: h - lw), controlPoint1: CGPoint(x: w - lw, y: h * 0.85), controlPoint2: CGPoint(x: w * 0.85, y: h - lw))
                p.addLine(to: CGPoint(x: w * 0.28, y: h - lw))
                p.addCurve(to: CGPoint(x: lw, y: h * 0.62), controlPoint1: CGPoint(x: w * 0.15, y: h - lw), controlPoint2: CGPoint(x: lw, y: h * 0.85))
                p.addCurve(to: CGPoint(x: w * 0.32, y: lw), controlPoint1: CGPoint(x: lw, y: h * 0.38), controlPoint2: CGPoint(x: w * 0.4, y: h * 0.3))
                p.close()
            } else {
                p = rr(CGRect(x: lw, y: kind == .jar ? h * 0.14 : lw, width: w - lw * 2, height: h - lw * 2 - (kind == .jar ? h * 0.12 : 0)), kind == .jar ? 6 : 3)
            }
            fill(p, kind == .glass ? body.withAlphaComponent(0.85) : body)
            if kind == .jar {
                fill(rr(CGRect(x: w * 0.1, y: lw, width: w * 0.8, height: h * 0.16), 3), accent, stroke: accent.darker(0.35))
                accent.withAlphaComponent(0.85).setFill()
                for (x, y) in [(0.3, 0.55), (0.6, 0.62), (0.42, 0.78), (0.7, 0.82), (0.25, 0.85)] {
                    oval(CGRect(x: w * x - 4, y: h * y - 4, width: 8, height: 8)).fill()
                }
            } else if kind == .vase {
                accent.setFill()
                UIRectFill(CGRect(x: w * 0.12, y: h * 0.6, width: w * 0.76, height: h * 0.08))
            }
            // ガラスの光（白い細い線）
            UIColor.white.withAlphaComponent(0.75).setFill()
            UIRectFill(CGRect(x: w * 0.22, y: h * 0.2, width: max(2, w * 0.08), height: h * 0.45))
            line.setStroke(); p.lineWidth = lw; p.stroke()

        case .kettle, .teapot:
            let p = oval(CGRect(x: w * 0.14, y: h * 0.22, width: w * 0.72, height: h * 0.74))
            let spout = UIBezierPath()
            spout.move(to: CGPoint(x: w * 0.78, y: h * 0.6))
            spout.addLine(to: CGPoint(x: w - lw, y: h * 0.3))
            spout.addLine(to: CGPoint(x: w - lw, y: h * 0.4))
            spout.addLine(to: CGPoint(x: w * 0.8, y: h * 0.75))
            spout.close()
            fill(spout, body, stroke: line)
            let handle = UIBezierPath(arcCenter: CGPoint(x: w * 0.5, y: h * 0.3), radius: w * 0.24, startAngle: .pi, endAngle: 0, clockwise: true)
            accent.setStroke(); handle.lineWidth = 4; handle.stroke()
            fill(p, body)
            shadeRight(p)
            fill(rr(CGRect(x: w * 0.4, y: h * 0.17, width: w * 0.2, height: h * 0.1), 3), accent)
            line.setStroke(); p.lineWidth = lw; p.stroke()

        case .pot, .riceCooker, .radio, .toolbox, .records:
            let p = rr(CGRect(x: w * 0.06, y: h * 0.12, width: w * 0.88, height: h * 0.86), kind == .riceCooker ? 14 : 5)
            if kind == .pot {
                fill(rr(CGRect(x: lw, y: h * 0.3, width: w - lw * 2, height: h * 0.14), 4), accent)
            }
            if kind == .toolbox {
                let handle = rr(CGRect(x: w * 0.32, y: lw, width: w * 0.36, height: h * 0.24), 4)
                accent.darker(0.3).setStroke(); handle.lineWidth = 4; handle.stroke()
            }
            fill(p, body)
            shadeRight(p, fraction: 0.2)
            switch kind {
            case .pot:
                accent.setFill(); UIRectFill(CGRect(x: w * 0.06, y: h * 0.12, width: w * 0.88, height: h * 0.12))
            case .riceCooker:
                fill(rr(CGRect(x: w * 0.3, y: h * 0.55, width: w * 0.4, height: h * 0.18), 4), accent)
                accent.setFill(); UIRectFill(CGRect(x: w * 0.06, y: h * 0.36, width: w * 0.88, height: h * 0.05))
            case .radio:
                fill(oval(CGRect(x: w * 0.12, y: h * 0.3, width: h * 0.55, height: h * 0.55)), accent, stroke: line)
                fill(rr(CGRect(x: w * 0.55, y: h * 0.35, width: w * 0.32, height: h * 0.2), 3), accent)
                UIColor(hex: 0x2F3A40).setFill(); UIRectFill(CGRect(x: w * 0.6, y: h * 0.7, width: w * 0.08, height: h * 0.12))
            case .toolbox:
                accent.setFill(); UIRectFill(CGRect(x: w * 0.06, y: h * 0.45, width: w * 0.88, height: h * 0.08))
                UIColor(hex: 0xF1C40F).setFill(); UIRectFill(CGRect(x: w * 0.45, y: h * 0.4, width: w * 0.1, height: h * 0.18))
            case .records:
                // 木箱から顔を出すレコード（黒い円の上半分）
                accent.setFill()
                for i in 0..<3 { oval(CGRect(x: w * (0.12 + CGFloat(i) * 0.26), y: h * 0.02, width: w * 0.24, height: w * 0.24)).fill() }
                fill(p, body)
                body.darker(0.2).setFill()
                for i in 1..<4 { UIRectFill(CGRect(x: w * 0.06, y: h * (0.12 + CGFloat(i) * 0.21), width: w * 0.88, height: 2)) }
            default: break
            }
            line.setStroke(); p.lineWidth = lw; p.stroke()

        case .cushion, .pillow, .blanket:
            let p = rr(inset, h * 0.35)
            fill(p, body)
            shadeRight(p, fraction: 0.22)
            switch kind {
            case .cushion:
                fill(oval(CGRect(x: w * 0.5 - 4, y: h * 0.5 - 4, width: 8, height: 8)), accent, stroke: line)
                accent.setStroke()
                let seam = rr(inset.insetBy(dx: 6, dy: 6), h * 0.25); seam.lineWidth = 1; seam.setLineDash([3, 3], count: 2, phase: 0); seam.stroke()
            case .pillow:
                accent.setFill()
                for i in 0..<3 { UIRectFill(CGRect(x: w * (0.2 + CGFloat(i) * 0.25), y: h * 0.2, width: 3, height: h * 0.6)) }
            case .blanket:
                accent.setFill()
                UIRectFill(CGRect(x: lw, y: h * 0.32, width: w - lw * 2, height: h * 0.1))
                UIRectFill(CGRect(x: lw, y: h * 0.6, width: w - lw * 2, height: h * 0.1))
            default: break
            }
            line.setStroke(); p.lineWidth = lw; p.stroke()

        case .teddy:
            let ear1 = oval(CGRect(x: w * 0.12, y: lw, width: w * 0.26, height: w * 0.26))
            let ear2 = oval(CGRect(x: w * 0.62, y: lw, width: w * 0.26, height: w * 0.26))
            fill(ear1, body, stroke: line); fill(ear2, body, stroke: line)
            let bodyP = oval(CGRect(x: w * 0.1, y: h * 0.45, width: w * 0.8, height: h * 0.53))
            fill(bodyP, body, stroke: line)
            fill(oval(CGRect(x: w * 0.3, y: h * 0.6, width: w * 0.4, height: h * 0.3)), accent)
            let head = oval(CGRect(x: w * 0.16, y: h * 0.06, width: w * 0.68, height: h * 0.48))
            fill(head, body, stroke: line)
            fill(oval(CGRect(x: w * 0.36, y: h * 0.28, width: w * 0.28, height: h * 0.18)), accent)
            UIColor(hex: 0x3B2F2F).setFill()
            oval(CGRect(x: w * 0.32, y: h * 0.2, width: 5, height: 5)).fill()
            oval(CGRect(x: w * 0.6, y: h * 0.2, width: 5, height: 5)).fill()
            oval(CGRect(x: w * 0.46, y: h * 0.3, width: 6, height: 4)).fill()

        case .photoFrame:
            let p = rr(inset, 3)
            fill(p, body, stroke: line)
            let pic = CGRect(x: w * 0.16, y: h * 0.13, width: w * 0.68, height: h * 0.74)
            fill(UIBezierPath(rect: pic), accent)
            let hill = UIBezierPath()
            hill.move(to: CGPoint(x: pic.minX, y: pic.maxY))
            hill.addLine(to: CGPoint(x: pic.minX + pic.width * 0.35, y: pic.minY + pic.height * 0.55))
            hill.addLine(to: CGPoint(x: pic.minX + pic.width * 0.6, y: pic.minY + pic.height * 0.75))
            hill.addLine(to: CGPoint(x: pic.maxX, y: pic.minY + pic.height * 0.5))
            hill.addLine(to: CGPoint(x: pic.maxX, y: pic.maxY))
            hill.close()
            UIColor(hex: 0x6BA368).setFill(); hill.fill()
            UIColor(hex: 0xFFF3B0).setFill()
            oval(CGRect(x: pic.minX + pic.width * 0.62, y: pic.minY + pic.height * 0.12, width: pic.width * 0.2, height: pic.width * 0.2)).fill()

        case .trophy:
            fill(rr(CGRect(x: w * 0.18, y: h * 0.8, width: w * 0.64, height: h * 0.18), 3), accent, stroke: accent.darker(0.3))
            fill(UIBezierPath(rect: CGRect(x: w * 0.44, y: h * 0.55, width: w * 0.12, height: h * 0.27)), body, stroke: line)
            let cup = UIBezierPath()
            cup.move(to: CGPoint(x: w * 0.14, y: lw))
            cup.addLine(to: CGPoint(x: w * 0.86, y: lw))
            cup.addCurve(to: CGPoint(x: w * 0.5, y: h * 0.58), controlPoint1: CGPoint(x: w * 0.86, y: h * 0.4), controlPoint2: CGPoint(x: w * 0.7, y: h * 0.58))
            cup.addCurve(to: CGPoint(x: w * 0.14, y: lw), controlPoint1: CGPoint(x: w * 0.3, y: h * 0.58), controlPoint2: CGPoint(x: w * 0.14, y: h * 0.4))
            cup.close()
            fill(cup, body)
            shadeRight(cup)
            UIColor.white.withAlphaComponent(0.7).setFill()
            UIRectFill(CGRect(x: w * 0.3, y: h * 0.08, width: 3, height: h * 0.25))
            line.setStroke(); cup.lineWidth = lw; cup.stroke()

        case .lamp:
            fill(rr(CGRect(x: w * 0.2, y: h * 0.9, width: w * 0.6, height: h * 0.09), 3), accent, stroke: accent.darker(0.3))
            accent.setFill(); UIRectFill(CGRect(x: w * 0.46, y: h * 0.38, width: w * 0.08, height: h * 0.54))
            let shadeP = UIBezierPath()
            shadeP.move(to: CGPoint(x: w * 0.28, y: lw))
            shadeP.addLine(to: CGPoint(x: w * 0.72, y: lw))
            shadeP.addLine(to: CGPoint(x: w - lw, y: h * 0.4))
            shadeP.addLine(to: CGPoint(x: lw, y: h * 0.4))
            shadeP.close()
            fill(shadeP, body)
            shadeRight(shadeP)
            line.setStroke(); shadeP.lineWidth = lw; shadeP.stroke()

        case .clock, .ball, .globe, .piggyBank, .snowGlobe:
            switch kind {
            case .clock:
                let p = oval(inset)
                fill(p, body, stroke: line)
                fill(oval(inset.insetBy(dx: w * 0.12, dy: h * 0.12)), accent)
                UIColor(hex: 0x2F3A40).setStroke()
                let hands = UIBezierPath()
                hands.move(to: CGPoint(x: w / 2, y: h / 2)); hands.addLine(to: CGPoint(x: w / 2, y: h * 0.25))
                hands.move(to: CGPoint(x: w / 2, y: h / 2)); hands.addLine(to: CGPoint(x: w * 0.68, y: h * 0.56))
                hands.lineWidth = 2.5; hands.stroke()
            case .ball:
                let p = oval(inset)
                fill(p, accent)
                body.setFill()
                for (x, y) in [(0.5, 0.5), (0.2, 0.3), (0.78, 0.3), (0.3, 0.8), (0.72, 0.8)] {
                    oval(CGRect(x: w * x - w * 0.11, y: h * y - h * 0.11, width: w * 0.22, height: h * 0.22)).fill()
                }
                accent.darker(0.35).setStroke(); p.lineWidth = lw; p.stroke()
            case .globe:
                fill(rr(CGRect(x: w * 0.25, y: h * 0.86, width: w * 0.5, height: h * 0.12), 3), UIColor(hex: 0x8D6346))
                let ball = oval(CGRect(x: w * 0.08, y: lw, width: w * 0.84, height: h * 0.8))
                fill(ball, body)
                c.saveGState(); ball.addClip()
                accent.setFill()
                oval(CGRect(x: w * 0.15, y: h * 0.12, width: w * 0.35, height: h * 0.25)).fill()
                oval(CGRect(x: w * 0.5, y: h * 0.42, width: w * 0.35, height: h * 0.3)).fill()
                c.restoreGState()
                line.setStroke(); ball.lineWidth = lw; ball.stroke()
            case .piggyBank:
                fill(oval(CGRect(x: w * 0.22, y: h * 0.06, width: w * 0.18, height: h * 0.24)), body, stroke: line)
                let p = oval(CGRect(x: lw, y: h * 0.14, width: w - lw * 2, height: h * 0.72))
                fill(p, body)
                shadeRight(p)
                line.setStroke(); p.lineWidth = lw; p.stroke()
                fill(rr(CGRect(x: w * 0.82, y: h * 0.4, width: w * 0.16, height: h * 0.2), 4), accent, stroke: line)
                accent.setFill()
                UIRectFill(CGRect(x: w * 0.25, y: h * 0.8, width: w * 0.1, height: h * 0.18))
                UIRectFill(CGRect(x: w * 0.6, y: h * 0.8, width: w * 0.1, height: h * 0.18))
                UIColor(hex: 0x3B2F2F).setFill()
                oval(CGRect(x: w * 0.66, y: h * 0.34, width: 4, height: 4)).fill()
                UIRectFill(CGRect(x: w * 0.4, y: h * 0.18, width: w * 0.16, height: 2))
            default:
                fill(rr(CGRect(x: w * 0.12, y: h * 0.74, width: w * 0.76, height: h * 0.24), 4), accent, stroke: accent.darker(0.3))
                let dome = oval(CGRect(x: w * 0.06, y: lw, width: w * 0.88, height: h * 0.8))
                fill(dome, body.withAlphaComponent(0.9))
                UIColor(hex: 0x6BA368).setFill()
                UIBezierPath(ovalIn: CGRect(x: w * 0.3, y: h * 0.38, width: w * 0.4, height: h * 0.34)).fill()
                UIColor.white.setFill()
                for (x, y) in [(0.3, 0.2), (0.6, 0.15), (0.45, 0.32), (0.72, 0.4), (0.22, 0.45)] {
                    oval(CGRect(x: w * x, y: h * y, width: 3.5, height: 3.5)).fill()
                }
                line.setStroke(); dome.lineWidth = lw; dome.stroke()
            }

        case .boots:
            let p = UIBezierPath()
            p.move(to: CGPoint(x: w * 0.1, y: lw))
            p.addLine(to: CGPoint(x: w * 0.6, y: lw))
            p.addLine(to: CGPoint(x: w * 0.6, y: h * 0.55))
            p.addQuadCurve(to: CGPoint(x: w - lw, y: h * 0.85), controlPoint: CGPoint(x: w - lw, y: h * 0.58))
            p.addLine(to: CGPoint(x: w - lw, y: h - lw))
            p.addLine(to: CGPoint(x: w * 0.1, y: h - lw))
            p.close()
            fill(p, body)
            shadeRight(p, fraction: 0.2)
            accent.setFill()
            UIRectFill(CGRect(x: w * 0.1, y: h * 0.9, width: w * 0.88, height: h * 0.08))
            UIRectFill(CGRect(x: w * 0.1, y: h * 0.06, width: w * 0.5, height: h * 0.07))
            line.setStroke(); p.lineWidth = lw; p.stroke()

        case .blocks:
            let colors = [body, accent, UIColor(hex: 0xFFD166), UIColor(hex: 0x06D6A0)]
            let half = CGSize(width: (w - lw * 2) / 2, height: (h - lw * 2) / 2)
            for i in 0..<4 {
                let r = CGRect(x: lw + CGFloat(i % 2) * half.width, y: lw + CGFloat(i / 2) * half.height, width: half.width, height: half.height)
                fill(rr(r.insetBy(dx: 0.5, dy: 0.5), 3), colors[i], stroke: colors[i].darker(0.35))
            }

        case .toyCar:
            let p = rr(CGRect(x: lw, y: h * 0.32, width: w - lw * 2, height: h * 0.42), 6)
            fill(rr(CGRect(x: w * 0.22, y: lw, width: w * 0.5, height: h * 0.45), 6), body.lighter(0.15), stroke: line)
            fill(p, body, stroke: line)
            UIColor.white.withAlphaComponent(0.85).setFill()
            UIRectFill(CGRect(x: w * 0.3, y: h * 0.1, width: w * 0.15, height: h * 0.2))
            UIRectFill(CGRect(x: w * 0.5, y: h * 0.1, width: w * 0.15, height: h * 0.2))
            for x in [0.22, 0.78] {
                fill(oval(CGRect(x: w * x - h * 0.2, y: h * 0.58, width: h * 0.4, height: h * 0.4)), accent, stroke: line)
            }

        case .dumbbell:
            accent.setFill(); UIRectFill(CGRect(x: w * 0.1, y: h * 0.42, width: w * 0.8, height: h * 0.16))
            for x in [0.0, 0.14, 0.72, 0.86] {
                fill(rr(CGRect(x: w * x + lw, y: x == 0 || x == 0.86 ? h * 0.12 : lw, width: w * 0.12, height: x == 0 || x == 0.86 ? h * 0.76 : h - lw * 2), 3), body, stroke: line)
            }

        case .ukulele:
            accent.setFill(); UIRectFill(CGRect(x: w * 0.42, y: lw, width: w * 0.16, height: h * 0.5))
            fill(rr(CGRect(x: w * 0.34, y: lw, width: w * 0.32, height: h * 0.1), 3), accent.darker(0.2))
            let p = UIBezierPath()
            p.append(oval(CGRect(x: w * 0.12, y: h * 0.42, width: w * 0.76, height: h * 0.26)))
            p.append(oval(CGRect(x: lw, y: h * 0.58, width: w - lw * 2, height: h * 0.4)))
            fill(p, body)
            fill(oval(CGRect(x: w * 0.38, y: h * 0.62, width: w * 0.24, height: w * 0.24)), accent)
            line.setStroke(); p.lineWidth = lw; p.stroke()
        }
    }
}

/// SwiftUI で物の絵を出す
struct ItemIcon: View {
    let kind: ItemKind
    var height: CGFloat = 34
    var dimmed = false

    var body: some View {
        let s = kind.spec
        let scale = height / max(s.h, s.w * 0.75)
        Image(uiImage: ItemArt.image(kind, scale: 3))
            .resizable()
            .interpolation(.high)
            .frame(width: s.w * scale, height: s.h * scale)
            .saturation(dimmed ? 0 : 1)
            .opacity(dimmed ? 0.35 : 1)
            .accessibilityHidden(true)
    }
}
