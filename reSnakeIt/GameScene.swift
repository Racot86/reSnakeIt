//
//  GameScene.swift
//  reSnakeIt
//
//  Created by Dmytro Mayevsky on 22.02.2026.
//

import SpriteKit

final class GameScene: SKScene {

    private struct SessionTheme {
        let hue: CGFloat
        let saturation: CGFloat

        static func random() -> SessionTheme {
            SessionTheme(
                hue: CGFloat.random(in: 0...1),
                saturation: CGFloat.random(in: 0.55...0.9)
            )
        }

        func color(brightness: CGFloat, alpha: CGFloat) -> SKColor {
            SKColor(hue: hue, saturation: saturation, brightness: brightness, alpha: alpha)
        }
    }

    private struct LevelConfig {
        let id: Int
        let title: String
        let initialInterval: TimeInterval
        let minimumInterval: TimeInterval
        let speedStep: TimeInterval
        let pointsPerFood: Int

        static let all: [LevelConfig] = [
            LevelConfig(id: 1, title: "L1", initialInterval: 0.24, minimumInterval: 0.11, speedStep: 0.003, pointsPerFood: 10),
            LevelConfig(id: 2, title: "L2", initialInterval: 0.20, minimumInterval: 0.09, speedStep: 0.0035, pointsPerFood: 20),
            LevelConfig(id: 3, title: "L3", initialInterval: 0.17, minimumInterval: 0.075, speedStep: 0.004, pointsPerFood: 35),
            LevelConfig(id: 4, title: "L4", initialInterval: 0.145, minimumInterval: 0.065, speedStep: 0.0045, pointsPerFood: 50)
        ]
    }

    private final class NeonTextNode: SKNode {
        private struct Pair {
            let glow: SKLabelNode
            let base: SKLabelNode
        }

        private var pairs: [Pair] = []
        private var currentText = ""
        private var fontName = "Menlo-Bold"
        private var fontSizeValue: CGFloat = 14
        private var colorValue: SKColor = .white

        private var wordGlowMultiplier: CGFloat = 1
        private var nextJitterTime: TimeInterval = 0
        private var wordBlinkUntil: TimeInterval = 0
        private var nextWordBlinkAttempt: TimeInterval = 0
        private var charBlinkUntil: [TimeInterval] = []
        private var nextCharBlinkAttempt: TimeInterval = 0

        func configure(fontName: String, fontSize: CGFloat, color: SKColor) {
            self.fontName = fontName
            self.fontSizeValue = fontSize
            self.colorValue = color
            rebuild()
        }

        func setFontSize(_ size: CGFloat) {
            fontSizeValue = size
            rebuild()
        }

        func setColor(_ color: SKColor) {
            colorValue = color
            rebuild()
        }

        func setText(_ text: String) {
            guard text != currentText else { return }
            currentText = text
            rebuild()
        }

        func updateEffects(currentTime: TimeInterval) {
            guard !pairs.isEmpty else { return }

            if currentTime >= nextJitterTime {
                wordGlowMultiplier = CGFloat.random(in: 0.85...1.12)
                nextJitterTime = currentTime + TimeInterval.random(in: 0.05...0.16)
            }

            if currentTime >= nextWordBlinkAttempt {
                nextWordBlinkAttempt = currentTime + TimeInterval.random(in: 1.2...2.8)
                if CGFloat.random(in: 0...1) < 0.06 {
                    wordBlinkUntil = currentTime + TimeInterval.random(in: 0.035...0.09)
                }
            }

            if currentTime >= nextCharBlinkAttempt {
                nextCharBlinkAttempt = currentTime + TimeInterval.random(in: 0.45...1.1)
                if !pairs.isEmpty, CGFloat.random(in: 0...1) < 0.18 {
                    let idx = Int.random(in: 0..<pairs.count)
                    charBlinkUntil[idx] = currentTime + TimeInterval.random(in: 0.02...0.07)
                }
            }

            for (index, pair) in pairs.enumerated() {
                let blinkingOff = currentTime < wordBlinkUntil || currentTime < charBlinkUntil[index]
                pair.base.alpha = blinkingOff ? 0.18 : 1.0
                pair.glow.alpha = blinkingOff ? 0.03 : wordGlowMultiplier
            }
        }

