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
    private let titleNode = SKLabelNode(fontNamed: "Menlo")
    private let restartButtonNode = SKShapeNode()
    private let restartLabelNode = SKLabelNode(fontNamed: "Menlo")

    var onRestart: (() -> Void)?

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

        let panelWidth = min(sceneSize.width * 0.58, max(220, cellSize * 12))
        let panelHeight = min(sceneSize.height * 0.42, max(120, cellSize * 5.6))
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

        titleNode.fontSize = max(14, cellSize * 0.78)
        titleNode.position = CGPoint(x: 0, y: panelHeight * 0.16)

        let buttonSize = CGSize(width: panelWidth * 0.6, height: max(34, cellSize * 1.45))
        restartButtonNode.path = CGPath(
            roundedRect: CGRect(
                x: -buttonSize.width * 0.5,
                y: -buttonSize.height * 0.5,
                width: buttonSize.width,
                height: buttonSize.height
            ),
            cornerWidth: 10,
            cornerHeight: 10,
            transform: nil
        )
        restartButtonNode.position = CGPoint(x: 0, y: -panelHeight * 0.18)

        restartLabelNode.fontSize = max(12, cellSize * 0.54)
        restartLabelNode.position = CGPoint(x: 0, y: -restartLabelNode.fontSize * 0.35)
    }

    func handleTap(at pointInScene: CGPoint) -> Bool {
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

        titleNode.text = "GAME OVER"
        titleNode.fontColor = SKColor(white: 1.0, alpha: 0.9)
        titleNode.verticalAlignmentMode = .center
        titleNode.horizontalAlignmentMode = .center
        addChild(titleNode)

        restartButtonNode.fillColor = SKColor(white: 1.0, alpha: 0.08)
        restartButtonNode.strokeColor = SKColor(white: 1.0, alpha: 0.35)
        restartButtonNode.lineWidth = 1
        addChild(restartButtonNode)

        restartLabelNode.text = "RESTART"
        restartLabelNode.fontColor = SKColor(white: 1.0, alpha: 0.9)
        restartLabelNode.verticalAlignmentMode = .center
        restartLabelNode.horizontalAlignmentMode = .center
        restartButtonNode.addChild(restartLabelNode)
    }
}
