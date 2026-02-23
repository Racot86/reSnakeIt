//
//  GameScene.swift
//  reSnakeIt
//
//  Created by Dmytro Mayevsky on 22.02.2026.
//

import SpriteKit

final class GameScene: SKScene {
    private struct HighScoreEntry: Codable {
        let tryNumber: Int
        let score: Int
    }

    private struct DigestionPulse {
        let startTime: TimeInterval
        let segmentDelay: TimeInterval
        let segmentDuration: TimeInterval
        let estimatedSegmentCount: Int
    }

    private enum HighScoreStorage {
        static let scoresKey = "reSnakeIt.highScores.v1"
        static let nextTryKey = "reSnakeIt.nextTryNumber.v1"
    }

    private enum EndReason {
        case wall
        case selfBite
        case starved
        case boardFilled
    }

    private struct SessionTheme {
        let hue: CGFloat
        let saturation: CGFloat

        static func random() -> SessionTheme {
            // Curated neon-friendly hues (avoids muddy/dull combinations on dark backgrounds).
            let neonHues: [CGFloat] = [0.00, 0.05, 0.12, 0.30, 0.43, 0.52, 0.60, 0.78, 0.90]
            return SessionTheme(
                hue: neonHues.randomElement() ?? 0.52,
                saturation: CGFloat.random(in: 0.88...1.0)
            )
        }

        func color(brightness: CGFloat, alpha: CGFloat) -> SKColor {
            SKColor(hue: hue, saturation: saturation, brightness: brightness, alpha: alpha)
        }
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

    private let columns = 30
    private let rows = 16
    private let boardNode = SKNode()
    private let borderGlowContainer = SKNode()
    private let foodContainer = SKNode()
    private let snakeContainer = SKNode()
    private let hudNode = SKNode()
    private let swipeTraceNode = SKNode()
    private let overlayNode = SKNode()
    private var gridCellNodes: [SKShapeNode] = []
    private var gridCellFlickerScale: [CGFloat] = []
    private var gridCellBlinkUntil: [TimeInterval] = []
    private var snakeSegmentNodes: [SKShapeNode] = []
    private var borderGlowNodes: [SKShapeNode] = []
    private var gameOverOverlay: GameOverOverlayNode?
    private var startScreenOverlay: StartScreenOverlayNode?

    private let scoreHUDText = NeonTextNode()
    private let hiScoreHUDText = NeonTextNode()
    private let foodHUDText = NeonTextNode()
    private let turnsHUDText = NeonTextNode()
    private let comboHUDText = NeonTextNode()

    private var boardWidth: CGFloat = 0
    private var boardHeight: CGFloat = 0
    private var boardCornerRadius: CGFloat = 10
    private var cellSize: CGFloat = 0
    private var gridCellInset: CGFloat = 0
    private var gridCellCornerRadius: CGFloat = 0

    private var lastMoveTime: TimeInterval = 0
    private var currentFrameTime: TimeInterval = 0
    private let initialMoveInterval: TimeInterval = 0.22
    private let minimumMoveInterval: TimeInterval = 0.085
    private let moveIntervalStep: TimeInterval = 0.0025
    private let pointsPerTile: Int = 1
    private let pointsPerFood: Int = 10
    private let pointsPerBonusFood: Int = 500
    private let pointsPerTurn: Int = 5
    private let comboTurnTimeout: TimeInterval = 1.1
    private let starvationRowsWorth: Int = 3
    private var currentMoveInterval: TimeInterval = 0.22
    private var snakeCells: [GridPoint] = []
    private var direction = GridPoint(x: 1, y: 0)
    private var pendingDirection: GridPoint?
    private var swipeStartPoint: CGPoint?
    private var swipeTracePoint: CGPoint?
    private var isGameOver = false
    private var foodCell: GridPoint?
    private var foodNode: SKShapeNode?
    private var bonusFoodCell: GridPoint?
    private var bonusFoodNode: SKShapeNode?
    private var bonusFoodExpiresAt: TimeInterval = 0
    private var nextBonusFoodSpawnAt: TimeInterval = 0
    private var snakeStrokeBaseAlpha: [CGFloat] = []
    private var snakeStrokeBaseBrightness: [CGFloat] = []
    private var snakeStrokeBaseLineWidth: [CGFloat] = []
    private var snakeStrokeBlinkUntil: [TimeInterval] = []
    private var snakeTurnPulseStart: [TimeInterval] = []
    private var snakeTurnPulseUntil: [TimeInterval] = []
    private var snakeTurnPulseStrength: [CGFloat] = []
    private var nextSnakeStrokeJitter: TimeInterval = 0
    private var nextSnakeStrokeBlinkAttempt: TimeInterval = 0
    private var nextGridFlickerJitter: TimeInterval = 0
    private var nextGridBlinkAttempt: TimeInterval = 0
    private let attractMoveInterval: TimeInterval = 0.19
    private var lastAttractMoveTime: TimeInterval = 0
    private var score = 0
    private var foodEatenCount = 0
    private var totalTurnsCount = 0
    private var turnComboCount = 0
    private var comboExpiresAt: TimeInterval = 0
    private var lastDisplayedComboCount = 0
    private var starvationStepsRemaining = 0
    private var starvationStepCapacity = 0
    private var highScores: [HighScoreEntry] = []
    private var nextTryNumber = 1
    private var currentTryNumber = 0
    private var currentRunSubmitted = false
    private var digestionPulses: [DigestionPulse] = []
    private var theme = SessionTheme.random()
    private var shouldPulseTurnCornerOnNextRedraw = false
    private var isStartScreenPresentation = false

    override func didMove(to view: SKView) {
        loadHighScores()
        backgroundColor = theme.color(brightness: 0.08, alpha: 1.0)
        anchorPoint = CGPoint(x: 0.5, y: 0.5)

        removeAllChildren()
        addChild(boardNode)
        boardNode.addChild(foodContainer)
        boardNode.addChild(snakeContainer)
        addChild(hudNode)
        addChild(swipeTraceNode)
        addChild(overlayNode)

        buildBoard()
        setupHUD()
        updateHUD()
        showStartScreenOverlay()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard boardNode.parent != nil else { return }
        buildBoard()
        redrawSnake()
        redrawFood()
        redrawBonusFood()
        layoutHUD()
        swipeTraceNode.zPosition = 15
        if let overlay = startScreenOverlay {
            overlay.configure(
                sceneSize: size,
                cellSize: max(cellSize, 16),
                accent: theme.color(brightness: 1.0, alpha: 1.0),
                highScoreLines: highScoreLinesForTitle()
            )
        }
        if isGameOver {
            gameOverOverlay?.updateLayout(sceneSize: size, cellSize: cellSize)
        }
    }