        private func rebuild() {
            removeAllChildren()
            pairs.removeAll(keepingCapacity: true)

            let chars = Array(currentText)
            charBlinkUntil = Array(repeating: 0, count: chars.count)
            guard !chars.isEmpty else { return }

            let step = fontSizeValue * 0.62
            let startX = -CGFloat(chars.count - 1) * step * 0.5

            for (i, ch) in chars.enumerated() {
                let glow = makeLabel()
                glow.fontColor = colorValue.withAlphaComponent(0.22)
                glow.text = String(ch)
                glow.position = CGPoint(x: startX + CGFloat(i) * step, y: 0)

                let base = makeLabel()
                base.fontColor = colorValue.withAlphaComponent(0.94)
                base.text = String(ch)
                base.position = glow.position

                addChild(glow)
                addChild(base)
                pairs.append(Pair(glow: glow, base: base))
            }
        }

        private func makeLabel() -> SKLabelNode {
            let label = SKLabelNode(fontNamed: fontName)
            label.fontSize = fontSizeValue
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            return label
        }
    }

    private let columns = 28
    private let rows = 16
    private let boardNode = SKNode()
    private let borderGlowContainer = SKNode()
    private let foodContainer = SKNode()
    private let snakeContainer = SKNode()
    private let hudNode = SKNode()
    private let overlayNode = SKNode()
    private var gridCellNodes: [SKShapeNode] = []
    private var snakeSegmentNodes: [SKShapeNode] = []
    private var borderGlowNodes: [SKShapeNode] = []
    private var gameOverOverlay: GameOverOverlayNode?
    private var levelSelectOverlay: LevelSelectOverlayNode?

    private let levelHUDText = NeonTextNode()
    private let scoreHUDText = NeonTextNode()

    private var boardWidth: CGFloat = 0
    private var boardHeight: CGFloat = 0
    private var boardCornerRadius: CGFloat = 10
    private var cellSize: CGFloat = 0
    private var gridCellInset: CGFloat = 0
    private var gridCellCornerRadius: CGFloat = 0

    private var lastMoveTime: TimeInterval = 0
    private var currentMoveInterval: TimeInterval = 0.24
    private var snakeCells: [GridPoint] = []
    private var direction = GridPoint(x: 1, y: 0)
    private var pendingDirection: GridPoint?
    private var swipeStartPoint: CGPoint?
    private var isGameOver = false
    private var foodCell: GridPoint?
    private var foodNode: SKShapeNode?
    private var selectedLevel: LevelConfig?
    private var score = 0
    private let theme = SessionTheme.random()

    override func didMove(to view: SKView) {
        backgroundColor = theme.color(brightness: 0.08, alpha: 1.0)
        anchorPoint = CGPoint(x: 0.5, y: 0.5)

        removeAllChildren()
        addChild(boardNode)
        boardNode.addChild(foodContainer)
        boardNode.addChild(snakeContainer)
        addChild(hudNode)
        addChild(overlayNode)

        buildBoard()
        setupHUD()
        updateHUD()
        showLevelSelectOverlay()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard boardNode.parent != nil else { return }
        buildBoard()
        redrawSnake()
        redrawFood()
        layoutHUD()
        if let overlay = levelSelectOverlay {
            configureLevelSelectOverlay(overlay)
        }
        if isGameOver {
            gameOverOverlay?.updateLayout(sceneSize: size, cellSize: cellSize)
        }
    }

