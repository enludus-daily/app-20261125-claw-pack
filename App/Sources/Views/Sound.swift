import AVFoundation

/// 効果音（端末の中で作る。録音したファイルは持たない）。
/// 引っ越しの朝：クレーンのモーターのウィーン、つかむカチャ、段ボールにトン、割れ物のガシャン、
/// ガムテープのビーッ、トラックへ送るポン、部屋が片付いたときの口笛の 4 音。消音スイッチに従い、ほかのアプリの音と混ぜる（.ambient）
@MainActor
final class SoundBox {
    static let shared = SoundBox()

    enum Cue: Hashable {
        case tap, whirr, grab, miss, thud(Int), crash, tape, truck, clear, warn, star
    }

    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var buffers: [Cue: AVAudioPCMBuffer] = [:]
    private var nextPlayer = 0
    private var prepared = false
    private let rate = 44_100.0
    private lazy var format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1)

    /// 音量の段階：触る 0.3・モーター 0.35・つかむ 0.5・落ちる 0.45〜0.7・テープ 0.55・割れる 0.8・片付いた 0.8
    private func volume(_ cue: Cue) -> Float {
        switch cue {
        case .tap: 0.3
        case .whirr: 0.35
        case .grab, .miss: 0.5
        case .thud(let w): 0.4 + Float(w) * 0.08
        case .tape, .truck: 0.55
        case .warn: 0.6
        case .crash, .clear, .star: 0.8
        }
    }

    private func prepare() -> Bool {
        if prepared { return engine.isRunning || ((try? engine.start()) != nil) }
        guard let format else { return false }
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        for _ in 0..<6 {
            let p = AVAudioPlayerNode()
            engine.attach(p)
            engine.connect(p, to: engine.mainMixerNode, format: format)
            players.append(p)
        }
        prepared = true
        return (try? engine.start()) != nil
    }

    func play(_ cue: Cue) {
        guard prepare(), engine.isRunning else { return }
        let buffer: AVAudioPCMBuffer
        if let b = buffers[cue] {
            buffer = b
        } else {
            guard let b = make(cue) else { return }
            buffers[cue] = b
            buffer = b
        }
        let player = players[nextPlayer]
        nextPlayer = (nextPlayer + 1) % players.count
        player.stop()
        player.volume = volume(cue)
        player.scheduleBuffer(buffer, at: nil, options: [])
        player.play()
    }

    private struct Tone {
        var freq: Double
        var amp: Double
        var decay: Double
        var delay: Double = 0
        var glide: Double? = nil
    }

    private func make(_ cue: Cue) -> AVAudioPCMBuffer? {
        switch cue {
        case .tap:
            return render(0.06, noise: 0.1, noiseDecay: 120, tones: [Tone(freq: 900, amp: 0.2, decay: 90)])
        case .whirr:
            // モーター：低いうなりが少し上がる
            return render(0.5, noise: 0.05, noiseDecay: 4, tones: [Tone(freq: 110, amp: 0.25, decay: 3, glide: 150), Tone(freq: 220, amp: 0.1, decay: 3, glide: 300)])
        case .grab:
            // つめが閉じる：カチャッ
            return render(0.14, noise: 0.3, noiseDecay: 70, tones: [Tone(freq: 1800, amp: 0.15, decay: 60), Tone(freq: 2600, amp: 0.1, decay: 80, delay: 0.04)])
        case .miss:
            // つかみ損ね：空振りのカシャ＋下がる音
            return render(0.3, noise: 0.15, noiseDecay: 60, tones: [Tone(freq: 520, amp: 0.25, decay: 10, glide: 330)])
        case .thud(let weight):
            // 段ボールにトン（重いほど低い）
            let f = 200.0 - Double(weight) * 30
            return render(0.2, noise: 0.25, noiseDecay: 45, tones: [Tone(freq: f, amp: 0.45, decay: 24, glide: f * 0.7)])
        case .crash:
            // 割れ物：ガシャン（高いノイズと、ばらばらの鈴の音）
            return render(0.7, noise: 0.55, noiseDecay: 9, tones: [3100.0, 4200, 2600, 5200].enumerated().map { i, f in
                Tone(freq: f, amp: 0.12, decay: 14, delay: Double(i) * 0.05)
            })
        case .tape:
            // ガムテープ：ビーッ（ノイズが上がる）
            return render(0.45, noise: 0.35, noiseDecay: 2, tones: [Tone(freq: 700, amp: 0.06, decay: 2, glide: 1400)])
        case .truck:
            // トラックへ：ポン・ポン
            return render(0.4, noise: 0, tones: [Tone(freq: 392, amp: 0.3, decay: 9), Tone(freq: 523.3, amp: 0.3, decay: 9, delay: 0.12)])
        case .warn:
            return render(0.4, noise: 0, tones: [Tone(freq: 440, amp: 0.25, decay: 6), Tone(freq: 415, amp: 0.25, decay: 6, delay: 0.16)])
        case .star:
            return render(0.35, noise: 0, tones: [Tone(freq: 1568, amp: 0.22, decay: 10), Tone(freq: 2093, amp: 0.18, decay: 10, delay: 0.06)])
        case .clear:
            // 口笛のような 4 音（片付いた）
            let notes = [659.3, 784.0, 1046.5, 1318.5]
            return render(1.2, noise: 0, tones: notes.enumerated().map { i, f in Tone(freq: f, amp: 0.24, decay: 4, delay: Double(i) * 0.11) })
        }
    }

    private func render(_ seconds: Double, noise: Double, noiseDecay: Double = 60, tones: [Tone]) -> AVAudioPCMBuffer? {
        guard let format else { return nil }
        let frames = AVAudioFrameCount(seconds * rate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames), let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frames
        var rng = SeededRNG(seed: 22)
        var phases = Array(repeating: 0.0, count: tones.count)
        for i in 0..<Int(frames) {
            let t = Double(i) / rate
            var v = 0.0
            for (k, p) in tones.enumerated() where t >= p.delay {
                let local = t - p.delay
                var f = p.freq
                if let to = p.glide {
                    let x = min(1, local / max(0.01, seconds - p.delay))
                    f = p.freq + (to - p.freq) * x
                }
                phases[k] += 2 * .pi * f / rate
                let attack = min(1, local / 0.003)
                v += sin(phases[k]) * p.amp * exp(-local * p.decay) * attack
            }
            if noise > 0 {
                let n = rng.unit() * 2 - 1
                v += n * noise * exp(-t * noiseDecay)
            }
            let tail = min(1, (seconds - t) / 0.01)
            data[i] = Float(max(-1, min(1, v * tail)))
        }
        return buffer
    }
}
