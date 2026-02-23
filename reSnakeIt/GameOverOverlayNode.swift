//
//  GameOverOverlayNode.swift
//  reSnakeIt
//
//  Created by Codex on 22.02.2026.
//

import SpriteKit

final class GameOverOverlayNode: SKNode {

    private let dimNode = SKShapeNode()
    private let panelNode = SKShapeNode()
    private let titleGlowNode = SKLabelNode(fontNamed: "Menlo-Bold")
    private let titleNode = SKLabelNode(fontNamed: "Menlo-Bold")
    private let reasonGlowNode = SKLabelNode(fontNamed: "Menlo")
    private let reasonNode = SKLabelNode(fontNamed: "Menlo")
    private let scoreGlowNode = SKLabelNode(fontNamed: "Menlo-Bold")
    private let scoreNode = SKLabelNode(fontNamed: "Menlo-Bold")
    private let recordGlowNode = SKLabelNode(fontNamed: "Menlo")
    private let recordNode = SKLabelNode(fontNamed: "Menlo")
    private let menuButtonNode = SKShapeNode()
    private let menuIconGlowNode = SKLabelNode(fontNamed: "Menlo-Bold")
    private let menuIconNode = SKLabelNode(fontNamed: "Menlo-Bold")
    private let restartButtonNode = SKShapeNode()
    private let restartGlowLabelNode = SKLabelNode(fontNamed: "Menlo")
    private let restartLabelNode = SKLabelNode(fontNamed: "Menlo")

    var onRestart: (() -> Void)?
    var onMainMenu: (() -> Void)?

    private var accentColor: SKColor = .white
    private var panelFillColor: SKColor = SKColor(white: 0.09, alpha: 0.96)
    private var titleWordGlow: CGFloat = 1
    private var nextGlowJitter: TimeInterval = 0
    private var nextWordBlinkAttempt: TimeInterval = 0
    private var wordBlinkUntil: TimeInterval = 0
    private var nextCharBlinkAttempt: TimeInterval = 0
    private var charBlinkUntil: [TimeInterval] = Array(repeating: 0, count: 9) // title chars

    override init() {
        super.init()
        setupNodes()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupNodes()
    }

    func updateLayout(sceneSize: CGSize, cellSize: CGFloat) {
        removeAllActions()

        let dimSize = CGSize(width: sceneSize.width, height: sceneSize.height)
        dimNode.path = CGPath(
            roundedRect: CGRect(
                x: -dimSize.width * 0.5,
                y: -dimSize.height * 0.5,
                width: dimSize.width,
                height: dimSize.height
            ),
            cornerWidth: 0,
            cornerHeight: 0,
            transform: nil
        )

        let panelWidth = min(sceneSize.width * 0.62, max(250, cellSize * 14))
        let panelHeight = min(sceneSize.height * 0.58, max(220, cellSize * 10.5))
        panelNode.path = CGPath(
            roundedRect: CGRect(
                x: -panelWidth * 0.5,
                y: -panelHeight * 0.5,
                width: panelWidth,
                height: panelHeight
            ),
            cornerWidth: 14,
            cornerHeight: 14,
            transform: nil
        )

        let titleSize = max(14, cellSize * 0.78)
        titleGlowNode.fontSize = titleSize
        titleNode.fontSize = titleSize
        titleGlowNode.position = CGPoint(x: 0, y: panelHeight * 0.29)
        titleNode.position = titleGlowNode.position

        let reasonSize = max(10, cellSize * 0.42)
        reasonGlowNode.fontSize = reasonSize
        reasonNode.fontSize = reasonSize
        reasonGlowNode.position = CGPoint(x: 0, y: panelHeight * 0.11)
        reasonNode.position = reasonGlowNode.position

        let scoreSize = max(12, cellSize * 0.5)
        scoreGlowNode.fontSize = scoreSize
        scoreNode.fontSize = scoreSize
        scoreGlowNode.position = CGPoint(x: 0, y: -panelHeight * 0.02)
        scoreNode.position = scoreGlowNode.position

        let recordSize = max(9, cellSize * 0.34)
        recordGlowNode.fontSize = recordSize
        recordNode.fontSize = recordSize
        recordGlowNode.position = CGPoint(x: 0, y: -panelHeight * 0.14)
        recordNode.position = recordGlowNode.position

        let buttonHeight = max(34, cellSize * 1.45)
        let menuButtonSize = CGSize(width: max(buttonHeight, panelWidth * 0.19), height: buttonHeight)
        let restartButtonSize = CGSize(width: panelWidth * 0.52, height: buttonHeight)
        let buttonsY = -panelHeight * 0.31
        let buttonGap = max(10, cellSize * 0.45)

        menuButtonNode.path = CGPath(
            roundedRect: CGRect(
                x: -menuButtonSize.width * 0.5,
                y: -menuButtonSize.height * 0.5,
                width: menuButtonSize.width,
                height: menuButtonSize.height
            ),
            cornerWidth: 10,
            cornerHeight: 10,
            transform: nil
        )
        menuButtonNode.position = CGPoint(
            x: -(restartButtonSize.width * 0.5 + buttonGap * 0.5 + menuButtonSize.width * 0.5),
            y: buttonsY
        )

        restartButtonNode.path = CGPath(
            roundedRect: CGRect(
                x: -restartButtonSize.width * 0.5,
                y: -restartButtonSize.height * 0.5,
                width: restartButtonSize.width,
                height: restartButtonSize.height
            ),
            cornerWidth: 10,
            cornerHeight: 10,
            transform: nil
        )
        restartButtonNode.position = CGPoint(
            x: menuButtonSize.width * 0.5 + buttonGap * 0.5,
            y: buttonsY
        )

        let menuIconSize = max(12, cellSize * 0.58)
        menuIconGlowNode.fontSize = menuIconSize
        menuIconNode.fontSize = menuIconSize
        menuIconNode.position = CGPoint(x: 0, y: -menuIconSize * 0.35)
        menuIconGlowNode.position = menuIconNode.position

        restartLabelNode.fontSize = max(12, cellSize * 0.54)
        restartLabelNode.position = CGPoint(x: 0, y: -restartLabelNode.fontSize * 0.35)
        restartGlowLabelNode.fontSize = restartLabelNode.fontSize
        restartGlowLabelNode.position = restartLabelNode.position
    }