    override func update(_ currentTime: TimeInterval) {
        if lastMoveTime == 0 {
            updateHUDEffects(currentTime)
            gameOverOverlay?.updateEffects(currentTime: currentTime)
            lastMoveTime = currentTime
            return
        }

        updateHUDEffects(currentTime)
        gameOverOverlay?.updateEffects(currentTime: currentTime)
        guard !isGameOver else { return }
        guard selectedLevel != nil else { return }
        guard currentTime - lastMoveTime >= currentMoveInterval else { return }
        lastMoveTime = currentTime

        advanceSnake()
        redrawSnake(animated: true)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        if let levelSelectOverlay {
            _ = levelSelectOverlay.handleTap(at: touch.location(in: self))
            swipeStartPoint = nil
            return
        }
        if isGameOver {
            swipeStartPoint = nil
            return
        }
        swipeStartPoint = touch.location(in: self)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard levelSelectOverlay == nil else { return }
        guard !isGameOver else { return }
        guard let touch = touches.first,
              let start = swipeStartPoint else { return }

        let current = touch.location(in: self)
        if handleSwipe(from: start, to: current) {
            swipeStartPoint = current
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else {
            swipeStartPoint = nil
            return
        }

        let touchPoint = touch.location(in: self)
        if let levelSelectOverlay {
            _ = levelSelectOverlay.handleTap(at: touchPoint)
            swipeStartPoint = nil
            return
        }
        if isGameOver {
            _ = gameOverOverlay?.handleTap(at: touchPoint)
            swipeStartPoint = nil
            return
        }

        guard let start = swipeStartPoint else {
            swipeStartPoint = nil
            return
        }

        _ = handleSwipe(from: start, to: touchPoint)
        swipeStartPoint = nil
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        swipeStartPoint = nil
    }
}

private extension GameScene {

    struct GridPoint: Equatable {
        var x: Int
        var y: Int
    }

    func buildBoard() {
        boardNode.removeAllChildren()
        boardNode.addChild(borderGlowContainer)
        boardNode.addChild(foodContainer)
        boardNode.addChild(snakeContainer)
        gridCellNodes.removeAll(keepingCapacity: true)
        borderGlowContainer.removeAllChildren()
        borderGlowNodes.removeAll(keepingCapacity: true)

        let horizontalPadding = size.width * 0.08
        let verticalPadding = size.height * 0.12
        let availableWidth = size.width - horizontalPadding * 2
        let availableHeight = size.height - verticalPadding * 2

        cellSize = min(availableWidth / CGFloat(columns), availableHeight / CGFloat(rows))
        boardWidth = cellSize * CGFloat(columns)
        boardHeight = cellSize * CGFloat(rows)

        let boardBackground = SKShapeNode(
            rectOf: CGSize(width: boardWidth, height: boardHeight),
            cornerRadius: boardCornerRadius
        )
        boardBackground.fillColor = theme.color(brightness: 0.12, alpha: 1.0)
        boardBackground.strokeColor = theme.color(brightness: 0.95, alpha: 0.08)
        boardBackground.lineWidth = 1
        boardBackground.zPosition = 0
        boardNode.addChild(boardBackground)

        let halfWidth = boardWidth * 0.5
        let halfHeight = boardHeight * 0.5
        gridCellInset = cellSize * 0.08
        gridCellCornerRadius = cellSize * 0.16

        for row in 0..<rows {
            for col in 0..<columns {
                let x = -halfWidth + (CGFloat(col) + 0.5) * cellSize
                let y = -halfHeight + (CGFloat(row) + 0.5) * cellSize

                let cellOutline = SKShapeNode(
                    rectOf: CGSize(width: cellSize - gridCellInset, height: cellSize - gridCellInset),
                    cornerRadius: gridCellCornerRadius
                )
                cellOutline.position = CGPoint(x: x, y: y)
                cellOutline.fillColor = .clear
                cellOutline.strokeColor = theme.color(brightness: 0.95, alpha: 0.03)
                cellOutline.lineWidth = 0.5
                cellOutline.zPosition = 1
                boardNode.addChild(cellOutline)
                gridCellNodes.append(cellOutline)
            }
        }

        borderGlowContainer.zPosition = 1.5
        snakeContainer.zPosition = 2
        foodContainer.zPosition = 2
        overlayNode.zPosition = 10
    }

    func setupSnake() {
        guard let level = selectedLevel else { return }

        snakeCells = [
            GridPoint(x: 6, y: 10),
            GridPoint(x: 5, y: 10),
            GridPoint(x: 4, y: 10),
            GridPoint(x: 3, y: 10)
        ]
        direction = GridPoint(x: 1, y: 0)
        pendingDirection = nil
        lastMoveTime = 0
        currentMoveInterval = level.initialInterval
        isGameOver = false
        foodCell = nil
        score = 0

        snakeContainer.removeAllChildren()
        snakeSegmentNodes.removeAll()
        foodContainer.removeAllChildren()
        foodNode = nil
        overlayNode.removeAllChildren()
        gameOverOverlay = nil

        for _ in snakeCells {
            let segment = SKShapeNode(
                rectOf: CGSize(width: cellSize - gridCellInset, height: cellSize - gridCellInset),
                cornerRadius: gridCellCornerRadius
            )
            segment.lineWidth = 0.8
            snakeContainer.addChild(segment)
            snakeSegmentNodes.append(segment)
        }

        redrawSnake()
        spawnFood()
        updateHUD()
    }

