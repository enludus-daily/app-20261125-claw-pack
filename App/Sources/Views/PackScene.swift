import SpriteKit
import UIKit

/// 部屋の物 1 つ
final class ItemNode: SKSpriteNode {
    var kind: ItemKind = .book
    /// 放した（落ちている）ときの、下の端の高さ。最初に何かに触れたら、落ちた高さを測って消す
    var fallingFrom: CGFloat?
    var held = false
    var gone = false
}

/// 部屋の場面（SpriteKit）。決まり（Rules）と記録は AppModel が持ち、ここは物理と動きだけ。
/// 座標は固定（480 × 440）で、画面には縦横比を保って縮めて出す（機種で物理が変わらないように）。
/// 左は部屋の床、右は段ボール箱。上のレールのクレーンを指でなぞって動かし、下のボタンで下ろす・つかむ・放す。
@MainActor
final class PackScene: SKScene, @preconcurrency SKPhysicsContactDelegate {
    weak var model: AppModel?

    enum Crane: Equatable { case idle, descending, lifting, holding, lowering, busy }
    private(set) var crane: Crane = .idle

    // 寸法
    static let size = CGSize(width: Rules.sceneWidth, height: Rules.sceneHeight)
    let floorY = CGFloat(Rules.floorY)
    let boxMinX: CGFloat = 266
    var boxMaxX: CGFloat { boxMinX + CGFloat(Rules.boxWidth) }
    var rimY: CGFloat { floorY + CGFloat(Rules.boxHeight) }
    let wall: CGFloat = 7
    let railY: CGFloat = 424
    /// つめの先の、いちばん上の高さ
    let restY: CGFloat = 404
    let roomMaxX: CGFloat = 246

    // 部品
    private var itemsLayer = SKNode()
    private var fxLayer = SKNode()
    private var boxNode = SKNode()
    private var boxLabel = SKLabelNode()
    private var carriage = SKShapeNode()
    private var cable = SKShapeNode()
    private var claw = SKNode()
    private var leftProng = SKShapeNode()
    private var rightProng = SKShapeNode()
    private var aimLine = SKShapeNode()
    private var rimLine = SKShapeNode()
    private var built = false

    /// クレーンの横の位置
    private(set) var aimX: CGFloat = 130
    private var clawY: CGFloat = 404
    private var target: ItemNode?
    private var heldNode: ItemNode?
    private var holdStart: TimeInterval = 0
    private var now: TimeInterval = 0
    private var lastTime: TimeInterval?
    private var lastSpawn: TimeInterval = -10
    var spawnPaused = false

    /// つめの上げ下げ（SKAction の中から self を触らないよう、毎フレームで進める）
    struct Tween {
        var from: CGFloat
        var to: CGFloat
        var duration: Double
        var delay: Double = 0
        var elapsed: Double = 0
        var done: () -> Void
    }
    private var tween: Tween?

    var items: [ItemNode] { itemsLayer.children.compactMap { $0 as? ItemNode }.filter { !$0.gone } }
    func inBox(_ n: ItemNode) -> Bool { !n.held && n.position.x > boxMinX && n.position.x < boxMaxX && n.position.y < rimY + 80 }
    var floorItems: [ItemNode] { items.filter { !$0.held && !inBox($0) } }
    var boxItems: [ItemNode] { items.filter { inBox($0) } }
    var isHolding: Bool { heldNode != nil }

    override init(size: CGSize) {
        super.init(size: PackScene.size)
        scaleMode = .aspectFit
        backgroundColor = .clear
        anchorPoint = .zero
        physicsWorld.gravity = CGVector(dx: 0, dy: -9.8)
        physicsWorld.contactDelegate = self
    }

    required init?(coder aDecoder: NSCoder) { fatalError("not used") }

    override func didMove(to view: SKView) {
        view.allowsTransparency = true
        view.backgroundColor = .clear
        view.isMultipleTouchEnabled = false
        if !built { build() }
    }

    // MARK: 組み立て