    func applyTheme(accent: SKColor, panelFill: SKColor) {
        accentColor = accent
        panelFillColor = panelFill

        panelNode.fillColor = panelFillColor
        panelNode.strokeColor = accentColor.withAlphaComponent(0.14)

        titleGlowNode.fontColor = accentColor.withAlphaComponent(0.24)
        titleNode.fontColor = accentColor.withAlphaComponent(0.95)
        reasonGlowNode.fontColor = accentColor.withAlphaComponent(0.14)
        reasonNode.fontColor = accentColor.withAlphaComponent(0.72)
        scoreGlowNode.fontColor = accentColor.withAlphaComponent(0.18)
        scoreNode.fontColor = accentColor.withAlphaComponent(0.9)
        recordGlowNode.fontColor = accentColor.withAlphaComponent(0.12)
        recordNode.fontColor = accentColor.withAlphaComponent(0.7)

        menuButtonNode.fillColor = accentColor.withAlphaComponent(0.05)
        menuButtonNode.strokeColor = accentColor.withAlphaComponent(0.3)
        menuIconGlowNode.fontColor = accentColor.withAlphaComponent(0.18)
        menuIconNode.fontColor = accentColor.withAlphaComponent(0.92)

        restartButtonNode.fillColor = accentColor.withAlphaComponent(0.05)
        restartButtonNode.strokeColor = accentColor.withAlphaComponent(0.3)
        restartGlowLabelNode.fontColor = accentColor.withAlphaComponent(0.18)
        restartLabelNode.fontColor = accentColor.withAlphaComponent(0.92)
    }

    func setOutcome(title: String, reason: String) {
        titleGlowNode.text = title
        titleNode.text = title
        reasonGlowNode.text = reason
        reasonNode.text = reason
        charBlinkUntil = Array(repeating: 0, count: max(1, title.count))
    }

    func setScoreInfo(score: Int, hiScore: Int, isNewHighScore: Bool) {
        scoreGlowNode.text = "SCORE \(score)"
        scoreNode.text = "SCORE \(score)"
        if isNewHighScore {
            recordGlowNode.text = "NEW HI SCORE"
            recordNode.text = "NEW HI SCORE"
            recordNode.alpha = 0.92
            recordGlowNode.alpha = 0.18
        } else {
            recordGlowNode.text = "HI \(hiScore)"
            recordNode.text = "HI \(hiScore)"
            recordNode.alpha = 0.7
            recordGlowNode.alpha = 0.12
        }
    }

    func updateEffects(currentTime: TimeInterval) {
        if currentTime >= nextGlowJitter {
            titleWordGlow = CGFloat.random(in: 0.82...1.15)
            nextGlowJitter = currentTime + TimeInterval.random(in: 0.05...0.16)
        }

        if currentTime >= nextWordBlinkAttempt {
            nextWordBlinkAttempt = currentTime + TimeInterval.random(in: 0.9...2.2)
            if CGFloat.random(in: 0...1) < 0.1 {
                wordBlinkUntil = currentTime + TimeInterval.random(in: 0.03...0.09)
            }
        }

        if currentTime >= nextCharBlinkAttempt {
            nextCharBlinkAttempt = currentTime + TimeInterval.random(in: 0.3...0.9)
            if CGFloat.random(in: 0...1) < 0.28, !charBlinkUntil.isEmpty {
                let idx = Int.random(in: 0..<charBlinkUntil.count)
                charBlinkUntil[idx] = currentTime + TimeInterval.random(in: 0.02...0.07)
            }
        }

        let wholeBlink = currentTime < wordBlinkUntil
        var anyCharBlink = false
        for end in charBlinkUntil where currentTime < end {
            anyCharBlink = true
            break
        }

        // Single label fallback approximation for "broken neon" on word:
        // mix full-word blinks with glow jitter and quick dim dips.
        if wholeBlink {
            titleNode.alpha = 0.15
            titleGlowNode.alpha = 0.02
        } else if anyCharBlink {
            titleNode.alpha = 0.75
            titleGlowNode.alpha = 0.12 * titleWordGlow
        } else {
            titleNode.alpha = 1.0
            titleGlowNode.alpha = 0.24 * titleWordGlow
        }
    }