    func advanceSnake() {
        guard let head = snakeCells.first else { return }

        if let pendingDirection, !isOpposite(pendingDirection, to: direction) {
            direction = pendingDirection
        }
        self.pendingDirection = nil

        let newHead = GridPoint(x: head.x + direction.x, y: head.y + direction.y)

        guard (0..<columns).contains(newHead.x), (0..<rows).contains(newHead.y) else {
            triggerGameOver()
            return
        }

        if snakeCells.dropLast().contains(newHead) {
            triggerGameOver()
            return
        }

        let didEatFood = (foodCell == newHead)
        snakeCells.insert(newHead, at: 0)

        if didEatFood {
            appendSnakeSegmentNode()
            score += selectedLevel?.pointsPerFood ?? 0
            speedUpSnake()
            spawnFood()
            updateHUD()
        } else {
            snakeCells.removeLast()
        }
    }

    @discardableResult
    func handleSwipe(from start: CGPoint, to end: CGPoint) -> Bool {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let threshold = max(18, cellSize * 0.45)

        guard max(abs(dx), abs(dy)) >= threshold else { return false }

        let candidate: GridPoint
        if abs(dx) > abs(dy) {
            candidate = GridPoint(x: dx > 0 ? 1 : -1, y: 0)
        } else {
            candidate = GridPoint(x: 0, y: dy > 0 ? 1 : -1)
        }

        let baseDirection = pendingDirection ?? direction
        guard candidate != baseDirection, !isOpposite(candidate, to: baseDirection) else {
            return false
        }

        pendingDirection = candidate
        return true
    }

    func isOpposite(_ lhs: GridPoint, to rhs: GridPoint) -> Bool {
        lhs.x == -rhs.x && lhs.y == -rhs.y
    }

    func triggerGameOver() {
        isGameOver = true
        foodNode?.removeAllActions()

        for (index, node) in snakeSegmentNodes.enumerated() {
            let alpha = index == 0 ? 0.9 : 0.55
            node.strokeColor = theme.color(brightness: 1.0, alpha: alpha)
            node.fillColor = theme.color(brightness: 0.9, alpha: 0.1)
        }
        clearBorderGlow()

        let overlay = GameOverOverlayNode()
        overlay.updateLayout(sceneSize: size, cellSize: cellSize)
        overlay.applyTheme(
            accent: theme.color(brightness: 1.0, alpha: 1.0),
            panelFill: theme.color(brightness: 0.11, alpha: 0.96)
        )
        overlay.onRestart = { [weak self] in
            self?.setupSnake()
        }
        overlayNode.removeAllChildren()
        overlayNode.addChild(overlay)
        gameOverOverlay = overlay
    }

    func redrawSnake(animated: Bool = false) {
        for (index, cell) in snakeCells.enumerated() {
            guard index < snakeSegmentNodes.count else { continue }
            let node = snakeSegmentNodes[index]
            let targetPosition = point(for: cell)

            if animated && !isGameOver {
                let move = SKAction.move(to: targetPosition, duration: currentMoveInterval)
                move.timingMode = .linear
                node.removeAction(forKey: "gridMove")
                node.run(move, withKey: "gridMove")
            } else {
                node.removeAction(forKey: "gridMove")
                node.position = targetPosition
            }

            if index == 0 {
                node.fillColor = theme.color(brightness: 0.98, alpha: 0.22)
                node.strokeColor = theme.color(brightness: 1.0, alpha: 0.75)
            } else {
                let fillAlpha = max(0.07, 0.18 - CGFloat(index) * 0.025)
                let strokeAlpha = max(0.22, 0.52 - CGFloat(index) * 0.07)
                let bodyBrightness = max(0.74, 0.92 - CGFloat(index) * 0.04)
                node.fillColor = theme.color(brightness: bodyBrightness, alpha: fillAlpha)
                node.strokeColor = theme.color(brightness: min(1.0, bodyBrightness + 0.1), alpha: strokeAlpha)
            }
        }

        updateGridGlowNearHead()
        updateBorderGlowNearSnake()
    }