    func build() {
        built = true
        removeAllChildren()
        let theme = model?.room.theme ?? .studio

        let bg = SKSpriteNode(texture: SKTexture(image: RoomPainter.background(theme: theme, size: PackScene.size)))
        bg.anchorPoint = .zero
        bg.size = PackScene.size
        bg.zPosition = -10
        addChild(bg)

        // 床と左右の壁（上は開いている）
        let edge = CGMutablePath()
        edge.move(to: CGPoint(x: 0, y: size.height * 2))
        edge.addLine(to: CGPoint(x: 0, y: floorY))
        edge.addLine(to: CGPoint(x: size.width, y: floorY))
        edge.addLine(to: CGPoint(x: size.width, y: size.height * 2))
        physicsBody = SKPhysicsBody(edgeChainFrom: edge)
        physicsBody?.friction = 0.8
        physicsBody?.restitution = 0.02
        physicsBody?.categoryBitMask = 2
        physicsBody?.contactTestBitMask = 1

        itemsLayer = SKNode()
        itemsLayer.zPosition = 2
        addChild(itemsLayer)
        fxLayer = SKNode()
        fxLayer.zPosition = 30
        addChild(fxLayer)

        buildBox()
        buildCrane()
        moveCrane(to: aimX)
    }

    private func buildBox() {
        boxNode.removeFromParent()
        boxNode = SKNode()
        boxNode.zPosition = 1
        addChild(boxNode)
        let back = SKSpriteNode(texture: SKTexture(image: RoomPainter.boxBack(number: (model?.closedBoxes.count ?? 0) + 1)))
        back.anchorPoint = .zero
        back.size = CGSize(width: boxMaxX - boxMinX + wall * 2, height: CGFloat(Rules.boxHeight) + 26)
        back.position = CGPoint(x: boxMinX - wall, y: floorY)
        back.zPosition = 0
        boxNode.addChild(back)

        // 左右の壁（物理あり・物の手前に描く）
        for x in [boxMinX - wall, boxMaxX] {
            let r = CGRect(x: x, y: floorY, width: wall, height: CGFloat(Rules.boxHeight))
            let w = SKShapeNode(rect: r, cornerRadius: 2)
            w.fillColor = UIColor(hex: Palette.cardboard)
            w.strokeColor = UIColor(hex: Palette.cardboardDeep)
            w.lineWidth = 1.5
            w.zPosition = 6
            let body = SKPhysicsBody(rectangleOf: r.size, center: CGPoint(x: r.midX, y: r.midY))
            body.isDynamic = false
            body.friction = 0.7
            body.categoryBitMask = 2
            body.contactTestBitMask = 1
            w.physicsBody = body
            boxNode.addChild(w)
            // 開いたふた（外へ傾いた板。物理なし）
            let flap = SKShapeNode(rectOf: CGSize(width: wall, height: 34), cornerRadius: 2)
            flap.fillColor = UIColor(hex: Palette.cardboard).lighter(0.08)
            flap.strokeColor = UIColor(hex: Palette.cardboardDeep)
            flap.lineWidth = 1.5
            let left = x < boxMinX
            flap.position = CGPoint(x: x + wall / 2 + (left ? -10 : 10), y: rimY + 14)
            flap.zRotation = left ? 0.5 : -0.5
            flap.zPosition = 6
            flap.name = "flap"
            boxNode.addChild(flap)
        }
        // 縁の線（はみ出すと赤く光る）
        let lp = CGMutablePath()
        lp.move(to: CGPoint(x: boxMinX, y: rimY))
        lp.addLine(to: CGPoint(x: boxMaxX, y: rimY))
        rimLine = SKShapeNode(path: lp.copy(dashingWithPhase: 0, lengths: [6, 5]))
        rimLine.strokeColor = UIColor(hex: Palette.cardboardDeep).withAlphaComponent(0.55)
        rimLine.lineWidth = 2
        rimLine.zPosition = 7
        boxNode.addChild(rimLine)
    }

