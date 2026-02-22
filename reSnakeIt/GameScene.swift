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

    private let columns = 28
    private let rows = 16
    private let moveInterval: TimeInterval = 0.12

    private let boardNode = SKNode()
    private let snakeContainer = SKNode()
    private let overlayNode = SKNode()
    private var snakeSegmentNodes: [SKShapeNode] = []
    private var gameOverOverlay: GameOverOverlayNode?

    private var boardWidth: CGFloat = 0
    private var boardHeight: CGFloat = 0
    private var cellSize: CGFloat = 0
    private var gridCellInset: CGFloat = 0
    private var gridCellCornerRadius: CGFloat = 0

    private var lastMoveTime: TimeInterval = 0
    private var snakeCells: [GridPoint] = []
    private var direction = GridPoint(x: 1, y: 0)
    private var pendingDirection: GridPoint?
    private var swipeStartPoint: CGPoint?
    private var isGameOver = false
    private let theme = SessionTheme.random()

    override func didMove(to view: SKView) {
        backgroundColor = theme.color(brightness: 0.08, alpha: 1.0)
        anchorPoint = CGPoint(x: 0.5, y: 0.5)

        removeAllChildren()
        addChild(boardNode)
        boardNode.addChild(snakeContainer)
        addChild(overlayNode)

        buildBoard()
        setupSnake()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard boardNode.parent != nil else { return }
        buildBoard()
        redrawSnake()
        if isGameOver {
            gameOverOverlay?.updateLayout(sceneSize: size, cellSize: cellSize)
        }
    }

    override func update(_ currentTime: TimeInterval) {
        if lastMoveTime == 0 {
            lastMoveTime = currentTime
            return
        }

        guard !isGameOver else { return }
        guard currentTime - lastMoveTime >= moveInterval else { return }
        lastMoveTime = currentTime

        advanceSnake()
        redrawSnake()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        if isGameOver {
            swipeStartPoint = nil
            return
        }
        swipeStartPoint = touch.location(in: self)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
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
        boardNode.addChild(snakeContainer)

        let horizontalPadding = size.width * 0.08
        let verticalPadding = size.height * 0.12
        let availableWidth = size.width - horizontalPadding * 2
        let availableHeight = size.height - verticalPadding * 2

        cellSize = min(availableWidth / CGFloat(columns), availableHeight / CGFloat(rows))
        boardWidth = cellSize * CGFloat(columns)
        boardHeight = cellSize * CGFloat(rows)

        let boardBackground = SKShapeNode(
            rectOf: CGSize(width: boardWidth, height: boardHeight),
            cornerRadius: 10
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
            }
        }

        snakeContainer.zPosition = 2
        overlayNode.zPosition = 10
    }

    func setupSnake() {
        snakeCells = [
            GridPoint(x: 6, y: 10),
            GridPoint(x: 5, y: 10),
            GridPoint(x: 4, y: 10),
            GridPoint(x: 3, y: 10)
        ]
        direction = GridPoint(x: 1, y: 0)
        pendingDirection = nil
        lastMoveTime = 0
        isGameOver = false

        snakeContainer.removeAllChildren()
        snakeSegmentNodes.removeAll()
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

        snakeCells.insert(newHead, at: 0)
        snakeCells.removeLast()
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

        for (index, node) in snakeSegmentNodes.enumerated() {
            let alpha = index == 0 ? 0.9 : 0.55
            node.strokeColor = theme.color(brightness: 1.0, alpha: alpha)
            node.fillColor = theme.color(brightness: 0.9, alpha: 0.1)
        }

        let overlay = GameOverOverlayNode()
        overlay.updateLayout(sceneSize: size, cellSize: cellSize)
        overlay.onRestart = { [weak self] in
            self?.setupSnake()
        }
        overlayNode.removeAllChildren()
        overlayNode.addChild(overlay)
        gameOverOverlay = overlay
    }

    func redrawSnake() {
        for (index, cell) in snakeCells.enumerated() {
            guard index < snakeSegmentNodes.count else { continue }
            let node = snakeSegmentNodes[index]
            node.position = point(for: cell)

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
    }

    func point(for cell: GridPoint) -> CGPoint {
        let halfWidth = boardWidth * 0.5
        let halfHeight = boardHeight * 0.5
        let x = -halfWidth + (CGFloat(cell.x) + 0.5) * cellSize
        let y = -halfHeight + (CGFloat(cell.y) + 0.5) * cellSize
        return CGPoint(x: x, y: y)
    }
}