    func updateGridGlowNearHead() {
        guard let head = snakeCells.first else { return }

        let baseAlpha: CGFloat = 0.03
        for row in 0..<rows {
            for col in 0..<columns {
                let dx = CGFloat(col - head.x)
                let dy = CGFloat(row - head.y)
                let distance = sqrt(dx * dx + dy * dy)

                let intensity = max(0, 1 - (distance / 2.6))
                let glowAlpha = baseAlpha + intensity * 0.13
                let brightness = min(1.0, 0.93 + intensity * 0.07)
                let lineWidth = 0.5 + intensity * 0.55

                let node = gridCellNodes[(row * columns) + col]
                node.strokeColor = theme.color(brightness: brightness, alpha: glowAlpha)
                node.lineWidth = lineWidth
            }
        }
    }

    func updateBorderGlowNearSnake() {
        guard !snakeCells.isEmpty else {
            clearBorderGlow()
            return
        }

        clearBorderGlow()

        let thresholdCells = 2
        let segmentLength = cellSize * 3.8
        let lineWidth = CGFloat(1.8)
        let halfW = boardWidth * 0.5
        let halfH = boardHeight * 0.5
        for (index, cell) in snakeCells.enumerated() {
            let bodyWeight = max(0.18, 1.0 - CGFloat(index) * 0.1)
            let cellPoint = point(for: cell)

            if cell.x <= thresholdCells {
                let proximity = 1 - (CGFloat(cell.x) / CGFloat(thresholdCells + 1))
                addBorderGlowSegment(
                    from: CGPoint(x: -halfW, y: cellPoint.y - segmentLength * 0.5),
                    to: CGPoint(x: -halfW, y: cellPoint.y + segmentLength * 0.5),
                    intensity: proximity * bodyWeight,
                    lineWidth: lineWidth
                )
            }

            if cell.x >= columns - 1 - thresholdCells {
                let dist = (columns - 1) - cell.x
                let proximity = 1 - (CGFloat(dist) / CGFloat(thresholdCells + 1))
                addBorderGlowSegment(
                    from: CGPoint(x: halfW, y: cellPoint.y - segmentLength * 0.5),
                    to: CGPoint(x: halfW, y: cellPoint.y + segmentLength * 0.5),
                    intensity: proximity * bodyWeight,
                    lineWidth: lineWidth
                )
            }

            if cell.y <= thresholdCells {
                let proximity = 1 - (CGFloat(cell.y) / CGFloat(thresholdCells + 1))
                addBorderGlowSegment(
                    from: CGPoint(x: cellPoint.x - segmentLength * 0.5, y: -halfH),
                    to: CGPoint(x: cellPoint.x + segmentLength * 0.5, y: -halfH),
                    intensity: proximity * bodyWeight,
                    lineWidth: lineWidth
                )
            }

            if cell.y >= rows - 1 - thresholdCells {
                let dist = (rows - 1) - cell.y
                let proximity = 1 - (CGFloat(dist) / CGFloat(thresholdCells + 1))
                addBorderGlowSegment(
                    from: CGPoint(x: cellPoint.x - segmentLength * 0.5, y: halfH),
                    to: CGPoint(x: cellPoint.x + segmentLength * 0.5, y: halfH),
                    intensity: proximity * bodyWeight,
                    lineWidth: lineWidth
                )
            }

            // Rounded corner glow (quarter arcs) when a body part is near two borders.
            if cell.x <= thresholdCells && cell.y <= thresholdCells {
                let px = 1 - (CGFloat(cell.x) / CGFloat(thresholdCells + 1))
                let py = 1 - (CGFloat(cell.y) / CGFloat(thresholdCells + 1))
                addCornerBorderGlow(corner: .bottomLeft, intensity: min(px, py) * bodyWeight)
            }
            if cell.x >= columns - 1 - thresholdCells && cell.y <= thresholdCells {
                let dx = (columns - 1) - cell.x
                let px = 1 - (CGFloat(dx) / CGFloat(thresholdCells + 1))
                let py = 1 - (CGFloat(cell.y) / CGFloat(thresholdCells + 1))
                addCornerBorderGlow(corner: .bottomRight, intensity: min(px, py) * bodyWeight)
            }
            if cell.x <= thresholdCells && cell.y >= rows - 1 - thresholdCells {
                let dy = (rows - 1) - cell.y
                let px = 1 - (CGFloat(cell.x) / CGFloat(thresholdCells + 1))
                let py = 1 - (CGFloat(dy) / CGFloat(thresholdCells + 1))
                addCornerBorderGlow(corner: .topLeft, intensity: min(px, py) * bodyWeight)
            }
            if cell.x >= columns - 1 - thresholdCells && cell.y >= rows - 1 - thresholdCells {
                let dx = (columns - 1) - cell.x
                let dy = (rows - 1) - cell.y
                let px = 1 - (CGFloat(dx) / CGFloat(thresholdCells + 1))
                let py = 1 - (CGFloat(dy) / CGFloat(thresholdCells + 1))
                addCornerBorderGlow(corner: .topRight, intensity: min(px, py) * bodyWeight)
            }
        }
    }