    override func update(_ currentTime: TimeInterval) {
        if lastMoveTime == 0 {
            currentFrameTime = currentTime
            updateHUDEffects(currentTime)
            updateSnakeStrokeFlicker(currentTime)
            updateGridFlicker(currentTime)
            updateGridGlowNearHead()
            startScreenOverlay?.updateEffects(currentTime: currentTime)
            gameOverOverlay?.updateEffects(currentTime: currentTime)
            lastMoveTime = currentTime
            return
        }

        currentFrameTime = currentTime
        updateHUDEffects(currentTime)
        updateSnakeStrokeFlicker(currentTime)
        updateGridFlicker(currentTime)
        updateGridGlowNearHead()
        updateComboTimeout(currentTime)
        updateBonusFoodState(currentTime)
        startScreenOverlay?.updateEffects(currentTime: currentTime)
        gameOverOverlay?.updateEffects(currentTime: currentTime)

        if startScreenOverlay != nil {
            if lastAttractMoveTime == 0 || currentTime - lastAttractMoveTime >= attractMoveInterval {
                lastAttractMoveTime = currentTime
                advanceAttractSnake()
                redrawSnake(animated: true)
            }
            return
        }
        guard !isGameOver else { return }
        guard currentTime - lastMoveTime >= currentMoveInterval else { return }
        lastMoveTime = currentTime

        advanceSnake()
        redrawSnake(animated: true)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        if let startScreenOverlay {
            _ = startScreenOverlay.handleTap(at: touch.location(in: self))
            swipeStartPoint = nil
            return
        }
        if isGameOver {
            swipeStartPoint = nil
            swipeTracePoint = nil
            return
        }
        let point = touch.location(in: self)
        swipeStartPoint = point
        swipeTracePoint = point
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard startScreenOverlay == nil else { return }
        guard !isGameOver else { return }
        guard let touch = touches.first,
              let start = swipeStartPoint else { return }

        let current = touch.location(in: self)
        if let tracePoint = swipeTracePoint {
            addSwipeTrace(from: tracePoint, to: current)
        }
        swipeTracePoint = current

        let didTurn = handleSwipe(from: start, to: current)
        let dragDistance = hypot(current.x - start.x, current.y - start.y)
        if didTurn || dragDistance > max(20, cellSize * 0.75) {
            swipeStartPoint = current
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else {
            swipeStartPoint = nil
            swipeTracePoint = nil
            return
        }

        let touchPoint = touch.location(in: self)
        if let startScreenOverlay {
            _ = startScreenOverlay.handleTap(at: touchPoint)
            swipeStartPoint = nil
            swipeTracePoint = nil
            return
        }
        if isGameOver {
            _ = gameOverOverlay?.handleTap(at: touchPoint)
            swipeStartPoint = nil
            swipeTracePoint = nil
            return
        }

        guard let start = swipeStartPoint else {
            swipeStartPoint = nil
            swipeTracePoint = nil
            return
        }

        if let tracePoint = swipeTracePoint {
            addSwipeTrace(from: tracePoint, to: touchPoint)
        } else {
            addSwipeTrace(from: start, to: touchPoint)
        }
        _ = handleSwipe(from: start, to: touchPoint)
        swipeStartPoint = nil
        swipeTracePoint = nil
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        swipeStartPoint = nil
        swipeTracePoint = nil
    }
}

private extension GameScene {

    struct GridPoint: Hashable {
        var x: Int
        var y: Int
    }

    func buildBoard() {
        boardNode.removeAllChildren()
        boardNode.addChild(borderGlowContainer)
        boardNode.addChild(foodContainer)
        boardNode.addChild(snakeContainer)
        gridCellNodes.removeAll(keepingCapacity: true)
        gridCellFlickerScale.removeAll(keepingCapacity: true)
        gridCellBlinkUntil.removeAll(keepingCapacity: true)
        borderGlowContainer.removeAllChildren()
        borderGlowNodes.removeAll(keepingCapacity: true)

        let horizontalPadding = isStartScreenPresentation ? size.width * 0.005 : size.width * 0.06
        let verticalPadding = isStartScreenPresentation ? size.height * 0.005 : size.height * 0.12
        let availableWidth = size.width - horizontalPadding * 2
        let availableHeight = size.height - verticalPadding * 2

        cellSize = min(availableWidth / CGFloat(columns), availableHeight / CGFloat(rows))
        boardWidth = cellSize * CGFloat(columns)
        boardHeight = cellSize * CGFloat(rows)

        let boardBackground = SKShapeNode(
            rectOf: CGSize(width: boardWidth, height: boardHeight),
            cornerRadius: boardCornerRadius
        )
        boardBackground.fillColor = isStartScreenPresentation ? .clear : theme.color(brightness: 0.12, alpha: 1.0)
        boardBackground.strokeColor = isStartScreenPresentation ? .clear : theme.color(brightness: 0.95, alpha: 0.08)
        boardBackground.lineWidth = isStartScreenPresentation ? 0 : 1
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
                cellOutline.strokeColor = theme.color(brightness: 0.95, alpha: isStartScreenPresentation ? 0.04 : 0.03)
                cellOutline.lineWidth = isStartScreenPresentation ? 0.55 : 0.5
                cellOutline.zPosition = 1
                boardNode.addChild(cellOutline)
                gridCellNodes.append(cellOutline)
                gridCellFlickerScale.append(1.0)
                gridCellBlinkUntil.append(0)
            }
        }

        borderGlowContainer.zPosition = 1.5
        snakeContainer.zPosition = 2
        foodContainer.zPosition = 2
        swipeTraceNode.zPosition = 15
        overlayNode.zPosition = 10
    }

    func setupSnake() {
        // New game = new neon color theme.
        theme = SessionTheme.random()
        backgroundColor = theme.color(brightness: 0.08, alpha: 1.0)
        buildBoard()
        setupHUD()
        updateHUD()

        snakeCells = [
            GridPoint(x: 6, y: 10),
            GridPoint(x: 5, y: 10),
            GridPoint(x: 4, y: 10),
            GridPoint(x: 3, y: 10)
        ]
        direction = GridPoint(x: 1, y: 0)
        pendingDirection = nil
        lastMoveTime = 0
        currentMoveInterval = initialMoveInterval
        isGameOver = false
        foodCell = nil
        bonusFoodCell = nil
        score = 0
        foodEatenCount = 0
        totalTurnsCount = 0
        turnComboCount = 0
        comboExpiresAt = 0
        lastDisplayedComboCount = 0
        starvationStepsRemaining = 0
        starvationStepCapacity = 0
        currentTryNumber = nextTryNumber
        nextTryNumber += 1
        currentRunSubmitted = false
        saveHighScores()

        snakeContainer.removeAllChildren()
        snakeSegmentNodes.removeAll()
        foodContainer.removeAllChildren()
        foodNode = nil
        bonusFoodNode = nil
        bonusFoodExpiresAt = 0
        nextBonusFoodSpawnAt = 0
        snakeStrokeBaseAlpha.removeAll()
        snakeStrokeBaseBrightness.removeAll()
        snakeStrokeBaseLineWidth.removeAll()
        snakeStrokeBlinkUntil.removeAll()
        snakeTurnPulseStart.removeAll()
        snakeTurnPulseUntil.removeAll()
        snakeTurnPulseStrength.removeAll()
        digestionPulses.removeAll()
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
        resetStarvationSteps()
        spawnFood()
        scheduleNextBonusFoodSpawn(from: currentFrameTime)
        updateHUD()
    }

