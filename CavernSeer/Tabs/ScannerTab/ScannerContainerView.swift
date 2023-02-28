//
//  ScannerContainerView.swift
//  CavernSeer
//
//  Created by Samuel Grush on 6/28/20.
//  Copyright © 2020 Samuel K. Grush. All rights reserved.
//
import ARKit
import CoreML
import SwiftUI /// View

struct ScannerContainerView : View {
    
//    let timer0_1 = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    @EnvironmentObject
    var scanStore: ScanStore

    @ObservedObject
    var control: ScannerControlModel
    
//    @State
//    var bigparents: CVPixelBuffer?
    
    var image_buffer :  CVPixelBuffer? {get { self.control.model?.arView?.session.currentFrame?.capturedImage }}
    
    var VNrequest : VNImageBasedRequest
    
//    let DetectionModel : _3cls_detect_b16_TL_Iteration_1000
    let visionModel : VNCoreMLModel
    
    
    init(control: ScannerControlModel, visionModel : VNCoreMLModel) {
        //init model at topper layer -> init one time only
        self.control = control
        self.bound = UIScreen.main.bounds
        self.visionModel = visionModel
        self.VNrequest = VNCoreMLRequest(model: visionModel) //, completionHandler: <#T##VNRequestCompletionHandler?##VNRequestCompletionHandler?##(VNRequest, Error?) -> Void#>)
//        self.VNrequest.imageCropAndScaleOption = .scaleFill
        
    }
    
    @State
    var RandomInt: Int = 121
    
    var x_max : Double = UIScreen.main.bounds.maxX
    var y_max : Double = UIScreen.main.bounds.maxY
    
    var active_AR_view : ActiveARViewContainer {
        ActiveARViewContainer(control: control)
    }
    
    @State
    var RandomBox: [CGFloat] = [CGFloat(0), CGFloat(0), CGFloat(0), CGFloat(0)]
    
    var bound : CGRect
    
    @State
    var Boundingbox: [Double] = [-50, -50, 0, 0]
    
    @State
    var Bbox_dist: [Float] = [0, 0, 0, 0]
    
    @State
    var Defecttype: String = "Defects"
    
//    // * -> 1  * -> 2
//    //
//    // * -> 4  * -> 3
//
//    @State
//    var Distances: [Double] = [0.0,    // 1->2
//                               0.0,    // 2->3
//                               0.0,    // 3->4
//                               0.0]   // 4->1
    
        
//    @State var Distance: 
    
//    , CGFloat.random(in: 0...300), CGFloat.random(in: 0...300), CGFloat.random(in: 0...300)]

    
    func visionRequest( _ buffer : CVPixelBuffer, VNrequest request : VNImageBasedRequest) {
            
        let handler = VNImageRequestHandler(cvPixelBuffer: buffer)
        try? handler.perform([request])
        
        print("Vision requseted, \(Date.now)")
        
        DispatchQueue.main.async{
            
        if request.results == [] {
            Boundingbox = [-50, -50, 0, 0]
            return
        }
            
        if request.results != nil {
            if !(request.results!.isEmpty){
                
                let predictions = request.results as? [VNRecognizedObjectObservation]
                let prediction = predictions?.first!
                let cls = prediction?.labels[0]
                let bbox = prediction!.boundingBox
                
                guard let name = cls?.identifier
                else { return }
                
                Boundingbox = [bbox.midX * x_max - bbox.width * x_max / 2,
                               bbox.midY * y_max - bbox.height * y_max / 2,
                               bbox.width * x_max,
                               bbox.height * y_max]
                
                if control.SphereEnabled{
                    self.control.model?.handleTap_auto_mark_4_pts(
                        [CGPoint(x: Boundingbox[0]                 , y: Boundingbox[1]                 ),  //Top left
                         CGPoint(x: Boundingbox[0] + Boundingbox[2], y: Boundingbox[1]                 ),  //Top right
                         CGPoint(x: Boundingbox[0] + Boundingbox[2], y: Boundingbox[1] + Boundingbox[3]),  //Bottom right
                         CGPoint(x: Boundingbox[0]                 , y: Boundingbox[1] + Boundingbox[3])   //Bottom left
                        ], defect_name: name)
                    
//                    self.control.SphereEnabled = false
                }
                
//                if control.BboxEnabled {
                    
//                    Boundingbox = [bbox.midX * x_max - bbox.width * x_max / 2,
//                                   bbox.midY * y_max - bbox.height * y_max / 2,
//                                   bbox.width * x_max,
//                                   bbox.height * y_max]
                    
                    self.Bbox_dist = (self.control.model?.handleTaps_info_4_pts(
                        [CGPoint(x: Boundingbox[0]                 , y: Boundingbox[1]                 ),  //Top left
                         CGPoint(x: Boundingbox[0] + Boundingbox[2], y: Boundingbox[1]                 ),  //Top right
                         CGPoint(x: Boundingbox[0] + Boundingbox[2], y: Boundingbox[1] + Boundingbox[3]),  //Bottom right
                         CGPoint(x: Boundingbox[0]                 , y: Boundingbox[1] + Boundingbox[3])   //Bottom left
                        ]))!
                    
                    
                    
                    Defecttype = name
                    print("\(name)'s BBox:  , \(Boundingbox)")

                }
            }
        }
    }
    
    
    

    var body: some View {
        
        if control.cameraEnabled != false {
            if control.renderingPassiveView {
                PassiveCameraViewContainer(control: control)
            }
            
            else if control.renderingARView {
                ZStack{
                    active_AR_view
                    if control.BboxEnabled{
                        Rectangle()
                        .path(in: CGRect(
                            x:      700 - Int(control.Boundingbox_ind_x/2) ,
                            y:      450 - Int(control.Boundingbox_ind_y/2),
                            width:  Int(control.Boundingbox_ind_x),
                            height: Int(control.Boundingbox_ind_y)))
                        .stroke(Color.red, lineWidth: 2.0)
                    }
                }
            }
        }
    }
    
    

    
    
}