    func addBorderGlowSegment(from start: CGPoint, to end: CGPoint, intensity: CGFloat, lineWidth: CGFloat) {
        let clamped = clampedBorderSegment(start: start, end: end)
        guard let start = clamped?.start, let end = clamped?.end else { return }

        let dx = end.x - start.x
        let dy = end.y - start.y

        // Three layered segments produce a center-weighted gradient:
        // long/faint base + medium + short/bright center.
        let layers: [(span: CGFloat, alpha: CGFloat, width: CGFloat)] = [
            (1.0, 0.05, 0.7),
            (0.62, 0.11, 1.0),
            (0.34, 0.2, 1.35)
        ]

        for layer in layers {
            let insetFactor = (1 - layer.span) * 0.5
            let layerStart = CGPoint(x: start.x + dx * insetFactor, y: start.y + dy * insetFactor)
            let layerEnd = CGPoint(x: end.x - dx * insetFactor, y: end.y - dy * insetFactor)

            let path = CGMutablePath()
            path.move(to: layerStart)
            path.addLine(to: layerEnd)

            let glow = SKShapeNode(path: path)
            glow.lineCap = .round
            glow.lineJoin = .round
            glow.lineWidth = (lineWidth + intensity * 1.2) * layer.width
            glow.strokeColor = theme.color(
                brightness: 1.0,
                alpha: layer.alpha * (0.55 + intensity * 0.9)
            )
            glow.zPosition = 2
            borderGlowContainer.addChild(glow)
            borderGlowNodes.append(glow)
        }
    }

    func clampedBorderSegment(start: CGPoint, end: CGPoint) -> (start: CGPoint, end: CGPoint)? {
        let halfW = boardWidth * 0.5
        let halfH = boardHeight * 0.5
        let borderInset = max(3, boardCornerRadius * 0.45) // leave room for rounded-corner arc glow

        var s = start
        var e = end

        if abs(start.x - end.x) < 0.001 {
            s.y = max(-halfH + borderInset, min(halfH - borderInset, s.y))
            e.y = max(-halfH + borderInset, min(halfH - borderInset, e.y))
        } else if abs(start.y - end.y) < 0.001 {
            s.x = max(-halfW + borderInset, min(halfW - borderInset, s.x))
            e.x = max(-halfW + borderInset, min(halfW - borderInset, e.x))
        }

        let length = hypot(e.x - s.x, e.y - s.y)
        guard length > 1 else { return nil }
        return (s, e)
    }

    enum BorderCorner {
        case topLeft
        case topRight
        case bottomLeft
        case bottomRight
    }