    func setupAttractSnake() {
        isGameOver = false
        foodCell = nil
        foodNode?.removeFromParent()
        foodNode = nil
        bonusFoodCell = nil
        bonusFoodNode?.removeFromParent()
        bonusFoodNode = nil
        bonusFoodExpiresAt = 0
        nextBonusFoodSpawnAt = 0
        foodContainer.removeAllChildren()
        snakeContainer.removeAllChildren()
        snakeSegmentNodes.removeAll()
        snakeStrokeBaseAlpha.removeAll()
        snakeStrokeBaseBrightness.removeAll()
        snakeStrokeBaseLineWidth.removeAll()
        snakeStrokeBlinkUntil.removeAll()
        snakeTurnPulseStart.removeAll()
        snakeTurnPulseUntil.removeAll()
        snakeTurnPulseStrength.removeAll()
        digestionPulses.removeAll()
        clearBorderGlow()
        lastDisplayedComboCount = 0
        starvationStepsRemaining = 0
        starvationStepCapacity = 0
        currentMoveInterval = max(0.12, initialMoveInterval * 0.9)

        let midY = rows / 2
        snakeCells = [
            GridPoint(x: 8, y: midY),
            GridPoint(x: 7, y: midY),
            GridPoint(x: 6, y: midY),
            GridPoint(x: 5, y: midY),
            GridPoint(x: 4, y: midY)
        ]
        direction = GridPoint(x: 1, y: 0)
        pendingDirection = nil
        lastAttractMoveTime = 0

        for _ in snakeCells {
            let segment = SKShapeNode(
                rectOf: CGSize(width: cellSize - gridCellInset, height: cellSize - gridCellInset),
                cornerRadius: gridCellCornerRadius
            )
            segment.lineWidth = 0.8
            snakeContainer.addChild(segment)
            snakeSegmentNodes.append(segment)
        }

        spawnFood()
        redrawSnake()
        redrawFood()
    }

    func advanceAttractSnake() {
        guard let head = snakeCells.first else { return }
        if foodCell == nil { spawnFood() }

        let candidateDirections = [
            GridPoint(x: 1, y: 0),
            GridPoint(x: -1, y: 0),
            GridPoint(x: 0, y: 1),
            GridPoint(x: 0, y: -1)
        ]
        let bodySet = Set(snakeCells.dropLast())
        let targetFood = foodCell

        let valid = candidateDirections.filter { candidate in
            if isOpposite(candidate, to: direction) { return false }
            let next = GridPoint(x: head.x + candidate.x, y: head.y + candidate.y)
            guard (0..<columns).contains(next.x), (0..<rows).contains(next.y) else { return false }
            return !bodySet.contains(next)
        }

        let fallback = candidateDirections.filter { candidate in
            let next = GridPoint(x: head.x + candidate.x, y: head.y + candidate.y)
            return (0..<columns).contains(next.x) && (0..<rows).contains(next.y)
        }

        let pool = valid.isEmpty ? fallback : valid
        if let best = pool.min(by: { lhs, rhs in
            let l = GridPoint(x: head.x + lhs.x, y: head.y + lhs.y)
            let r = GridPoint(x: head.x + rhs.x, y: head.y + rhs.y)
            let targetX = targetFood?.x ?? head.x
            let targetY = targetFood?.y ?? head.y
            let lDist = abs(l.x - targetX) + abs(l.y - targetY)
            let rDist = abs(r.x - targetX) + abs(r.y - targetY)
            if lDist == rDist {
                let lTurn = lhs == direction ? 0 : 1
                let rTurn = rhs == direction ? 0 : 1
                return lTurn < rTurn
            }
            return lDist < rDist
        }) {
            direction = best
        }

        let newHead = GridPoint(x: head.x + direction.x, y: head.y + direction.y)
        snakeCells.insert(newHead, at: 0)
        snakeCells.removeLast()

        if foodCell == newHead {
            foodCell = nil
            foodNode?.removeAllActions()
            foodNode?.removeFromParent()
            foodNode = nil
            spawnFood()
        }
    }

    func advanceSnake() {
        guard let head = snakeCells.first else { return }

        if let pendingDirection, !isOpposite(pendingDirection, to: direction) {
            if pendingDirection != direction {
                totalTurnsCount += 1
                if currentFrameTime <= comboExpiresAt, turnComboCount > 0 {
                    turnComboCount += 1
                } else {
                    turnComboCount = 1
                }
                comboExpiresAt = currentFrameTime + comboTurnTimeout
                score += pointsPerTurn
                shouldPulseTurnCornerOnNextRedraw = true
            }
            direction = pendingDirection
        }
        self.pendingDirection = nil

        let newHead = GridPoint(x: head.x + direction.x, y: head.y + direction.y)

        guard (0..<columns).contains(newHead.x), (0..<rows).contains(newHead.y) else {
            triggerGameOver(.wall)
            return
        }

        if snakeCells.dropLast().contains(newHead) {
            triggerGameOver(.selfBite)
            return
        }

        let didEatBonusFood = (bonusFoodCell == newHead)
        let didEatFood = (foodCell == newHead)
        snakeCells.insert(newHead, at: 0)

        if didEatBonusFood {
            score += pointsPerBonusFood
            resetStarvationSteps()
            consumeBonusFood()
        }

        if didEatFood {
            appendSnakeSegmentNode()
            foodEatenCount += 1
            score += pointsPerFood
            triggerFoodDigestionPulse()
            speedUpSnake()
            resetStarvationSteps()

            if snakeCells.count >= columns * rows {
                foodCell = nil
                foodNode?.removeAllActions()
                foodNode?.removeFromParent()
                foodNode = nil
                score += pointsPerTile
                updateHUD()
                triggerGameOver(.boardFilled)
                return
            } else {
                consumeFoodAndRespawn()
            }
        } else {
            snakeCells.removeLast()
            starvationStepsRemaining = max(0, starvationStepsRemaining - 1)
        }

        score += pointsPerTile
        updateHUD()

        if starvationStepsRemaining <= 0 {
            triggerGameOver(.starved)
        }
    }

