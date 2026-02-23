//
//  StartScreenOverlayNode.swift
//  reSnakeIt
//
//  Created by Codex on 23.02.2026.
//

import SpriteKit

final class StartScreenOverlayNode: SKNode {

    private struct NeonChar {
        let glow: SKLabelNode
        let base: SKLabelNode
    }

    private let dimNode = SKShapeNode()
    private let gameTitleGlow = SKLabelNode(fontNamed: "Menlo-Bold")
    private let gameTitle = SKLabelNode(fontNamed: "Menlo-Bold")
    private let subtitleGlow = SKLabelNode(fontNamed: "Menlo")
    private let subtitle = SKLabelNode(fontNamed: "Menlo")
    private let scoresHeaderGlow = SKLabelNode(fontNamed: "Menlo")
    private let scoresHeader = SKLabelNode(fontNamed: "Menlo")
    private var scoreLineGlows: [SKLabelNode] = []
    private var scoreLines: [SKLabelNode] = []

    private var chars: [NeonChar] = []
    private var bustedIndices: Set<Int> = []
    private var charBlinkUntil: [TimeInterval] = []
    private var wordBlinkUntil: TimeInterval = 0
    private var nextWordBlinkAttempt: TimeInterval = 0
    private var nextCharBlinkAttempt: TimeInterval = 0
    private var nextGlowJitter: TimeInterval = 0
    private var glowMultiplier: CGFloat = 1

    var onStart: (() -> Void)?

    override init() {
        super.init()
        setup()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }

    func configure(sceneSize: CGSize, cellSize: CGFloat, accent: SKColor, highScoreLines: [String]) {
        zPosition = 130

        dimNode.path = CGPath(
            rect: CGRect(x: -sceneSize.width * 0.5, y: -sceneSize.height * 0.5, width: sceneSize.width, height: sceneSize.height),
            transform: nil
        )
        dimNode.fillColor = SKColor(white: 0, alpha: 0.08)

        gameTitleGlow.text = "reSnakeIt"
        gameTitle.text = "reSnakeIt"
        gameTitleGlow.fontSize = max(18, cellSize * 0.9)
        gameTitle.fontSize = gameTitleGlow.fontSize
        gameTitleGlow.fontColor = accent.withAlphaComponent(0.18)
        gameTitle.fontColor = accent.withAlphaComponent(0.92)
        gameTitleGlow.position = CGPoint(x: 0, y: max(70, cellSize * 3.4))
        gameTitle.position = gameTitleGlow.position

        let titleText = "START GAME"
        rebuildTitle(text: titleText, fontSize: max(20, cellSize * 0.95), accent: accent)

        subtitleGlow.text = "TAP TO BEGIN"
        subtitle.text = "TAP TO BEGIN"
        subtitleGlow.fontSize = max(11, cellSize * 0.42)
        subtitle.fontSize = subtitleGlow.fontSize
        subtitleGlow.fontColor = accent.withAlphaComponent(0.13)
        subtitle.fontColor = accent.withAlphaComponent(0.78)
        subtitleGlow.position = CGPoint(x: 0, y: -max(36, cellSize * 1.7))
        subtitle.position = subtitleGlow.position

        scoresHeaderGlow.text = "TOP 5 / TRY"
        scoresHeader.text = "TOP 5 / TRY"
        scoresHeaderGlow.fontSize = max(10, cellSize * 0.36)
        scoresHeader.fontSize = scoresHeaderGlow.fontSize
        scoresHeaderGlow.fontColor = accent.withAlphaComponent(0.12)
        scoresHeader.fontColor = accent.withAlphaComponent(0.68)
        let listTopY = -max(68, cellSize * 3.0)
        scoresHeaderGlow.position = CGPoint(x: 0, y: listTopY)
        scoresHeader.position = scoresHeaderGlow.position

        ensureScoreLineNodes(count: 5)
        let lineSpacing = max(14, cellSize * 0.58)
        for i in 0..<5 {
            let text = i < highScoreLines.count ? highScoreLines[i] : ""
            scoreLineGlows[i].text = text
            scoreLines[i].text = text
            let y = listTopY - max(14, cellSize * 0.75) - CGFloat(i) * lineSpacing
            scoreLineGlows[i].fontSize = max(10, cellSize * 0.34)
            scoreLines[i].fontSize = scoreLineGlows[i].fontSize
            scoreLineGlows[i].fontColor = accent.withAlphaComponent(0.08)
            scoreLines[i].fontColor = accent.withAlphaComponent(text.isEmpty ? 0.22 : 0.56)
            scoreLineGlows[i].position = CGPoint(x: 0, y: y)
            scoreLines[i].position = scoreLineGlows[i].position
        }
    }