    private func buildCrane() {
        let rail = SKShapeNode(rect: CGRect(x: 8, y: railY, width: size.width - 16, height: 8), cornerRadius: 4)
        rail.fillColor = UIColor(hex: 0x8A97A0)
        rail.strokeColor = UIColor(hex: 0x5C6B73)
        rail.lineWidth = 1.5
        rail.zPosition = 20
        addChild(rail)

        let skin = UIColor(hex: model?.save.skin.color ?? ClawSkin.sunny.color)
        carriage = SKShapeNode(rect: CGRect(x: -22, y: -9, width: 44, height: 18), cornerRadius: 6)
        carriage.fillColor = skin
        carriage.strokeColor = skin.darker(0.4)
        carriage.lineWidth = 2
        carriage.position = CGPoint(x: aimX, y: railY + 4)
        carriage.zPosition = 22
        addChild(carriage)

        cable = SKShapeNode()
        cable.strokeColor = UIColor(hex: 0x5C6B73)
        cable.lineWidth = 2
        cable.zPosition = 19
        addChild(cable)

        aimLine = SKShapeNode()
        aimLine.strokeColor = skin.withAlphaComponent(0.55)
        aimLine.lineWidth = 2
        aimLine.zPosition = 1.5
        addChild(aimLine)

        claw = SKNode()
        claw.zPosition = 21
        let hub = SKShapeNode(rect: CGRect(x: -14, y: 0, width: 28, height: 12), cornerRadius: 4)
        hub.fillColor = skin
        hub.strokeColor = skin.darker(0.4)
        hub.lineWidth = 2
        claw.addChild(hub)
        func prong(_ dir: CGFloat) -> SKShapeNode {
            let p = CGMutablePath()
            p.move(to: .zero)
            p.addLine(to: CGPoint(x: dir * 12, y: -14))
            p.addLine(to: CGPoint(x: dir * 4, y: -26))
            let n = SKShapeNode(path: p)
            n.strokeColor = skin.darker(0.25)
            n.lineWidth = 4
            n.lineCap = .round
            n.lineJoin = .round
            n.position = CGPoint(x: dir * 9, y: 2)
            return n
        }
        leftProng = prong(-1)
        rightProng = prong(1)
        claw.addChild(leftProng)
        claw.addChild(rightProng)
        addChild(claw)
        openProngs(true, animated: false)
    }

    private func openProngs(_ open: Bool, animated: Bool = true) {
        let a: CGFloat = open ? 0.35 : -0.12
        if animated && !(model?.motionOff ?? false) {
            leftProng.run(.rotate(toAngle: -a, duration: 0.12))
            rightProng.run(.rotate(toAngle: a, duration: 0.12))
        } else {
            leftProng.zRotation = -a
            rightProng.zRotation = a
        }
    }

    /// つめの先の位置に、クレーンの絵を合わせる
    private func layoutClaw() {
        carriage.position = CGPoint(x: aimX, y: railY + 4)
        claw.position = CGPoint(x: aimX, y: clawY + 26)
        let p = CGMutablePath()
        p.move(to: CGPoint(x: aimX, y: railY))
        p.addLine(to: CGPoint(x: aimX, y: clawY + 38))
        cable.path = p
        let surface = surfaceBelow(x: aimX, ignoring: heldNode)
        let a = CGMutablePath()
        let fromY = heldNode.map { $0.position.y - $0.size.height / 2 } ?? clawY
        a.move(to: CGPoint(x: aimX, y: fromY - 4))
        a.addLine(to: CGPoint(x: aimX, y: surface + 2))
        aimLine.path = a.copy(dashingWithPhase: 0, lengths: [4, 6])
        if let held = heldNode {
            held.position = CGPoint(x: aimX, y: clawY - held.size.height / 2 + 4)
        }
    }

    // MARK: 物

    @discardableResult
    func makeItem(_ kind: ItemKind, at p: CGPoint, angle: CGFloat = 0) -> ItemNode {
        let s = kind.spec
        let node = ItemNode(texture: SKTexture(image: ItemArt.image(kind)))
        node.size = CGSize(width: CGFloat(s.w), height: CGFloat(s.h))
        node.kind = kind
        node.position = p
        node.zRotation = angle
        node.zPosition = CGFloat(itemsLayer.children.count % 20) * 0.01
        node.physicsBody = makeBody(kind)
        itemsLayer.addChild(node)
        return node
    }

    private func makeBody(_ kind: ItemKind) -> SKPhysicsBody {
        let body = SKPhysicsBody(polygonFrom: ItemArt.outline(kind))
        let s = kind.spec
        body.restitution = s.shape == .round ? 0.18 : 0.04
        body.friction = s.shape == .round ? 0.4 : 0.75
        body.density = 0.4 + CGFloat(s.weight) * 0.35
        body.angularDamping = s.shape == .round ? 0.6 : 2.2
        body.linearDamping = 0.2
        body.categoryBitMask = 1
        body.collisionBitMask = 1 | 2
        body.contactTestBitMask = 1 | 2
        return body
    }

