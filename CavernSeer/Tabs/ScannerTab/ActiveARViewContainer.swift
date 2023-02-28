//
//  ActiveARViewContainer.swift
//  CavernSeer
//
//  Created by Samuel Grush on 1/18/21.
//  Copyright © 2021 Samuel K. Grush. All rights reserved.
//
import ARKit
import CoreML
import SwiftUI /// UIViewRepresentable
import RealityKit /// ARView
import RealityKit
import Vision

struct ActiveARViewContainer: UIViewRepresentable {
    weak var control: ScannerControlModel?
    
    var rayCastResultValue : ARRaycastResult!
    var visionRequests = [VNRequest]()
    
    
    
    //#Isaac_From_ARview_to_ARSCNView
    func makeUIView(context: Context) -> ARView {
//    func makeUIView(context: Context) -> ARSCNView {

        let arView = ARView(frame: .zero)
//        let arView = ARSCNView(frame: .zero)
        
        arView.backgroundColor = UIColor.systemBackground
        
        control?.model?.onViewAppear(arView: arView)
        
        return arView
    }
    
    
    func updateUIView(_ arView: ARView, context: Context) {
//        guard let drawView = control?.model?.drawView else { return }
//        
        print("Hi Isaac \(Date.now)")
//        
//        drawView.frame = arView.frame
//        drawView.updateConstraints()
//        arView.bringSubviewToFront(drawView)
        
    }

    static func dismantleUIView(_ arView: ARView, coordinator: Coordinator) {
        arView.removeFromSuperview()
//        coordinator.control?.scanDisappearing()
    }
}
