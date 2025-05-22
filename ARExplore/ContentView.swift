//
//  ContentView.swift
//  ARExplore
//
//  Created by James Silaban on 20/05/25.
//

import SwiftUI
import RealityKit
import ARKit

/// A UIViewRepresentable wrapper for RealityKit's ARView
struct ARViewContainer: UIViewRepresentable {
    // Capture the coordinator in SwiftUI
    @Binding var coordinatorRef: Coordinator?
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // Configure AR session for plane detection
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        arView.session.run(config)
        
        // Add coaching overlay (optional)
        let coaching = ARCoachingOverlayView()
        coaching.session = arView.session
        coaching.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        coaching.goal = .horizontalPlane
        arView.addSubview(coaching)
        
        // Enable tap gesture for placing objects
        let tap = UITapGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.handleTap(_:)))
        arView.addGestureRecognizer(tap)
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        let c = Coordinator(self)
        // Immediately assign into the binding so SwiftUI sees it
        DispatchQueue.main.async {
            coordinatorRef = c
        }
        return c
    }
    
    /// Coordinator manages gesture callbacks and object placement
    class Coordinator: NSObject {
        var parent: ARViewContainer
        
        // Keep a reference to the placed model so we can play its animations later
        var monsterEntity: Entity?
        var idleAnim: AnimationResource?
        var walkAnim: AnimationResource?
        var attackAnim: AnimationResource?
        
        init(_ parent: ARViewContainer) {
            self.parent = parent
        }
        
        @objc func handleTap(_ sender: UITapGestureRecognizer) {
            guard let arView = sender.view as? ARView else { return }
            let tapLocation = sender.location(in: arView)
            
            // Perform a raycast to find a surface
            if let result = arView.raycast(from: tapLocation,
                                           allowing: .estimatedPlane,
                                           alignment: .horizontal).first {
                let anchor = AnchorEntity(world: result.worldTransform)
                
                // Load a USDZ model (ensure "Monster.usdz" is in app bundle)
                if let modelEntity = try? Entity.load(named: "MonsterGLB") {
                    // ── ADDED: store for later playback
                    self.monsterEntity = modelEntity
                    self.monsterEntity?.scale = SIMD3(repeating: 0.1)
                    
                    // ── ADDED: extract the three named clips
                    let animations = modelEntity.availableAnimations
                    
                    idleAnim   = animations.first(where: { $0.name == "idle" })
                    walkAnim   = animations.first(where: { $0.name == "walk" })
                    attackAnim = animations.first(where: { $0.name == "attack" })
                    print("Loaded animations:", animations.map(\.name))
                        
                    
                    // ── ADDED: start in idle loop
                    if let idle = idleAnim {
                        modelEntity.playAnimation(idle.repeat(), transitionDuration: 0.3)
                    }
                    
                    anchor.addChild(modelEntity)
                    arView.scene.addAnchor(anchor)
                } else {
                    print("Failed to load model")
                }
            }
        }
        
        func playWalk() {
            guard let entity = monsterEntity, let walk = walkAnim else { return }
            entity.playAnimation(walk.repeat(), transitionDuration: 0.3)
        }
        
        func playAttack() {
            guard let entity = monsterEntity, let attack = attackAnim else { return }
            entity.playAnimation(attack, transitionDuration: 0.2)
        }
    }
}

/// SwiftUI ContentView embedding ARViewContainer
struct ContentView: View {
    // Hold onto the Coordinator when it’s created
    @State private var arCoordinator: ARViewContainer.Coordinator? = nil

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Pass the binding down
            ARViewContainer(coordinatorRef: $arCoordinator)
                .edgesIgnoringSafeArea(.all)

            VStack {
                Button("walk") {
                    arCoordinator?.playWalk()
                }
                .padding(8)
                .background(Color.white.opacity(0.75))
                .cornerRadius(8)

                Button("attack") {
                    arCoordinator?.playAttack()
                }
                .padding(8)
                .background(Color.white.opacity(0.75))
                .cornerRadius(8)
            }
            .padding()
        }
    }
}


#Preview {
    ContentView()
}
