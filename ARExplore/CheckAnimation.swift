//
//  CheckAnimation.swift
//  ARExplore
//
//  Created by James Silaban on 22/05/25.
//

import SwiftUI
import RealityKit
import ARKit


struct ARContainerView: UIViewRepresentable {
    @Binding var arCoordinator: Coordinator?
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // 1. Store the ARView on the coordinator so it can use it later
        context.coordinator.arView = arView
        
        // 2. Run AR session
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        arView.session.run(config)
        
        // 3. (Optional) Coaching overlay
        let coaching = ARCoachingOverlayView()
        coaching.session = arView.session
        coaching.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        coaching.goal = .horizontalPlane
        arView.addSubview(coaching)
        
        // 4. Kick off model loading once the view exists
        context.coordinator.loadMonster()
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        let c = Coordinator()
        // Expose the coordinator back to SwiftUI
        DispatchQueue.main.async { arCoordinator = c }
        return c
    }
    
    class Coordinator: NSObject {
        // Will be set in makeUIView
        var arView: ARView? = nil
        
        // Model + animations
        var monster: Entity?
        var idle: AnimationResource?
        var walk: AnimationResource?
        var attack: AnimationResource?
        
        /// Called once ARView is up, loads + places the model
        func loadMonster() {
            guard let arView = arView else { return }
            do {
                // Load the USDZ (make sure it's in your bundle)
                let model = try Entity.loadModel(named: "brr_brr_patapim_convert")
                model.scale = SIMD3(repeating: 0.1)
                monster = model
                
                // Extract and log clip names
                let clips = model.availableAnimations
                
                let defaults: Set<String> = [
                    "global scene animation",
                    "default scene animation",
                    "default subtree animation"
                ]
                
                let realClips = clips.filter { clip in
                    let name = clip.name?.lowercased() ?? ""
                    return !defaults.contains(name)
                }
                print("RealClips: ", realClips[0])

                
                // 4. Check if you actually have any real ones
                if realClips.isEmpty {
                    print("⚠️ No custom animations found—did you name your NLA tracks ‘Idle’, ‘Walk’, ‘Attack’ before exporting?")
                } else {
                    print("✅ Found real animations:", realClips.compactMap(\.name))
                    // 5. Map them by substring
                    idle   = realClips.first { $0.name?.lowercased().contains("idle") ?? false }
                    walk   = realClips.first { $0.name?.lowercased().contains("walk") ?? false }
                    attack = realClips.first { $0.name?.lowercased().contains("attack") ?? false }
                }
                
                // Place the model 1m in front of the camera
                var t = model.transform
                t.translation = [0, 0, -1]
                let anchor = AnchorEntity(world: t.matrix)
                anchor.addChild(model)
                arView.scene.addAnchor(anchor)
                
                // Start idle loop
                if let clip = idle {
                    model.playAnimation(clip.repeat(), transitionDuration: 0.3)
                }
                
            } catch {
                print("Error loading model:", error)
            }
        }
        
        func playWalk() {
            guard let model = monster, let clip = walk else { return }
            model.playAnimation(clip.repeat(), transitionDuration: 0.3)
        }
        
        func playAttack() {
            guard let model = monster, let clip = attack else { return }
            model.playAnimation(clip, transitionDuration: 0.2)
        }
    }
}


struct CheckAnimation: View {
    @State private var arCoordinator: ARContainerView.Coordinator? = nil
    
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ARContainerView(arCoordinator: $arCoordinator)
                .edgesIgnoringSafeArea(.all)
            
            HStack(spacing: 20) {
                Button("Walk") {
                    arCoordinator?.playWalk()
                }
                .padding()
                .background(Color.white.opacity(0.75))
                .cornerRadius(8)
                
                Button("Attack") {
                    arCoordinator?.playAttack()
                }
                .padding()
                .background(Color.white.opacity(0.75))
                .cornerRadius(8)
            }
            .padding(.bottom, 40)
        }
    }
}

#Preview {
    CheckAnimation()
}
