//
//  GameViewController.swift
//  reSnakeIt
//
//  Created by Dmytro Mayevsky on 22.02.2026.
//

import UIKit
import SpriteKit

class GameViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        guard let skView = self.view as? SKView else { return }

        let scene = GameScene(size: skView.bounds.size)
        scene.scaleMode = .resizeFill

        skView.presentScene(scene)
        skView.ignoresSiblingOrder = true
        skView.showsFPS = false
        skView.showsNodeCount = false
        skView.showsPhysics = false
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        guard let skView = self.view as? SKView,
              let scene = skView.scene else { return }

        if scene.size != skView.bounds.size {
            scene.size = skView.bounds.size
        }
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return [.landscapeLeft, .landscapeRight]
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}