    /// 部屋の物を床に並べて置く（部屋の始め・撮影）
    func placeOnFloor(_ kinds: [ItemKind]) {
        var x: CGFloat = 14
        var y: CGFloat = floorY
        var rowH: CGFloat = 0
        for k in kinds {
            let s = (w: CGFloat(k.spec.w), h: CGFloat(k.spec.h))
            if x + s.w > roomMaxX - 6 {
                x = 14
                y += rowH + 2
                rowH = 0
            }
            makeItem(k, at: CGPoint(x: x + s.w / 2, y: y + s.h / 2 + 1))
            x += s.w + 6
            rowH = max(rowH, s.h)
        }
    }

    /// 箱の中に並べて置く（撮影・デモ用）
    func placeInBox(_ kinds: [ItemKind]) {
        var x = boxMinX + 2
        var y = floorY
        var rowH: CGFloat = 0
        for k in kinds {
            let s = (w: CGFloat(k.spec.w), h: CGFloat(k.spec.h))
            if x + s.w > boxMaxX - 2 {
                x = boxMinX + 2
                y += rowH + 1
                rowH = 0
            }
            makeItem(k, at: CGPoint(x: x + s.w / 2, y: y + s.h / 2 + 1))
            x += s.w + 1
            rowH = max(rowH, s.h)
        }
    }

    /// 撮影・デモ：物を持った状態にする
    func stageHold(_ kind: ItemKind, x: CGFloat, lowered: CGFloat = 0) {
        let node = makeItem(kind, at: CGPoint(x: x, y: 300))
        node.held = true
        node.physicsBody = nil
        node.zPosition = 10
        heldNode = node
        crane = .holding
        openProngs(false, animated: false)
        clawY = restY - lowered
        aimX = x
        moveCrane(to: x)
    }

    /// 撮影・デモ：いまの物の位置（種類ごとの最初の 1 つ）
    func position(of kind: ItemKind) -> CGFloat? {
        floorItems.first { $0.kind == kind }?.position.x
    }

    /// 次の物を部屋に入れる（床の物が 4 つより少ないとき。左のドアから落ちてくる）
    private func spawnIfNeeded() {
        guard !spawnPaused, let model, now - lastSpawn > 0.6, floorItems.count < 4, crane != .busy else { return }
        guard let kind = model.nextItemFromQueue() else { return }
        lastSpawn = now
        let w = CGFloat(kind.spec.w)
        var rng = SeededRNG(seed: UInt64(model.queueIndex * 7919 + model.room.number))
        let x = 20 + w / 2 + CGFloat(rng.unit()) * max(0, roomMaxX - 40 - w)
        let node = makeItem(kind, at: CGPoint(x: x, y: 330))
        if !(model.motionOff) {
            node.setScale(0.6)
            node.run(.scale(to: 1, duration: 0.18))
        }
    }

    /// 物の真下の面の高さ（床・箱の縁・ほかの物の上）
    func surfaceBelow(x: CGFloat, halfWidth: CGFloat = 1, ignoring: ItemNode?) -> CGFloat {
        var top = floorY
        let lo = x - halfWidth, hi = x + halfWidth
        // 箱の壁の上
        for wx in [boxMinX - wall, boxMaxX] where hi > wx && lo < wx + wall { top = max(top, rimY) }
        for n in items where n !== ignoring && !n.held {
            let f = n.frame
            if hi > f.minX && lo < f.maxX && f.maxY < (ignoring.map { $0.position.y } ?? size.height) + 400 {
                top = max(top, f.maxY)
            }
        }
        return top
    }

    // MARK: 操作

    func setAim(_ x: CGFloat) {
        guard crane == .idle || crane == .holding else { return }
        moveCrane(to: x)
    }

    private func moveCrane(to x: CGFloat) {
        let half = (heldNode?.size.width ?? 20) / 2
        aimX = min(max(x, 12 + half), size.width - 12 - half)
        layoutClaw()
    }