    @discardableResult
    func handleSwipe(from start: CGPoint, to end: CGPoint) -> Bool {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let threshold = max(10, cellSize * 0.28)

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

    private func triggerGameOver(_ reason: EndReason) {
        isGameOver = true
        foodNode?.removeAllActions()
        bonusFoodNode?.removeAllActions()
        let isNewHighScore = recordCurrentRunScore()
        let hiScoreValue = topHighScoreValue()
        updateHUD()

        for (index, node) in snakeSegmentNodes.enumerated() {
            let alpha = index == 0 ? 0.9 : 0.55
            node.strokeColor = theme.color(brightness: 1.0, alpha: alpha)
            node.fillColor = theme.color(brightness: 0.9, alpha: 0.1)
        }
        clearBorderGlow()
        digestionPulses.removeAll()
        fadeOutFoodNodesForDeath()

        let showOverlay: () -> Void = { [weak self] in
            self?.presentGameOverOverlay(reason: reason, hiScoreValue: hiScoreValue, isNewHighScore: isNewHighScore)
        }

        if reason == .boardFilled {
            showOverlay()
        } else {
            playDeathAnimation(for: reason, completion: showOverlay)
        }
    }

    private func presentGameOverOverlay(reason: EndReason, hiScoreValue: Int, isNewHighScore: Bool) {
        let overlay = GameOverOverlayNode()
        overlay.updateLayout(sceneSize: size, cellSize: cellSize)
        overlay.applyTheme(
            accent: theme.color(brightness: 1.0, alpha: 1.0),
            panelFill: theme.color(brightness: 0.11, alpha: 0.96)
        )
        overlay.setOutcome(
            title: reason == .boardFilled ? "YOU WIN" : "GAME OVER",
            reason: gameOverReasonText(for: reason)
        )
        overlay.setScoreInfo(score: score, hiScore: hiScoreValue, isNewHighScore: isNewHighScore)
        overlay.onRestart = { [weak self] in
            self?.setupSnake()
        }
        overlay.onMainMenu = { [weak self] in
            self?.showStartScreenOverlay()
        }
        overlayNode.removeAllChildren()
        overlayNode.addChild(overlay)
        gameOverOverlay = overlay
    }

    private func fadeOutFoodNodesForDeath() {
        [foodNode, bonusFoodNode].forEach { node in
            guard let node else { return }
            node.removeAllActions()
            let action = SKAction.group([
                .fadeAlpha(to: 0.0, duration: 0.12),
                .scale(to: 0.9, duration: 0.12)
            ])
            node.run(action)
        }
    }

    private func playDeathAnimation(for reason: EndReason, completion: @escaping () -> Void) {
        guard !snakeSegmentNodes.isEmpty else {
            completion()
            return
        }

        for node in snakeSegmentNodes {
            node.removeAllActions()
        }

        switch reason {
        case .wall:
            animateWallDeath(completion: completion)
        case .selfBite:
            animateSelfBiteDeath(completion: completion)
        case .starved:
            animateStarvationDeath(completion: completion)
        case .boardFilled:
            completion()
        }
    }

    private func animateWallDeath(completion: @escaping () -> Void) {
        let stepDelay: TimeInterval = 0.05
        let segmentDuration: TimeInterval = 0.16
        let lastIndex = max(0, snakeSegmentNodes.count - 1)

        for (index, node) in snakeSegmentNodes.enumerated() {
            let preFlash = SKAction.group([
                .fadeAlpha(to: 1.0, duration: 0.03),
                .scale(to: 1.05, duration: 0.03)
            ])
            let vanish = SKAction.group([
                .fadeOut(withDuration: segmentDuration),
                .scale(to: 0.75, duration: segmentDuration)
            ])
            let delay = SKAction.wait(forDuration: Double(index) * stepDelay)
            var actions: [SKAction] = [delay, preFlash, vanish]
            if index == lastIndex {
                actions.append(.run(completion))
            }
            node.run(.sequence(actions), withKey: "death")
        }
    }

    private func animateSelfBiteDeath(completion: @escaping () -> Void) {
        let centerIndex = max(0, min(1, snakeSegmentNodes.count - 1))
        let maxDistance = max(1, snakeSegmentNodes.count - 1)
        let finishDelay = 0.36 + Double(maxDistance) * 0.04

        for (index, node) in snakeSegmentNodes.enumerated() {
            let distance = abs(index - centerIndex)
            let delay = SKAction.wait(forDuration: Double(distance) * 0.04)
            let flash = SKAction.run { [weak self, weak node] in
                guard let self, let node else { return }
                node.strokeColor = self.theme.color(brightness: 1.0, alpha: 0.95)
                node.fillColor = self.theme.color(brightness: 1.0, alpha: 0.18)
            }
            let wobble = SKAction.sequence([
                .moveBy(x: CGFloat.random(in: -4...4), y: CGFloat.random(in: -4...4), duration: 0.05),
                .moveBy(x: CGFloat.random(in: -3...3), y: CGFloat.random(in: -3...3), duration: 0.05)
            ])
            let collapse = SKAction.group([
                .fadeOut(withDuration: 0.18),
                .scale(to: 0.7, duration: 0.18)
            ])
            node.run(.sequence([delay, flash, wobble, collapse]), withKey: "death")
        }

        run(.sequence([.wait(forDuration: finishDelay), .run(completion)]), withKey: "selfBiteDeathCompletion")
    }

    private func animateStarvationDeath(completion: @escaping () -> Void) {
        var maxDelay: TimeInterval = 0

        for node in snakeSegmentNodes {
            let delayValue = TimeInterval.random(in: 0.0...0.22)
            maxDelay = max(maxDelay, delayValue)
            let delay = SKAction.wait(forDuration: delayValue)
            let flicker = SKAction.sequence([
                .fadeAlpha(to: 0.15, duration: 0.03),
                .fadeAlpha(to: 0.9, duration: 0.025),
                .fadeAlpha(to: 0.08, duration: 0.04),
                .fadeAlpha(to: 0.6, duration: 0.03)
            ])
            let fadeOut = SKAction.group([
                .fadeOut(withDuration: 0.2),
                .scale(to: 0.82, duration: 0.2)
            ])
            node.run(.sequence([delay, flicker, fadeOut]), withKey: "death")
        }

        run(.sequence([.wait(forDuration: maxDelay + 0.35), .run(completion)]), withKey: "starveDeathCompletion")
    }

    private func gameOverReasonText(for reason: EndReason) -> String {
        switch reason {
        case .wall:
            return "Bonk. Wall 1, snake 0."
        case .selfBite:
            return "You bit yourself. Tasty but fatal."
        case .starved:
            return "Too many tricks, not enough snacks."
        case .boardFilled:
            return "Every tile claimed. Snake domination."
        }
    }

    func redrawSnake(animated: Bool = false) {
        ensureSnakeFlickerStorage()
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
                snakeStrokeBaseBrightness[index] = 1.0
                snakeStrokeBaseAlpha[index] = 0.75
                snakeStrokeBaseLineWidth[index] = max(1.0, cellSize * 0.1)
                node.lineWidth = snakeStrokeBaseLineWidth[index]
                node.strokeColor = theme.color(
                    brightness: snakeStrokeBaseBrightness[index],
                    alpha: snakeStrokeBaseAlpha[index]
                )
            } else {
                let fillAlpha = max(0.11, 0.23 - CGFloat(index) * 0.02)
                let strokeAlpha = max(0.34, 0.62 - CGFloat(index) * 0.055)
                let bodyBrightness = max(0.78, 0.95 - CGFloat(index) * 0.03)
                node.fillColor = theme.color(brightness: bodyBrightness, alpha: fillAlpha)
                let strokeBrightness = min(1.0, bodyBrightness + 0.1)
                snakeStrokeBaseBrightness[index] = strokeBrightness
                snakeStrokeBaseAlpha[index] = strokeAlpha
                snakeStrokeBaseLineWidth[index] = max(0.9, cellSize * 0.085)
                node.lineWidth = snakeStrokeBaseLineWidth[index]
                node.strokeColor = theme.color(
                    brightness: snakeStrokeBaseBrightness[index],
                    alpha: snakeStrokeBaseAlpha[index]
                )
            }
        }

        updateGridGlowNearHead()
        if isStartScreenPresentation {
            clearBorderGlow()
        } else {
            updateBorderGlowNearSnake()
        }