    func updateEffects(currentTime: TimeInterval) {
        guard !chars.isEmpty else { return }

        if currentTime >= nextGlowJitter {
            nextGlowJitter = currentTime + TimeInterval.random(in: 0.05...0.15)
            glowMultiplier = CGFloat.random(in: 0.85...1.18)
        }

        if currentTime >= nextWordBlinkAttempt {
            nextWordBlinkAttempt = currentTime + TimeInterval.random(in: 1.0...2.3)
            if CGFloat.random(in: 0...1) < 0.09 {
                wordBlinkUntil = currentTime + TimeInterval.random(in: 0.03...0.08)
            }
        }

        if currentTime >= nextCharBlinkAttempt {
            nextCharBlinkAttempt = currentTime + TimeInterval.random(in: 0.25...0.7)
            if CGFloat.random(in: 0...1) < 0.35 {
                let candidates = chars.indices.filter { !bustedIndices.contains($0) }
                if let idx = candidates.randomElement() {
                    charBlinkUntil[idx] = currentTime + TimeInterval.random(in: 0.02...0.07)
                }
            }
        }

        let wholeBlink = currentTime < wordBlinkUntil
        for i in chars.indices {
            let isBusted = bustedIndices.contains(i)
            let charBlink = currentTime < charBlinkUntil[i]

            let baseAlpha: CGFloat = isBusted ? 0.45 : 0.94
            let glowAlpha: CGFloat = isBusted ? 0.08 : 0.24

            if wholeBlink || charBlink {
                chars[i].base.alpha = isBusted ? 0.12 : 0.2
                chars[i].glow.alpha = 0.02
            } else {
                chars[i].base.alpha = baseAlpha
                chars[i].glow.alpha = glowAlpha * glowMultiplier
            }
        }

        let subtitleJitter = CGFloat.random(in: 0.92...1.08)
        subtitleGlow.alpha = 0.11 * subtitleJitter
        subtitle.alpha = 0.72
        scoresHeaderGlow.alpha = 0.09 * subtitleJitter
        scoresHeader.alpha = 0.62
        for i in scoreLineGlows.indices {
            let textEmpty = (scoreLines[i].text ?? "").isEmpty
            scoreLineGlows[i].alpha = textEmpty ? 0.03 : 0.08 * CGFloat.random(in: 0.9...1.08)
            scoreLines[i].alpha = textEmpty ? 0.18 : 0.56
        }
    }

    func handleTap(at pointInScene: CGPoint) -> Bool {
        let bounds = frame.insetBy(dx: -40, dy: -40)
        guard bounds.contains(pointInScene) else { return false }
        onStart?()
        return true
    }
}

private extension StartScreenOverlayNode {

    func setup() {
        dimNode.strokeColor = .clear
        addChild(dimNode)
        addChild(gameTitleGlow)
        addChild(gameTitle)
        addChild(subtitleGlow)
        addChild(subtitle)
        addChild(scoresHeaderGlow)
        addChild(scoresHeader)
    }

    func ensureScoreLineNodes(count: Int) {
        guard scoreLines.count != count || scoreLineGlows.count != count else { return }

        for node in scoreLineGlows { node.removeFromParent() }
        for node in scoreLines { node.removeFromParent() }
        scoreLineGlows.removeAll(keepingCapacity: true)
        scoreLines.removeAll(keepingCapacity: true)

        for _ in 0..<count {
            let glow = SKLabelNode(fontNamed: "Menlo")
            glow.verticalAlignmentMode = .center
            glow.horizontalAlignmentMode = .center
            addChild(glow)
            scoreLineGlows.append(glow)

            let base = SKLabelNode(fontNamed: "Menlo")
            base.verticalAlignmentMode = .center
            base.horizontalAlignmentMode = .center
            addChild(base)
            scoreLines.append(base)
        }
    }

    func rebuildTitle(text: String, fontSize: CGFloat, accent: SKColor) {
        for char in chars {
            char.glow.removeFromParent()
            char.base.removeFromParent()
        }
        chars.removeAll(keepingCapacity: true)

        let characters = Array(text)
        charBlinkUntil = Array(repeating: 0, count: characters.count)

        let step = fontSize * 0.62
        let startX = -CGFloat(characters.count - 1) * step * 0.5

        let bustedCount = max(1, characters.count / 6)
        bustedIndices = Set((0..<characters.count).shuffled().prefix(bustedCount))

        for (idx, ch) in characters.enumerated() {
            let glow = SKLabelNode(fontNamed: "Menlo-Bold")
            glow.text = String(ch)
            glow.fontSize = fontSize
            glow.fontColor = accent.withAlphaComponent(0.24)
            glow.verticalAlignmentMode = .center
            glow.horizontalAlignmentMode = .center
            glow.position = CGPoint(x: startX + CGFloat(idx) * step, y: 0)

            let base = SKLabelNode(fontNamed: "Menlo-Bold")
            base.text = String(ch)
            base.fontSize = fontSize
            base.fontColor = accent.withAlphaComponent(0.95)
            base.verticalAlignmentMode = .center
            base.horizontalAlignmentMode = .center
            base.position = glow.position

            addChild(glow)
            addChild(base)
            chars.append(NeonChar(glow: glow, base: base))
        }
    }
}