    func addCornerBorderGlow(corner: BorderCorner, intensity: CGFloat) {
        guard intensity > 0.02 else { return }

        let halfW = boardWidth * 0.5
        let halfH = boardHeight * 0.5
        let inset = max(3, boardCornerRadius * 0.4)
        let span = max(cellSize * 1.3, boardCornerRadius * 1.2)

        switch corner {
        case .topLeft:
            addBorderGlowSegment(
                from: CGPoint(x: -halfW + inset, y: halfH),
                to: CGPoint(x: -halfW + inset + span, y: halfH),
                intensity: intensity,
                lineWidth: 1.5
            )
            addBorderGlowSegment(
                from: CGPoint(x: -halfW, y: halfH - inset),
                to: CGPoint(x: -halfW, y: halfH - inset - span),
                intensity: intensity,
                lineWidth: 1.5
            )
        case .topRight:
            addBorderGlowSegment(
                from: CGPoint(x: halfW - inset, y: halfH),
                to: CGPoint(x: halfW - inset - span, y: halfH),
                intensity: intensity,
                lineWidth: 1.5
            )
            addBorderGlowSegment(
                from: CGPoint(x: halfW, y: halfH - inset),
                to: CGPoint(x: halfW, y: halfH - inset - span),
                intensity: intensity,
                lineWidth: 1.5
            )
        case .bottomLeft:
            addBorderGlowSegment(
                from: CGPoint(x: -halfW + inset, y: -halfH),
                to: CGPoint(x: -halfW + inset + span, y: -halfH),
                intensity: intensity,
                lineWidth: 1.5
            )
            addBorderGlowSegment(
                from: CGPoint(x: -halfW, y: -halfH + inset),
                to: CGPoint(x: -halfW, y: -halfH + inset + span),
                intensity: intensity,
                lineWidth: 1.5
            )
        case .bottomRight:
            addBorderGlowSegment(
                from: CGPoint(x: halfW - inset, y: -halfH),
                to: CGPoint(x: halfW - inset - span, y: -halfH),
                intensity: intensity,
                lineWidth: 1.5
            )
            addBorderGlowSegment(
                from: CGPoint(x: halfW, y: -halfH + inset),
                to: CGPoint(x: halfW, y: -halfH + inset + span),
                intensity: intensity,
                lineWidth: 1.5
            )
        }
    }

    func clearBorderGlow() {
        guard !borderGlowNodes.isEmpty else { return }
        for node in borderGlowNodes {
            node.removeFromParent()
        }
        borderGlowNodes.removeAll(keepingCapacity: true)
    }

    func spawnFood() {
        guard snakeCells.count < columns * rows else {
            foodCell = nil
            foodNode?.removeFromParent()
            foodNode = nil
            return
        }

        let freeCells = (0..<rows).flatMap { row in
            (0..<columns).compactMap { col -> GridPoint? in
                let point = GridPoint(x: col, y: row)
                return snakeCells.contains(point) ? nil : point
            }
        }

        guard let nextFood = freeCells.randomElement() else { return }
        foodCell = nextFood
        ensureFoodNode()
        redrawFood()
        startFoodBlink()
    }

    func ensureFoodNode() {
        guard foodNode == nil else { return }

        let node = SKShapeNode(
            rectOf: CGSize(width: cellSize - gridCellInset, height: cellSize - gridCellInset),
            cornerRadius: gridCellCornerRadius
        )
        node.lineWidth = 1
        node.fillColor = theme.color(brightness: 1.0, alpha: 0.12)
        node.strokeColor = theme.color(brightness: 1.0, alpha: 0.9)
        foodContainer.addChild(node)
        foodNode = node
    }

    func redrawFood() {
        guard let foodCell, let foodNode else { return }

        if foodNode.parent == nil {
            foodContainer.addChild(foodNode)
        }

        foodNode.position = point(for: foodCell)

        let size = CGSize(width: cellSize - gridCellInset, height: cellSize - gridCellInset)
        foodNode.path = CGPath(
            roundedRect: CGRect(
                x: -size.width * 0.5,
                y: -size.height * 0.5,
                width: size.width,
                height: size.height
            ),
            cornerWidth: gridCellCornerRadius,
            cornerHeight: gridCellCornerRadius,
            transform: nil
        )
    }

    func startFoodBlink() {
        guard let foodNode else { return }
        foodNode.removeAction(forKey: "blink")

        let fadeDown = SKAction.group([
            .fadeAlpha(to: 0.35, duration: 0.7),
            .scale(to: 0.93, duration: 0.7)
        ])
        let fadeUp = SKAction.group([
            .fadeAlpha(to: 1.0, duration: 0.7),
            .scale(to: 1.0, duration: 0.7)
        ])
        let sequence = SKAction.sequence([fadeDown, fadeUp])
        foodNode.run(.repeatForever(sequence), withKey: "blink")
    }

