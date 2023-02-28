//
//  BoundingBox_layer.swift
//  CavernSeer
//
//  Created by Ho Tin Hung on 2022/9/4.
//  Copyright © 2022 Samuel K. Grush. All rights reserved.
//

import UIKit
import SwiftUI
import AVFoundation
import Vision

class Bbox_layer_Controller: UIViewController{
    
    private let sessionQueue = DispatchQueue(label: "sessionQueue")
    var detectionLayer: CALayer! = nil
    
    var screenRect: CGRect! = nil // For view dimensions
    
    override func viewDidLoad() {
        screenRect = UIScreen.main.bounds
        sessionQueue.async { [unowned self] in
            self.setupLayers()
        }
    }
    
    func setupLayers() {
        detectionLayer = CALayer()
        detectionLayer.frame = CGRect(x: 0, y: 0, width: screenRect.size.width, height: screenRect.size.height)
        
        self.view.layer.addSublayer(detectionLayer)
        
        let boxLayer = CALayer()
        boxLayer.frame = CGRect(x: 100, y: 100, width: 50, height: 50)
        boxLayer.borderWidth = 3.0
        boxLayer.borderColor = CGColor.init(red: 7.0, green: 8.0, blue: 7.0, alpha: 1.0)
        boxLayer.cornerRadius = 4
        
        detectionLayer.addSublayer(boxLayer)
    }
}

struct Bbox_layer_ControllerRepresentable: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        return Bbox_layer_Controller()
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
    }
    
    
//    typealias UIViewControllerType = UIViewController
    
    
    
}
