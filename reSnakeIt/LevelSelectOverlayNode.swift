//
//  LevelSelectOverlayNode.swift
//  reSnakeIt
//
//  Created by Codex on 22.02.2026.
//

import SpriteKit

final class LevelSelectOverlayNode: SKNode {

    struct Option {
        let id: Int
        let title: String
        let subtitle: String
    }

    private let dimNode = SKShapeNode()
    private let panelNode = SKShapeNode()
    private let titleNode = SKLabelNode(fontNamed: "Menlo-Bold")
    private var buttonNodes: [Int: SKShapeNode] = [:]
    private var buttonOrder: [Int] = []

    var onSelectLevel: ((Int) -> Void)?

    override init() {
        super.init()
        setupBase()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupBase()
    }

    func configure(
        options: [Option],
        sceneSize: CGSize,
        cellSize: CGFloat,
        accent: SKColor,
        accentSoft: SKColor
    ) {
        removeButtons()

        dimNode.path = CGPath(rect: CGRect(x: -sceneSize.width * 0.5, y: -sceneSize.height * 0.5, width: sceneSize.width, height: sceneSize.height), transform: nil)

        let panelWidth = min(sceneSize.width * 0.72, max(300, cellSize * 18))
        let buttonHeight = max(34, cellSize * 1.35)
        let spacing = max(8, cellSize * 0.35)
        let panelHeight = max(180, cellSize * 3.8 + CGFloat(options.count) * (buttonHeight + spacing))

        panelNode.path = CGPath(
            roundedRect: CGRect(x: -panelWidth * 0.5, y: -panelHeight * 0.5, width: panelWidth, height: panelHeight),
            cornerWidth: 14,
            cornerHeight: 14,
            transform: nil
        )
        panelNode.fillColor = accentSoft
        panelNode.strokeColor = accent.withAlphaComponent(0.18)

        titleNode.text = "SELECT LEVEL"
        titleNode.fontSize = max(14, cellSize * 0.7)
        titleNode.fontColor = accent.withAlphaComponent(0.95)
        titleNode.position = CGPoint(x: 0, y: panelHeight * 0.33)

        let stackTop = panelHeight * 0.12
        for (idx, option) in options.enumerated() {
            let y = stackTop - CGFloat(idx) * (buttonHeight + spacing)
            let button = SKShapeNode(
                rectOf: CGSize(width: panelWidth * 0.82, height: buttonHeight),
                cornerRadius: min(10, buttonHeight * 0.28)
            )
            button.position = CGPoint(x: 0, y: y)
            button.fillColor = accent.withAlphaComponent(0.05)
            button.strokeColor = accent.withAlphaComponent(0.28)
            button.lineWidth = 1
            addChild(button)

            let glow = SKLabelNode(fontNamed: "Menlo")
            glow.text = "\(option.title)  \(option.subtitle)"
            glow.fontSize = max(10, cellSize * 0.42)
            glow.fontColor = accent.withAlphaComponent(0.22)
            glow.position = CGPoint(x: 0, y: -glow.fontSize * 0.35)
            glow.verticalAlignmentMode = .center
            glow.horizontalAlignmentMode = .center
            button.addChild(glow)

            let label = SKLabelNode(fontNamed: "Menlo")
            label.text = glow.text
            label.fontSize = glow.fontSize
            label.fontColor = accent.withAlphaComponent(0.95)
            label.position = glow.position
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            button.addChild(label)

            buttonNodes[option.id] = button
            buttonOrder.append(option.id)
        }
    }

    func handleTap(at pointInScene: CGPoint) -> Bool {
        for id in buttonOrder {
            if let button = buttonNodes[id], button.contains(pointInScene) {
                onSelectLevel?(id)
                return true
            }
        }
        return false
    }
}

private extension LevelSelectOverlayNode {

    func setupBase() {
        zPosition = 120

        dimNode.fillColor = SKColor(white: 0, alpha: 0.16)
        dimNode.strokeColor = .clear
        addChild(dimNode)

        panelNode.lineWidth = 1
        addChild(panelNode)

        titleNode.verticalAlignmentMode = .center
        titleNode.horizontalAlignmentMode = .center
        addChild(titleNode)
    }

    func removeButtons() {
        for id in buttonOrder {
            buttonNodes[id]?.removeFromParent()
        }
        buttonNodes.removeAll(keepingCapacity: true)
        buttonOrder.removeAll(keepingCapacity: true)
    }
}