    func handleTap(at pointInScene: CGPoint) -> Bool {
        if menuButtonNode.contains(pointInScene) {
            onMainMenu?()
            return true
        }
        guard restartButtonNode.contains(pointInScene) else { return false }
        onRestart?()
        return true
    }
}

private extension GameOverOverlayNode {

    func setupNodes() {
        zPosition = 100

        dimNode.fillColor = SKColor(white: 0.0, alpha: 0.22)
        dimNode.strokeColor = .clear
        addChild(dimNode)

        panelNode.fillColor = SKColor(white: 0.09, alpha: 0.96)
        panelNode.strokeColor = SKColor(white: 1.0, alpha: 0.08)
        panelNode.lineWidth = 1
        addChild(panelNode)

        titleGlowNode.text = "GAME OVER"
        titleGlowNode.fontColor = SKColor(white: 1.0, alpha: 0.22)
        titleGlowNode.verticalAlignmentMode = .center
        titleGlowNode.horizontalAlignmentMode = .center
        addChild(titleGlowNode)

        titleNode.text = "GAME OVER"
        titleNode.fontColor = SKColor(white: 1.0, alpha: 0.9)
        titleNode.verticalAlignmentMode = .center
        titleNode.horizontalAlignmentMode = .center
        addChild(titleNode)

        reasonGlowNode.text = ""
        reasonGlowNode.fontColor = SKColor(white: 1.0, alpha: 0.14)
        reasonGlowNode.verticalAlignmentMode = .center
        reasonGlowNode.horizontalAlignmentMode = .center
        addChild(reasonGlowNode)

        reasonNode.text = ""
        reasonNode.fontColor = SKColor(white: 1.0, alpha: 0.72)
        reasonNode.verticalAlignmentMode = .center
        reasonNode.horizontalAlignmentMode = .center
        addChild(reasonNode)

        scoreGlowNode.text = ""
        scoreGlowNode.fontColor = SKColor(white: 1.0, alpha: 0.18)
        scoreGlowNode.verticalAlignmentMode = .center
        scoreGlowNode.horizontalAlignmentMode = .center
        addChild(scoreGlowNode)

        scoreNode.text = ""
        scoreNode.fontColor = SKColor(white: 1.0, alpha: 0.9)
        scoreNode.verticalAlignmentMode = .center
        scoreNode.horizontalAlignmentMode = .center
        addChild(scoreNode)

        recordGlowNode.text = ""
        recordGlowNode.fontColor = SKColor(white: 1.0, alpha: 0.12)
        recordGlowNode.verticalAlignmentMode = .center
        recordGlowNode.horizontalAlignmentMode = .center
        addChild(recordGlowNode)

        recordNode.text = ""
        recordNode.fontColor = SKColor(white: 1.0, alpha: 0.7)
        recordNode.verticalAlignmentMode = .center
        recordNode.horizontalAlignmentMode = .center
        addChild(recordNode)

        menuButtonNode.fillColor = SKColor(white: 1.0, alpha: 0.08)
        menuButtonNode.strokeColor = SKColor(white: 1.0, alpha: 0.35)
        menuButtonNode.lineWidth = 1
        addChild(menuButtonNode)

        menuIconGlowNode.text = "⌂"
        menuIconGlowNode.fontColor = SKColor(white: 1.0, alpha: 0.18)
        menuIconGlowNode.verticalAlignmentMode = .center
        menuIconGlowNode.horizontalAlignmentMode = .center
        menuButtonNode.addChild(menuIconGlowNode)

        menuIconNode.text = "⌂"
        menuIconNode.fontColor = SKColor(white: 1.0, alpha: 0.9)
        menuIconNode.verticalAlignmentMode = .center
        menuIconNode.horizontalAlignmentMode = .center
        menuButtonNode.addChild(menuIconNode)

        restartButtonNode.fillColor = SKColor(white: 1.0, alpha: 0.08)
        restartButtonNode.strokeColor = SKColor(white: 1.0, alpha: 0.35)
        restartButtonNode.lineWidth = 1
        addChild(restartButtonNode)

        restartGlowLabelNode.text = "RESTART"
        restartGlowLabelNode.fontColor = SKColor(white: 1.0, alpha: 0.18)
        restartGlowLabelNode.verticalAlignmentMode = .center
        restartGlowLabelNode.horizontalAlignmentMode = .center
        restartButtonNode.addChild(restartGlowLabelNode)

        restartLabelNode.text = "RESTART"
        restartLabelNode.fontColor = SKColor(white: 1.0, alpha: 0.9)
        restartLabelNode.verticalAlignmentMode = .center
        restartLabelNode.horizontalAlignmentMode = .center
        restartButtonNode.addChild(restartLabelNode)
    }
}