    func appendSnakeSegmentNode() {
        let segment = SKShapeNode(
            rectOf: CGSize(width: cellSize - gridCellInset, height: cellSize - gridCellInset),
            cornerRadius: gridCellCornerRadius
        )
        segment.lineWidth = 0.8
        if let tail = snakeCells.last {
            segment.position = point(for: tail)
        }
        snakeContainer.addChild(segment)
        snakeSegmentNodes.append(segment)
    }

    func speedUpSnake() {
        guard let level = selectedLevel else { return }
        currentMoveInterval = max(level.minimumInterval, currentMoveInterval - level.speedStep)
    }

    func setupHUD() {
        hudNode.removeAllChildren()
        hudNode.zPosition = 20

        levelHUDText.configure(fontName: "Menlo-Bold", fontSize: max(12, cellSize * 0.55), color: theme.color(brightness: 1.0, alpha: 1))
        scoreHUDText.configure(fontName: "Menlo-Bold", fontSize: max(12, cellSize * 0.55), color: theme.color(brightness: 1.0, alpha: 1))

        hudNode.addChild(levelHUDText)
        hudNode.addChild(scoreHUDText)

        layoutHUD()
    }

    func layoutHUD() {
        let fontSize = max(12, cellSize > 0 ? cellSize * 0.55 : 14)
        levelHUDText.setFontSize(fontSize)
        scoreHUDText.setFontSize(fontSize)

        let y = boardHeight * 0.5 + max(cellSize * 0.9, 18)
        let xInset = boardWidth * 0.5 - max(cellSize * 2.7, 70)

        levelHUDText.position = CGPoint(x: -xInset, y: y)
        scoreHUDText.position = CGPoint(x: xInset, y: y)
    }

    func updateHUD() {
        let levelText = selectedLevel.map { "LEVEL \($0.id)" } ?? "LEVEL -"
        let scoreText = "SCORE \(score)"

        levelHUDText.setText(levelText)
        scoreHUDText.setText(scoreText)
    }

    func updateHUDEffects(_ currentTime: TimeInterval) {
        levelHUDText.updateEffects(currentTime: currentTime)
        scoreHUDText.updateEffects(currentTime: currentTime)
    }

    func showLevelSelectOverlay() {
        overlayNode.removeAllChildren()
        gameOverOverlay = nil

        let overlay = LevelSelectOverlayNode()
        overlay.onSelectLevel = { [weak self] levelId in
            self?.startGame(withLevelID: levelId)
        }
        configureLevelSelectOverlay(overlay)
        overlayNode.addChild(overlay)
        levelSelectOverlay = overlay
    }

    func configureLevelSelectOverlay(_ overlay: LevelSelectOverlayNode) {
        let options = LevelConfig.all.map {
            LevelSelectOverlayNode.Option(
                id: $0.id,
                title: $0.title,
                subtitle: "\(Int((1 / $0.initialInterval).rounded())) t/s • +\($0.pointsPerFood)"
            )
        }
        overlay.configure(
            options: options,
            sceneSize: size,
            cellSize: max(cellSize, 16),
            accent: theme.color(brightness: 1.0, alpha: 1.0),
            accentSoft: theme.color(brightness: 0.11, alpha: 0.95)
        )
    }

    func startGame(withLevelID levelID: Int) {
        guard let level = LevelConfig.all.first(where: { $0.id == levelID }) else { return }
        selectedLevel = level
        levelSelectOverlay?.removeFromParent()
        levelSelectOverlay = nil
        overlayNode.removeAllChildren()
        updateHUD()
        setupSnake()
    }

    func point(for cell: GridPoint) -> CGPoint {
        let halfWidth = boardWidth * 0.5
        let halfHeight = boardHeight * 0.5
        let x = -halfWidth + (CGFloat(cell.x) + 0.5) * cellSize
        let y = -halfHeight + (CGFloat(cell.y) + 0.5) * cellSize
        return CGPoint(x: x, y: y)
    }
}