    // 部屋を指でなぞると、クレーンが左右に動く（SpriteKit の画面が指を受ける）
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let t = touches.first { setAim(t.location(in: self).x) }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let t = touches.first { setAim(t.location(in: self).x) }
    }

    /// 下のボタンを押した
    func press() {
        switch crane {
        case .idle: descend()
        case .holding:
            crane = .lowering
            holdStart = now
            model?.craneChanged()
        default: break
        }
    }

    /// 下のボタンを離した
    func release() {
        if crane == .lowering || crane == .holding { drop() }
    }

    private func descend() {
        let candidates = items.filter { !$0.held && $0.frame.minX <= aimX && $0.frame.maxX >= aimX }
        target = candidates.max { $0.frame.maxY < $1.frame.maxY }
        let stopY = max(target.map { $0.frame.maxY } ?? surfaceBelow(x: aimX, ignoring: nil), floorY) + 2
        crane = .descending
        model?.craneChanged()
        model?.play(.whirr)
        openProngs(true)
        let dist = restY - stopY
        let duration = (model?.motionOff ?? false) ? 0.15 : Double(dist / 420)
        tween = Tween(from: clawY, to: stopY, duration: duration) { [weak self] in self?.tryGrab() }
    }

    private func tryGrab() {
        guard let model else { return }
        openProngs(false)
        var grabbed = false
        if let t = target, !t.gone {
            let offset = Double((aimX - t.position.x) / max(1, t.frame.width / 2))
            if Rules.grabs(t.kind, offset: offset, steady: model.steadyOn, roll: model.nextRoll()) {
                grabbed = true
                heldNode = t
                t.held = true
                t.physicsBody = nil
                t.zRotation = 0
                t.zPosition = 10
            }
        }
        if grabbed {
            model.didGrab(heldNode!.kind)
        } else {
            model.didMiss(near: target?.kind)
            if let t = target, !t.gone {
                // つかみ損ね：物が少し揺れる
                t.physicsBody?.applyImpulse(CGVector(dx: (t.position.x - aimX) * 0.3, dy: 6))
            }
        }
        target = nil
        let from = clawY
        let duration = (model.motionOff) ? 0.12 : Double((restY - from) / 330) + 0.08
        crane = .lifting
        tween = Tween(from: from, to: restY, duration: duration, delay: grabbed ? 0.12 : 0.22) { [weak self] in
            guard let self else { return }
            self.crane = self.heldNode == nil ? .idle : .holding
            if self.heldNode == nil { self.openProngs(true) }
            self.moveCrane(to: self.aimX)
            self.model?.craneChanged()
        }
    }

    /// 放す（いまの高さから落ちる）
    private func drop() {
        guard let node = heldNode, let model else { return }
        heldNode = nil
        node.held = false
        node.physicsBody = makeBody(node.kind)
        node.physicsBody?.velocity = CGVector(dx: 0, dy: -20)
        node.fallingFrom = node.position.y - node.size.height / 2
        node.zPosition = CGFloat(itemsLayer.children.count % 20) * 0.01
        openProngs(true)
        model.didRelease(node.kind)
        crane = .lifting
        let from = clawY
        let duration = model.motionOff ? 0.1 : Double((restY - from) / 380) + 0.05
        tween = Tween(from: from, to: restY, duration: duration) { [weak self] in
            self?.crane = .idle
            self?.model?.craneChanged()
        }
    }

    // MARK: 割れる

    func didBegin(_ contact: SKPhysicsContact) {
        let a = contact.bodyA.node as? ItemNode
        let b = contact.bodyB.node as? ItemNode
        for (n, other) in [(a, b), (b, a)] {
            guard let n, let from = n.fallingFrom, !n.gone else { continue }
            n.fallingFrom = nil
            let bottom = n.position.y - n.size.height / 2
            let fall = Double(max(0, from - bottom))
            if Rules.breaks(n.kind, fall: fall) {
                shatter(n)
                continue
            }
            if let other, !other.gone, other.position.y < n.position.y, Rules.crushes(n.kind, fall: fall, onto: other.kind) {
                shatter(other)
            }
            model?.didLand(n.kind, fall: fall)
        }
    }

    private func shatter(_ n: ItemNode) {
        guard !n.gone else { return }
        n.gone = true
        n.physicsBody = nil
        let at = n.position
        let color = UIColor(hex: n.kind.spec.body)
        model?.didBreak(n.kind)
        if model?.motionOff ?? false {
            n.removeFromParent()
            return
        }
        n.run(.sequence([.group([.scale(to: 1.12, duration: 0.06), .fadeOut(withDuration: 0.16)]), .removeFromParent()]))
        // かけら 7 つ（決まった散り方）
        for i in 0..<7 {
            let shard = SKShapeNode(path: {
                let p = CGMutablePath()
                p.move(to: .zero)
                p.addLine(to: CGPoint(x: 7, y: 2))
                p.addLine(to: CGPoint(x: 3, y: 8))
                p.closeSubpath()
                return p
            }())
            shard.fillColor = i % 2 == 0 ? color : color.darker(0.3)
            shard.strokeColor = color.darker(0.45)
            shard.lineWidth = 1
            shard.position = at
            fxLayer.addChild(shard)
            let a = CGFloat(i) / 7 * .pi + 0.2
            let d: CGFloat = 26 + CGFloat(i % 3) * 10
            shard.run(.sequence([
                .group([.move(by: CGVector(dx: cos(a) * d, dy: sin(a) * d * 0.7), duration: 0.32), .rotate(byAngle: 3, duration: 0.32)]),
                .group([.moveBy(x: 0, y: -18, duration: 0.3), .fadeOut(withDuration: 0.3)]),
                .removeFromParent(),
            ]))
        }
        floatText(tr("ガシャン", "CRASH"), at: CGPoint(x: at.x, y: at.y + 24), color: UIColor(hex: Palette.alert))
    }

    func floatText(_ text: String, at p: CGPoint, color: UIColor) {
        let l = SKLabelNode(text: text)
        l.fontName = "AvenirNext-Heavy"
        l.fontSize = 22
        l.fontColor = color
        l.position = p
        l.zPosition = 40
        fxLayer.addChild(l)
        if model?.motionOff ?? false {
            l.run(.sequence([.wait(forDuration: 0.8), .removeFromParent()]))
        } else {
            l.setScale(0.6)
            l.run(.sequence([.scale(to: 1.1, duration: 0.12), .group([.moveBy(x: 0, y: 26, duration: 0.7), .fadeOut(withDuration: 0.7)]), .removeFromParent()]))
        }
    }

    // MARK: 箱を閉じる

    /// 箱の中の物の上の端（箱の底から）
    var boxTops: [Double] { boxItems.map { Double($0.frame.maxY - floorY) } }

    /// 箱が閉じられるか（はみ出しなし・揺れが止まっている・持っていない）
    var canSeal: Bool { crane == .idle && Rules.canClose(tops: boxTops) }

    /// はみ出している物を赤く点滅させる
    func flashOverflow() {
        for n in boxItems where Double(n.frame.maxY - floorY) > Rules.boxHeight + Rules.lidTolerance {
            n.run(.sequence([.colorize(with: UIColor(hex: Palette.alert), colorBlendFactor: 0.6, duration: 0.1), .wait(forDuration: 0.25), .colorize(withColorBlendFactor: 0, duration: 0.2)]))
        }
        rimLine.strokeColor = UIColor(hex: Palette.alert)
        run(.wait(forDuration: 0.6)) { [weak self] in
            self?.rimLine.strokeColor = UIColor(hex: Palette.cardboardDeep).withAlphaComponent(0.55)
        }
    }

    /// 箱を閉じてトラックへ送る。中身と、たいせつな物が一番上だったかを返す
    func seal() -> (items: [ItemKind], keepsakeOnTop: Bool)? {
        let inside = boxItems
        guard !inside.isEmpty, canSeal else { return nil }
        let top = inside.max { $0.frame.maxY < $1.frame.maxY }
        let keepsakeOnTop = top?.kind.spec.keepsake ?? false
        let kinds = inside.sorted { $0.position.y < $1.position.y }.map(\.kind)
        crane = .busy
        let old = boxNode
        for n in inside {
            n.gone = true
            n.physicsBody = nil
            n.move(toParent: old)
        }
        // ふたを閉じてテープ → 右へ滑ってトラックへ → 新しい箱
        let tape = SKShapeNode(rect: CGRect(x: boxMinX - wall - 2, y: rimY - 4, width: boxMaxX - boxMinX + wall * 2 + 4, height: 12), cornerRadius: 2)
        tape.fillColor = UIColor(hex: Palette.tape)
        tape.strokeColor = UIColor(hex: Palette.cardboardDeep).withAlphaComponent(0.5)
        tape.zPosition = 9
        let lid = SKShapeNode(rect: CGRect(x: boxMinX - wall, y: rimY - 2, width: boxMaxX - boxMinX + wall * 2, height: 10), cornerRadius: 2)
        lid.fillColor = UIColor(hex: Palette.cardboard)
        lid.strokeColor = UIColor(hex: Palette.cardboardDeep)
        lid.lineWidth = 1.5
        lid.zPosition = 8
        old.addChild(lid)
        old.enumerateChildNodes(withName: "flap") { n, _ in n.removeFromParent() }
        // 閉じた箱の前に、大きな段ボールの面をかぶせる（中身は見えなくなる）
        let front = SKSpriteNode(texture: SKTexture(image: RoomPainter.boxFront(label: BoxLabel.dominant(kinds), number: (model?.closedBoxes.count ?? 0) + 1)))
        front.anchorPoint = .zero
        front.size = CGSize(width: boxMaxX - boxMinX + wall * 2, height: CGFloat(Rules.boxHeight) + 4)
        front.position = CGPoint(x: boxMinX - wall, y: floorY)
        front.zPosition = 8
        let motionOff = model?.motionOff ?? false
        front.alpha = motionOff ? 1 : 0
        old.addChild(front)
        tape.xScale = motionOff ? 1 : 0.01
        tape.position = .zero
        old.addChild(tape)
        old.children.forEach { $0.physicsBody = nil }
        if motionOff {
            old.removeFromParent()
            buildBox()
            crane = .idle
        } else {
            front.run(.fadeIn(withDuration: 0.18))
            tape.run(.sequence([.wait(forDuration: 0.18), .scaleX(to: 1, duration: 0.22)]))
            old.run(.sequence([.wait(forDuration: 0.55), .moveBy(x: 300, y: 0, duration: 0.42), .removeFromParent()]))
            run(.wait(forDuration: 0.75)) { [weak self] in
                guard let self else { return }
                self.buildBox()
                self.boxNode.position = CGPoint(x: 260, y: 0)
                self.boxNode.run(.moveTo(x: 0, duration: 0.3)) { [weak self] in
                    self?.crane = .idle
                    self?.model?.craneChanged()
                }
            }
        }
        return (kinds, keepsakeOnTop)
    }

    /// 部屋をやり直す・新しい部屋
    func reset() {
        removeAllActions()
        tween = nil
        crane = .idle
        heldNode = nil
        target = nil
        clawY = restY
        aimX = 130
        build()
    }

    /// いまの絵（撮影で止まった絵に差し替えるため）
    func freezeImage() -> UIImage? {
        guard let view, view.bounds.width > 0 else { return nil }
        let renderer = UIGraphicsImageRenderer(bounds: view.bounds)
        return renderer.image { _ in _ = view.drawHierarchy(in: view.bounds, afterScreenUpdates: true) }
    }

    // MARK: 毎フレーム

    override func update(_ currentTime: TimeInterval) {
        let dt = lastTime.map { min(0.05, currentTime - $0) } ?? 0
        lastTime = currentTime
        now += dt
        if var t = tween {
            t.elapsed += dt
            let k = CGFloat(min(1, max(0, (t.elapsed - t.delay) / max(t.duration, 0.0001))))
            clawY = t.from + (t.to - t.from) * k
            layoutClaw()
            if t.elapsed >= t.delay + t.duration {
                tween = nil
                t.done()
            } else {
                tween = t
            }
        }
        if crane == .lowering, let held = heldNode {
            let surface = surfaceBelow(x: aimX, halfWidth: held.size.width / 2 - 2, ignoring: held)
            let bottom = clawY - held.size.height + 4
            let stop = surface + 4
            if bottom > stop {
                clawY = max(stop + held.size.height - 4, clawY - CGFloat(Rules.lowerSpeed) * CGFloat(dt))
                layoutClaw()
            }
        }
        // 箱から落ちた・場面の外に出た物は床に戻す
        for n in items where n.position.y < -40 {
            n.position = CGPoint(x: 120, y: 300)
            n.physicsBody?.velocity = .zero
        }
        spawnIfNeeded()
        model?.sceneTick(floor: floorItems.count, inBox: boxItems.count)
    }
}