        if shouldPulseTurnCornerOnNextRedraw {
            triggerTurnCornerGlowPulse()
            shouldPulseTurnCornerOnNextRedraw = false
        }
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
                let index = (row * columns) + col
                let flickerScale = index < gridCellFlickerScale.count ? gridCellFlickerScale[index] : 1.0
                let isBlinking = index < gridCellBlinkUntil.count ? currentFrameTime < gridCellBlinkUntil[index] : false
                let blinkAlphaMul: CGFloat = isBlinking ? 0.35 : 1.0
                let glowAlpha = (baseAlpha + intensity * 0.13) * flickerScale * blinkAlphaMul
                let brightness = min(1.0, (0.93 + intensity * 0.07) * (isBlinking ? 0.94 : 1.0))
                let lineWidth = 0.5 + intensity * 0.55

                let node = gridCellNodes[index]
                node.strokeColor = theme.color(brightness: brightness, alpha: glowAlpha)
                node.lineWidth = lineWidth
            }
        }
    }

    func updateGridFlicker(_ currentTime: TimeInterval) {
        guard !gridCellNodes.isEmpty else { return }

        if currentTime >= nextGridFlickerJitter {
            nextGridFlickerJitter = currentTime + TimeInterval.random(in: 0.08...0.22)
            for i in gridCellFlickerScale.indices {
                // Tiny ambient variation only.
                gridCellFlickerScale[i] = CGFloat.random(in: 0.92...1.08)
            }
        }

        if currentTime >= nextGridBlinkAttempt {
            nextGridBlinkAttempt = currentTime + TimeInterval.random(in: 0.25...0.7)
            if CGFloat.random(in: 0...1) < 0.35 {
                let blinkCount = Int.random(in: 1...3)
                for _ in 0..<blinkCount {
                    let idx = Int.random(in: 0..<gridCellNodes.count)
                    gridCellBlinkUntil[idx] = currentTime + TimeInterval.random(in: 0.015...0.05)
                }
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

        guard let nextFood = randomFreeCell(excluding: bonusFoodCell.map { [$0] } ?? []) else { return }
        foodCell = nextFood
        ensureFoodNode()
        redrawFood()
        animateFoodSpawnFlicker()
    }

    func ensureFoodNode() {
        guard foodNode == nil else { return }
        let node = SKShapeNode(
            rectOf: CGSize(width: cellSize - gridCellInset, height: cellSize - gridCellInset),
            cornerRadius: gridCellCornerRadius
        )
        node.lineWidth = max(1.1, cellSize * 0.09)
        node.fillColor = theme.color(brightness: 1.0, alpha: 0.12)
        node.strokeColor = theme.color(brightness: 1.0, alpha: 0.92)
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
        foodNode.lineWidth = max(1.1, cellSize * 0.09)
        foodNode.fillColor = theme.color(brightness: 1.0, alpha: 0.12)
        foodNode.strokeColor = theme.color(brightness: 1.0, alpha: 0.92)
        foodNode.alpha = 1.0
        foodNode.setScale(1.0)
    }

    func ensureBonusFoodNode() {
        guard bonusFoodNode == nil else { return }
        let node = SKShapeNode(
            rectOf: CGSize(width: cellSize - gridCellInset, height: cellSize - gridCellInset),
            cornerRadius: gridCellCornerRadius
        )
        node.lineWidth = max(1.3, cellSize * 0.11)
        node.fillColor = theme.color(brightness: 1.0, alpha: 0.06)
        node.strokeColor = theme.color(brightness: 1.0, alpha: 1.0)
        foodContainer.addChild(node)
        bonusFoodNode = node
    }

    func redrawBonusFood() {
        guard let bonusFoodCell, let bonusFoodNode else { return }
        if bonusFoodNode.parent == nil {
            foodContainer.addChild(bonusFoodNode)
        }

        bonusFoodNode.position = point(for: bonusFoodCell)
        let size = CGSize(width: cellSize - gridCellInset, height: cellSize - gridCellInset)
        bonusFoodNode.path = CGPath(
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
        bonusFoodNode.lineWidth = max(1.3, cellSize * 0.11)
        bonusFoodNode.fillColor = theme.color(brightness: 1.0, alpha: 0.06)
        bonusFoodNode.strokeColor = theme.color(brightness: 1.0, alpha: 1.0)
        bonusFoodNode.alpha = 1.0
        bonusFoodNode.setScale(1.0)
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

    func animateFoodSpawnFlicker() {
        guard let foodNode else { return }
        foodNode.removeAllActions()
        foodNode.alpha = 0.0
        foodNode.setScale(0.96)

        let flickerSequence = SKAction.sequence([
            .fadeAlpha(to: 0.95, duration: 0.03),
            .fadeAlpha(to: 0.2, duration: 0.02),
            .fadeAlpha(to: 0.75, duration: 0.025),
            .fadeAlpha(to: 0.35, duration: 0.02),
            .group([
                .fadeAlpha(to: 1.0, duration: 0.05),
                .scale(to: 1.0, duration: 0.06)
            ]),
            .run { [weak self] in self?.startFoodBlink() }
        ])
        foodNode.run(flickerSequence, withKey: "spawnFlicker")
    }

    func consumeFoodAndRespawn() {
        foodCell = nil
        guard let node = foodNode else {
            spawnFood()
            return
        }

        node.removeAllActions()
        node.run(.sequence([
            .sequence([
                .fadeAlpha(to: 0.25, duration: 0.025),
                .fadeAlpha(to: 0.9, duration: 0.02),
                .fadeAlpha(to: 0.1, duration: 0.03),
                .group([
                    .fadeOut(withDuration: 0.04),
                    .scale(to: 1.05, duration: 0.04)
                ])
            ]),
            .run { [weak self, weak node] in
                guard let self else { return }
                if let node {
                    node.removeFromParent()
                    if self.foodNode === node {
                        self.foodNode = nil
                    }
                }
                guard !self.isGameOver else { return }
                self.spawnFood()
            }
        ]))
    }

    func scheduleNextBonusFoodSpawn(from currentTime: TimeInterval) {
        nextBonusFoodSpawnAt = currentTime + TimeInterval.random(in: 5.5...10.5)
    }

    func updateBonusFoodState(_ currentTime: TimeInterval) {
        guard startScreenOverlay == nil, !isGameOver else { return }

        if bonusFoodCell != nil {
            if currentTime >= bonusFoodExpiresAt {
                removeBonusFood(animated: true)
                scheduleNextBonusFoodSpawn(from: currentTime)
            }
            return
        }

        if nextBonusFoodSpawnAt == 0 {
            scheduleNextBonusFoodSpawn(from: currentTime)
            return
        }

        if currentTime >= nextBonusFoodSpawnAt {
            spawnBonusFood(currentTime: currentTime)
        }
    }

    func spawnBonusFood(currentTime: TimeInterval) {
        guard bonusFoodCell == nil else { return }
        guard snakeCells.count < columns * rows else { return }
        guard let nextCell = randomFreeCell(excluding: foodCell.map { [$0] } ?? []) else {
            scheduleNextBonusFoodSpawn(from: currentTime)
            return
        }

        bonusFoodCell = nextCell
        bonusFoodExpiresAt = currentTime + TimeInterval.random(in: 2.4...3.8)
        ensureBonusFoodNode()
        redrawBonusFood()
        animateBonusFoodSpawnFlicker()
        startBonusFoodBlink()
    }

    func startBonusFoodBlink() {
        guard let bonusFoodNode else { return }
        bonusFoodNode.removeAction(forKey: "bonusBlink")
        let pulseDown = SKAction.group([
            .fadeAlpha(to: 0.2, duration: 0.22),
            .scale(to: 0.9, duration: 0.22)
        ])
        let pulseUp = SKAction.group([
            .fadeAlpha(to: 1.0, duration: 0.22),
            .scale(to: 1.0, duration: 0.22)
        ])
        bonusFoodNode.run(.repeatForever(.sequence([pulseDown, pulseUp])), withKey: "bonusBlink")
    }

    func animateBonusFoodSpawnFlicker() {
        guard let bonusFoodNode else { return }
        bonusFoodNode.removeAllActions()
        bonusFoodNode.alpha = 0.0
        bonusFoodNode.setScale(0.88)
        let seq = SKAction.sequence([
            .fadeAlpha(to: 1.0, duration: 0.02),
            .fadeAlpha(to: 0.12, duration: 0.015),
            .fadeAlpha(to: 0.95, duration: 0.02),
            .fadeAlpha(to: 0.18, duration: 0.015),
            .group([
                .fadeAlpha(to: 1.0, duration: 0.04),
                .scale(to: 1.0, duration: 0.05)
            ]),
            .run { [weak self] in self?.startBonusFoodBlink() }
        ])
        bonusFoodNode.run(seq, withKey: "bonusSpawn")
    }

    func consumeBonusFood() {
        removeBonusFood(animated: true)
        scheduleNextBonusFoodSpawn(from: currentFrameTime)
    }

    func removeBonusFood(animated: Bool) {
        bonusFoodCell = nil
        guard let node = bonusFoodNode else { return }
        node.removeAllActions()
        if !animated {
            node.removeFromParent()
            if bonusFoodNode === node { bonusFoodNode = nil }
            return
        }

        node.run(.sequence([
            .group([
                .fadeOut(withDuration: 0.06),
                .scale(to: 1.08, duration: 0.06)
            ]),
            .run { [weak self, weak node] in
                guard let self else { return }
                if let node {
                    node.removeFromParent()
                    if self.bonusFoodNode === node { self.bonusFoodNode = nil }
                }
            }
        ]))
    }

    func randomFreeCell(excluding extraBlocked: [GridPoint] = []) -> GridPoint? {
        let blocked = Set(extraBlocked)
        let freeCells = (0..<rows).flatMap { row in
            (0..<columns).compactMap { col -> GridPoint? in
                let point = GridPoint(x: col, y: row)
                if snakeCells.contains(point) { return nil }
                if blocked.contains(point) { return nil }
                return point
            }
        }
        return freeCells.randomElement()
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

    func updateSnakeStrokeFlicker(_ currentTime: TimeInterval) {
        guard !isGameOver else { return }
        guard !snakeSegmentNodes.isEmpty else { return }
        ensureSnakeFlickerStorage()
        let starvationSeverity = starvationFlickerSeverity()
        let starvationDriven = starvationSeverity > 0.01

        if currentTime >= nextSnakeStrokeJitter {
            if starvationDriven {
                let jitterMax = max(0.08, 0.28 - TimeInterval(starvationSeverity) * 0.2)
                let jitterMin = max(0.025, jitterMax * 0.35)
                nextSnakeStrokeJitter = currentTime + TimeInterval.random(in: jitterMin...jitterMax)

                let baseChance = 0.02 + (0.30 * starvationSeverity * starvationSeverity)
                for index in snakeSegmentNodes.indices {
                    guard currentTime >= snakeStrokeBlinkUntil[index] else { continue }
                    if CGFloat.random(in: 0...1) < baseChance {
                        let duration = TimeInterval.random(in: 0.02...0.06 + 0.07 * starvationSeverity)
                        snakeStrokeBlinkUntil[index] = currentTime + duration
                    }
                }
            } else {
                nextSnakeStrokeJitter = currentTime + 0.18
            }
        }

        if currentTime >= nextSnakeStrokeBlinkAttempt {
            if starvationDriven {
                let gapMax = max(0.22, 0.85 - TimeInterval(starvationSeverity) * 0.55)
                let gapMin = max(0.08, gapMax * 0.45)
                nextSnakeStrokeBlinkAttempt = currentTime + TimeInterval.random(in: gapMin...gapMax)
                if !snakeSegmentNodes.isEmpty, CGFloat.random(in: 0...1) < (0.1 + 0.65 * starvationSeverity) {
                    let burstCount = min(
                        snakeSegmentNodes.count,
                        max(1, Int((CGFloat.random(in: 0.6...2.4) + starvationSeverity * 2.3).rounded(.down)))
                    )
                    for _ in 0..<burstCount {
                        let idx = Int.random(in: 0..<snakeSegmentNodes.count)
                        let burstDuration = TimeInterval.random(in: 0.018...0.05 + 0.05 * starvationSeverity)
                        snakeStrokeBlinkUntil[idx] = max(snakeStrokeBlinkUntil[idx], currentTime + burstDuration)
                    }
                }
            } else {
                // Disable ambient random snake flicker when not starving.
                nextSnakeStrokeBlinkAttempt = currentTime + 0.6
            }
        }

        for index in snakeSegmentNodes.indices {
            let node = snakeSegmentNodes[index]
            let blinking = currentTime < snakeStrokeBlinkUntil[index]
            let baseAlpha = snakeStrokeBaseAlpha[index]
            let baseBrightness = snakeStrokeBaseBrightness[index]
            let baseLineWidth = snakeStrokeBaseLineWidth[index]
            let jitter = CGFloat.random(in: 0.88...1.12)
            var proximityBoost: CGFloat = 0
            if index > 0, let headNode = snakeSegmentNodes.first {
                let distance = hypot(node.position.x - headNode.position.x, node.position.y - headNode.position.y)
                let radius = cellSize * 2.4
                proximityBoost = max(0, 1 - (distance / radius))
            }
            let turnPulse = turnPulseAmount(for: index, currentTime: currentTime)
            let digestionPulse = digestionPulseAmount(for: index, currentTime: currentTime)

            let alpha = blinking
                ? baseAlpha * 0.2
                : min(1.0, baseAlpha * jitter + proximityBoost * 0.28 + turnPulse * 0.42 + digestionPulse * 0.5)
            let brightness = blinking
                ? max(0.7, baseBrightness - 0.15)
                : min(1.0, baseBrightness + CGFloat.random(in: -0.02...0.03) + proximityBoost * 0.08 + turnPulse * 0.14 + digestionPulse * 0.18)
            node.strokeColor = theme.color(brightness: brightness, alpha: alpha)
            node.lineWidth = baseLineWidth
                + proximityBoost * max(0.25, cellSize * 0.03)
                + turnPulse * max(0.4, cellSize * 0.06)
                + digestionPulse * max(0.45, cellSize * 0.055)
        }
    }

    func ensureSnakeFlickerStorage() {
        let count = snakeSegmentNodes.count
        if snakeStrokeBaseAlpha.count != count
            || snakeTurnPulseStart.count != count
            || snakeTurnPulseUntil.count != count
            || snakeTurnPulseStrength.count != count {
            snakeStrokeBaseAlpha = Array(repeating: 0.5, count: count)
            snakeStrokeBaseBrightness = Array(repeating: 1.0, count: count)
            snakeStrokeBaseLineWidth = Array(repeating: 1.0, count: count)
            snakeStrokeBlinkUntil = Array(repeating: 0, count: count)
            snakeTurnPulseStart = Array(repeating: 0, count: count)
            snakeTurnPulseUntil = Array(repeating: 0, count: count)
            snakeTurnPulseStrength = Array(repeating: 0, count: count)
        }
    }

    func triggerTurnCornerGlowPulse() {
        guard snakeSegmentNodes.count > 1 else { return }
        ensureSnakeFlickerStorage()

        let now = currentFrameTime > 0 ? currentFrameTime : CACurrentMediaTime()
        queueTurnPulse(for: 1, at: now, duration: 0.34, strength: 1.0)

        if snakeSegmentNodes.count > 2 {
            queueTurnPulse(for: 2, at: now + 0.02, duration: 0.28, strength: 0.5)
        }
    }

    func queueTurnPulse(for index: Int, at start: TimeInterval, duration: TimeInterval, strength: CGFloat) {
        guard index >= 0, index < snakeSegmentNodes.count else { return }
        snakeTurnPulseStart[index] = start
        snakeTurnPulseUntil[index] = start + duration
        snakeTurnPulseStrength[index] = max(snakeTurnPulseStrength[index], strength)
    }

    func turnPulseAmount(for index: Int, currentTime: TimeInterval) -> CGFloat {
        guard index >= 0, index < snakeTurnPulseUntil.count else { return 0 }
        let end = snakeTurnPulseUntil[index]
        guard currentTime < end else {
            if index < snakeTurnPulseStrength.count {
                snakeTurnPulseStrength[index] = 0
            }
            return 0
        }

        let start = snakeTurnPulseStart[index]
        let duration = max(0.001, end - start)
        let t = max(0, min(1, CGFloat((currentTime - start) / duration)))
        // Quick neon pop with soft decay.
        let envelope = sin(t * .pi)
        let shaped = pow(envelope, 0.75) * (1.0 - t * 0.1)
        return max(0, shaped) * snakeTurnPulseStrength[index]
    }

    func triggerFoodDigestionPulse() {
        let now = currentFrameTime > 0 ? currentFrameTime : CACurrentMediaTime()
        let pulse = DigestionPulse(
            startTime: now,
            segmentDelay: max(0.045, currentMoveInterval * 0.9),
            segmentDuration: max(0.12, currentMoveInterval * 0.75),
            estimatedSegmentCount: max(1, snakeSegmentNodes.count)
        )
        digestionPulses.append(pulse)
    }

    func digestionPulseAmount(for index: Int, currentTime: TimeInterval) -> CGFloat {
        guard !digestionPulses.isEmpty else { return 0 }

        var strongest: CGFloat = 0
        digestionPulses.removeAll { pulse in
            let endTime = pulse.startTime
                + pulse.segmentDelay * Double(max(pulse.estimatedSegmentCount, snakeSegmentNodes.count) + 1)
                + pulse.segmentDuration
            if currentTime > endTime { return true }

            let segmentStart = pulse.startTime + (Double(index) * pulse.segmentDelay)
            let segmentEnd = segmentStart + pulse.segmentDuration
            guard currentTime >= segmentStart, currentTime <= segmentEnd else { return false }

            let t = CGFloat((currentTime - segmentStart) / max(0.001, pulse.segmentDuration))
            let envelope = sin(t * .pi)
            let shaped = pow(max(0, envelope), 0.7)
            strongest = max(strongest, shaped)
            return false
        }

        return strongest
    }

    func speedUpSnake() {
        currentMoveInterval = max(minimumMoveInterval, currentMoveInterval - moveIntervalStep)
    }

    func resetStarvationSteps() {
        starvationStepCapacity = max(1, columns * starvationRowsWorth)
        starvationStepsRemaining = starvationStepCapacity
    }

    func starvationFlickerSeverity() -> CGFloat {
        guard starvationStepCapacity > 0 else { return 0.0 }
        let ratio = CGFloat(starvationStepsRemaining) / CGFloat(starvationStepCapacity)
        let clamped = max(0, min(1, ratio))
        // Calm for most of the hunger bar, then ramps faster near starvation.
        let severity = 1 - clamped
        return max(0, pow(severity, 1.35))
    }

    func setupHUD() {
        hudNode.removeAllChildren()
        hudNode.zPosition = 20

        scoreHUDText.configure(fontName: "Menlo-Bold", fontSize: max(12, cellSize * 0.55), color: theme.color(brightness: 1.0, alpha: 1))
        hiScoreHUDText.configure(fontName: "Menlo-Bold", fontSize: max(10, cellSize * 0.42), color: theme.color(brightness: 1.0, alpha: 1))
        foodHUDText.configure(fontName: "Menlo-Bold", fontSize: max(10, cellSize * 0.42), color: theme.color(brightness: 1.0, alpha: 1))
        turnsHUDText.configure(fontName: "Menlo-Bold", fontSize: max(10, cellSize * 0.42), color: theme.color(brightness: 1.0, alpha: 1))
        comboHUDText.configure(fontName: "Menlo-Bold", fontSize: max(10, cellSize * 0.48), color: theme.color(brightness: 1.0, alpha: 1))

        hudNode.addChild(scoreHUDText)
        hudNode.addChild(hiScoreHUDText)
        hudNode.addChild(foodHUDText)
        hudNode.addChild(turnsHUDText)
        hudNode.addChild(comboHUDText)

        layoutHUD()
    }

    func layoutHUD() {
        let fontSize = max(12, cellSize > 0 ? cellSize * 0.55 : 14)
        let smallFontSize = max(10, cellSize > 0 ? cellSize * 0.42 : 12)
        let comboFontSize = max(10, cellSize > 0 ? cellSize * 0.48 : 12)
        scoreHUDText.setFontSize(fontSize)
        hiScoreHUDText.setFontSize(smallFontSize)
        foodHUDText.setFontSize(smallFontSize)
        turnsHUDText.setFontSize(smallFontSize)
        comboHUDText.setFontSize(comboFontSize)

        let y = boardHeight * 0.5 + max(cellSize * 0.9, 18)
        let sideX = boardWidth * 0.5 - max(cellSize * 2.8, 78)
        scoreHUDText.position = CGPoint(x: 0, y: y + max(12, cellSize * 0.55))
        hiScoreHUDText.position = CGPoint(x: 0, y: y - max(2, cellSize * 0.12))
        foodHUDText.position = CGPoint(x: -sideX, y: y)
        turnsHUDText.position = CGPoint(x: sideX, y: y)
        comboHUDText.position = CGPoint(x: sideX, y: y + max(14, cellSize * 0.75))
    }

    func updateHUD() {
        let previousCombo = lastDisplayedComboCount
        let scoreText = "SCORE \(score)"
        let hiText = "HI \(topHighScoreValue())"
        let foodText = "FOOD \(foodEatenCount)"
        let turnsText = "TURNS \(totalTurnsCount)"
        let comboText = "COMBO x\(turnComboCount)"

        scoreHUDText.setText(scoreText)
        hiScoreHUDText.setText(hiText)
        foodHUDText.setText(foodText)
        turnsHUDText.setText(turnsText)
        comboHUDText.setText(comboText)

        if turnComboCount > 1 {
            if previousCombo <= 1 {
                comboHUDText.alpha = 1.0
            }
        } else if previousCombo <= 1 {
            comboHUDText.alpha = 0.0
        }

        if turnComboCount > previousCombo && turnComboCount > 1 {
            animateComboIncrease()
        } else if previousCombo > 1 && turnComboCount <= 1 {
            animateComboReset()
        }

        lastDisplayedComboCount = turnComboCount
    }

    func updateHUDEffects(_ currentTime: TimeInterval) {
        scoreHUDText.updateEffects(currentTime: currentTime)
        hiScoreHUDText.updateEffects(currentTime: currentTime)
        foodHUDText.updateEffects(currentTime: currentTime)
        turnsHUDText.updateEffects(currentTime: currentTime)
        if turnComboCount > 1 {
            comboHUDText.updateEffects(currentTime: currentTime)
        }
    }

    func updateComboTimeout(_ currentTime: TimeInterval) {
        guard turnComboCount > 0 else { return }
        if currentTime > comboExpiresAt {
            if turnComboCount != 0 {
                if turnComboCount > 1 {
                    score += pointsPerTurn * turnComboCount
                }
                turnComboCount = 0
                updateHUD()
            }
        }
    }

    func animateComboIncrease() {
        comboHUDText.removeAllActions()
        comboHUDText.alpha = 1.0
        comboHUDText.setScale(0.86)

        let popUp = SKAction.group([
            .scale(to: 1.12, duration: 0.09),
            .fadeAlpha(to: 1.0, duration: 0.06)
        ])
        popUp.timingMode = .easeOut

        let settle = SKAction.scale(to: 1.0, duration: 0.14)
        settle.timingMode = .easeInEaseOut

        comboHUDText.run(.sequence([popUp, settle]), withKey: "comboPulse")
    }

    func animateComboReset() {
        comboHUDText.removeAllActions()
        comboHUDText.alpha = 1.0
        comboHUDText.setScale(1.0)

        let flicker1 = SKAction.fadeAlpha(to: 0.18, duration: 0.03)
        let flicker2 = SKAction.fadeAlpha(to: 0.9, duration: 0.025)
        let flicker3 = SKAction.fadeAlpha(to: 0.12, duration: 0.03)
        let end = SKAction.group([
            .fadeOut(withDuration: 0.09),
            .scale(to: 0.94, duration: 0.09)
        ])
        let reset = SKAction.run { [weak self] in
            self?.comboHUDText.setScale(1.0)
            self?.comboHUDText.alpha = 0.0
        }

        comboHUDText.run(.sequence([flicker1, flicker2, flicker3, end, reset]), withKey: "comboReset")
    }

    func showStartScreenOverlay() {
        isStartScreenPresentation = true
        buildBoard()
        overlayNode.removeAllChildren()
        gameOverOverlay = nil
        hudNode.alpha = 0.0

        setupAttractSnake()

        let overlay = StartScreenOverlayNode()
        overlay.configure(
            sceneSize: size,
            cellSize: max(cellSize, 16),
            accent: theme.color(brightness: 1.0, alpha: 1.0),
            highScoreLines: highScoreLinesForTitle()
        )
        overlay.onStart = { [weak self] in
            self?.handleStartTapped()
        }
        overlayNode.addChild(overlay)
        startScreenOverlay = overlay
    }

    func handleStartTapped() {
        startScreenOverlay?.removeFromParent()
        startScreenOverlay = nil
        startGame()
    }

    func startGame() {
        isStartScreenPresentation = false
        hudNode.alpha = 1.0
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

    func topHighScoreValue() -> Int {
        highScores.first?.score ?? 0
    }

    func highScoreLinesForTitle() -> [String] {
        let top = Array(highScores.prefix(5))
        if top.isEmpty {
            return ["1. --- TRY -", "2. --- TRY -", "3. --- TRY -", "4. --- TRY -", "5. --- TRY -"]
        }

        var lines: [String] = []
        for (index, entry) in top.enumerated() {
            lines.append("\(index + 1). \(entry.score)  TRY \(entry.tryNumber)")
        }
        while lines.count < 5 {
            lines.append("\(lines.count + 1). --- TRY -")
        }
        return lines
    }

    func loadHighScores() {
        let defaults = UserDefaults.standard
        nextTryNumber = max(1, defaults.integer(forKey: HighScoreStorage.nextTryKey))
        if nextTryNumber == 0 { nextTryNumber = 1 }

        guard let data = defaults.data(forKey: HighScoreStorage.scoresKey),
              let decoded = try? JSONDecoder().decode([HighScoreEntry].self, from: data) else {
            highScores = []
            return
        }

        highScores = decoded
            .sorted { lhs, rhs in
                if lhs.score == rhs.score { return lhs.tryNumber < rhs.tryNumber }
                return lhs.score > rhs.score
            }
    }

    func saveHighScores() {
        let defaults = UserDefaults.standard
        defaults.set(nextTryNumber, forKey: HighScoreStorage.nextTryKey)
        if let data = try? JSONEncoder().encode(highScores) {
            defaults.set(data, forKey: HighScoreStorage.scoresKey)
        }
    }

    func recordCurrentRunScore() -> Bool {
        guard !currentRunSubmitted, currentTryNumber > 0 else { return false }
        currentRunSubmitted = true

        let previousBest = topHighScoreValue()
        highScores.append(HighScoreEntry(tryNumber: currentTryNumber, score: score))
        highScores.sort { lhs, rhs in
            if lhs.score == rhs.score { return lhs.tryNumber < rhs.tryNumber }
            return lhs.score > rhs.score
        }
        if highScores.count > 5 {
            highScores = Array(highScores.prefix(5))
        }
        saveHighScores()
        return score > previousBest
    }

    func addSwipeTrace(from start: CGPoint, to end: CGPoint) {
        let length = hypot(end.x - start.x, end.y - start.y)
        guard length > max(8, cellSize * 0.25) else { return }

        let path = CGMutablePath()
        path.move(to: start)
        path.addLine(to: end)

        let glow = SKShapeNode(path: path)
        glow.lineCap = .round
        glow.lineJoin = .round
        glow.strokeColor = theme.color(brightness: 1.0, alpha: 0.18)
        glow.lineWidth = max(2.0, cellSize * 0.18)
        glow.zPosition = 0

        let core = SKShapeNode(path: path)
        core.lineCap = .round
        core.lineJoin = .round
        core.strokeColor = theme.color(brightness: 1.0, alpha: 0.6)
        core.lineWidth = max(1.0, cellSize * 0.07)
        core.zPosition = 1

        let container = SKNode()
        container.addChild(glow)
        container.addChild(core)
        swipeTraceNode.addChild(container)

        let fade = SKAction.group([
            .fadeOut(withDuration: 0.22),
            .scale(to: 0.97, duration: 0.22)
        ])
        let remove = SKAction.removeFromParent()
        container.run(.sequence([fade, remove]))
    }
}