/// 背景・箱の絵（一度だけ描いてテクスチャにする）
@MainActor
enum RoomPainter {
    static func background(theme: RoomTheme, size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let c = ctx.cgContext
            let h = size.height
            // 上下を UIKit の向きで描く（SpriteKit の y = h - UIKit の y）
            UIColor(hex: theme.wall).setFill()
            c.fill(CGRect(origin: .zero, size: size))
            // 窓と朝の光（左上から差す光の帯）
            let window = CGRect(x: 40, y: 70, width: 120, height: 110)
            UIColor(hex: 0xCFE6F5).setFill()
            UIBezierPath(roundedRect: window, cornerRadius: 6).fill()
            UIColor(hex: 0xFFFFFF).withAlphaComponent(0.9).setFill()
            c.fill(CGRect(x: window.midX - 2, y: window.minY, width: 4, height: window.height))
            c.fill(CGRect(x: window.minX, y: window.midY - 2, width: window.width, height: 4))
            UIColor(hex: 0xFFFFFF).setStroke()
            let frame = UIBezierPath(roundedRect: window, cornerRadius: 6)
            frame.lineWidth = 5
            frame.stroke()
            UIColor(hex: 0xFFF4D6).withAlphaComponent(0.55).setFill()
            let beam = UIBezierPath()
            beam.move(to: CGPoint(x: window.minX, y: window.maxY))
            beam.addLine(to: CGPoint(x: window.maxX, y: window.maxY))
            beam.addLine(to: CGPoint(x: window.maxX + 150, y: h - Rules.floorY))
            beam.addLine(to: CGPoint(x: window.minX + 70, y: h - Rules.floorY))
            beam.close()
            beam.fill()
            // 壁に残った絵の跡（外した額の、少し明るい四角）
            UIColor.white.withAlphaComponent(0.35).setFill()
            UIBezierPath(roundedRect: CGRect(x: 300, y: 64, width: 64, height: 80), cornerRadius: 2).fill()
            UIColor(hex: theme.wall).darker(0.12).setFill()
            c.fill(CGRect(x: 330, y: 52, width: 4, height: 6))
            // 巾木
            UIColor(hex: theme.wall).darker(0.1).setFill()
            c.fill(CGRect(x: 0, y: h - Rules.floorY - 8, width: size.width, height: 8))
            // 床（木目）
            let floor = UIColor(hex: theme.floor)
            floor.setFill()
            c.fill(CGRect(x: 0, y: h - Rules.floorY, width: size.width, height: Rules.floorY))
            floor.darker(0.1).setFill()
            for i in 0..<9 {
                c.fill(CGRect(x: CGFloat(i) * 56 + CGFloat(i % 2) * 20, y: h - Rules.floorY, width: 1.5, height: Rules.floorY))
            }
            c.fill(CGRect(x: 0, y: h - Rules.floorY / 2, width: size.width, height: 1))
        }
    }

    /// 開いた箱の内側（奥の面。マジックで番号）
    static func boxBack(number: Int) -> UIImage {
        let size = CGSize(width: Rules.boxWidth + 14, height: Rules.boxHeight + 26)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let r = CGRect(x: 0, y: 26, width: size.width, height: Rules.boxHeight)
            UIColor(hex: Palette.cardboard).darker(0.14).setFill()
            UIBezierPath(roundedRect: r, cornerRadius: 3).fill()
            // 奥のふた（開いて立っている）
            UIColor(hex: Palette.cardboard).darker(0.06).setFill()
            ctx.cgContext.fill(CGRect(x: 7, y: 4, width: size.width - 14, height: 24))
            UIColor(hex: Palette.cardboardDeep).withAlphaComponent(0.5).setFill()
            ctx.cgContext.fill(CGRect(x: 7, y: 26, width: size.width - 14, height: 1.5))
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont(name: "MarkerFelt-Wide", size: 40) ?? UIFont.systemFont(ofSize: 40, weight: .heavy),
                .foregroundColor: UIColor(hex: Palette.ink).withAlphaComponent(0.18),
            ]
            let s = NSAttributedString(string: "\(number)", attributes: attrs)
            let b = s.size()
            s.draw(at: CGPoint(x: (size.width - b.width) / 2, y: 26 + (Rules.boxHeight - b.height) / 2))
        }
    }

    /// 閉じた箱の前の面（分類と番号をマジックで）
    static func boxFront(label: BoxLabel, number: Int) -> UIImage {
        let size = CGSize(width: Rules.boxWidth + 14, height: Rules.boxHeight + 4)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIColor(hex: Palette.cardboard).setFill()
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 3).fill()
            UIColor(hex: Palette.cardboardDeep).withAlphaComponent(0.35).setFill()
            ctx.cgContext.fill(CGRect(x: 0, y: size.height * 0.5, width: size.width, height: 1.5))
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont(name: "MarkerFelt-Wide", size: 34) ?? UIFont.systemFont(ofSize: 34, weight: .heavy),
                .foregroundColor: UIColor(hex: Palette.ink),
            ]
            let s = NSAttributedString(string: "\(label.text) #\(number)", attributes: attrs)
            let b = s.size()
            s.draw(at: CGPoint(x: (size.width - b.width) / 2, y: (size.height - b.height) / 2 + 10))
        }
    }
}
