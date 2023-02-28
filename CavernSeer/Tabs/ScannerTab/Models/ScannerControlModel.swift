//
//  ScannerControlModel.swift
//  CavernSeer
//
//  Created by Samuel Grush on 1/16/21.
//  Copyright © 2021 Samuel K. Grush. All rights reserved.
//

import SwiftUI
import Foundation
import VideoToolbox
import Vision


class ScannerControlModel : ObservableObject {
    
    let DetectionModel : yolov7x_original_with_NMS_IOU_Thrd_05_Conf_Thrd_04
    let visionModel : VNCoreMLModel

    /** The active scanner model. Only accessible while scanning is enabled. */
    @Published
    public private(set) var model: ScannerModel?

    /** Controls if the `ActiveARViewContainer` will render. */
    @Published
    public private(set) var renderingARView = false

    /** Controls if the `PassiveCameraViewContainer` will render. */
    @Published
    public private(set) var renderingPassiveView = true

    /** Indicates that the UI should show us as being in scan-mode */
    @Published
    public private(set) var scanEnabled = false

    /** Indicates that the torch (onboard-light) is engaged. */
    @Published
    public private(set) var torchEnabled = false

    /** Indicates that the ARView debug should render. */
    @Published
    public private(set) var debugEnabled = false

    /** Indicates that the scene-understanding mesh should render. */
    @Published
    public private(set) var meshEnabled = true
    
    @Published
    public private(set) var AnchorEnabled = true

    /** The user-facing message string. */
    @Published
    public private(set) var message = ""
    
    @Published
    public private(set) var defectname_yolo = "YOLO"

    /** If we even have access to the camera. `nil` if not yet checked. */
    public private(set) var cameraEnabled: Bool?
    
//    @Published
//    public private(set) var last_captured_image: CVPixelBuffer?
    
    @Published
    public var Captured_image: UIImage? = nil
    
    @Published
    public var DetectEnabled: Bool = false
    
    @Published
    public var BboxEnabled: Bool = false
    
    @Published
    public var SphereEnabled: Bool = false
    
    @Published
    public var frameCaptureEnabled: Bool = false
    
    @Published
    public var Recolized: Bool = true
    
    @Published
    public var screenRecordEnabled: Bool = false
    
    @Published
    public var Captured_image_id: Int = 1
    
    @Published
    public var statusLabel_text: String = ""
    
    @Published
    public var Mapping_status: String = ""
    
    @Published
    public var Tracking_status: String = ""
    
    
    @Published public var Last_defect_name: String = "NA"
    @Published public var Last_edge_1: String = "NA"
    @Published public var Last_edge_2: String = "NA"
    @Published public var Last_edge_3: String = "NA"
    @Published public var Last_edge_4: String = "NA"
    
    
    @Published
    public var Cam_Loc: String = ""
    
    @Published
    public var requests = [VNRequest]()
    
    @Published
    var Boundingbox_ind_x: Double = 300
    
    @Published
    var Boundingbox_ind_y: Double = 200
    
//    @Published
//    var Boundingboxs: [[Double]] = [[340,   256, 686, 170],
//                                    [425.5, 320, 515, 384],
//                                    [511.5, 384, 343, 256],
//                                    [597.5, 448, 172, 128]
//                                   ]
//
    @Published
    var allow_dist: Float = 0.2
    
    
    
    var date_formatter_path = DateFormatter()
    
    @Published
    public var save_folder: URL
    
    @Published
    public var save_folder_root: URL
    
    @Published
    public var save_name: String
    
    var reloc_map_url: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

    // * -> 1  * -> 2
    //
    // * -> 4  * -> 3
    
    @State
    var Distances: [Double] = [0.0,    // 1->2
                               0.0,    // 2->3
                               0.0,    // 3->4
                               0.0]   // 4->1

    /**
     * Stop the passive camera, construct a `ScannerModel` and start the active AR camera.
     */
    
    init(reloc_map: URL?){
        
        self.DetectionModel = {
            do {
                let configuration = MLModelConfiguration()
                return try yolov7x_original_with_NMS_IOU_Thrd_05_Conf_Thrd_04(configuration: configuration)
            } catch let error {
                fatalError(error.localizedDescription)
            }
        }()
        
        self.visionModel = try! VNCoreMLModel(for: DetectionModel.model)
        
        self.date_formatter_path.dateFormat = "MM-dd-yyyy HH-mm"
        self.save_folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.save_folder_root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("scans")
        self.save_name = "\(self.date_formatter_path.string(from: Date.now))"
        self.save_folder = self.save_folder.appendingPathComponent(save_name) //"\(self.date_formatter_path.string(from: Date.now))")
        
        guard let map = reloc_map else {return }
        self.reloc_map_url = map
        
        
        print("ScannerControlModel init() save_folder: \(self.save_folder)")
    }
    
    func startScan() {
        model = nil
        precondition(cameraEnabled == true)
        precondition(model == nil)
        precondition(renderingARView == false)

        self.message = ""
        
        self.renderingPassiveView = false
        self.model = ScannerModel(control: self)

        self.renderingARView = true
        self.scanEnabled = true
        
        do { try FileManager.default.createDirectory(at: self.save_folder, withIntermediateDirectories: true, attributes: [:])}
        catch {print(error)}
        
        let Vid_folder = self.save_folder.appendingPathComponent("Vid")
        
        do { try FileManager.default.createDirectory(at: Vid_folder, withIntermediateDirectories: true, attributes: [:])}
        catch {print(error)}
        
        

        /// now we wait for `model.onViewAppear` which will start the scan
    }

    /**
     * Simply stops rendering the ARView, triggering the `ActiveARViewContainer` to
     * disappear, subsequently calling `scanDisappearing`.
     *
     * Does  not save the scan.
     */

    func Change_defectname_yolo(to name: String) {
        self.defectname_yolo = name
    }
    
    func cancelScan() {
        if self.renderingARView {
            self.renderingARView = false
        }
        if self.scanEnabled {
            self.scanEnabled = false
        }
        
//        do {
////            let fileUrls = try FileManager.default.contentsOfDirectory(at:self.save_folder, includingPropertiesForKeys: nil)
////                // process files
////                print("#DEBUG check save_folder_is_empy \(fileUrls)")
////            if fileUrls.count == 0{
////                print("#DEBUG Delete empty folder afer scan")
////                try? FileManager.default.removeItem(at: self.save_folder)
////            }
//            
//            try? FileManager.default.removeItem(at: self.save_folder)
//            //Delete directly, no checking 
//            } catch {
//                print("Error while enumerating files \(self.save_folder.path): \(error.localizedDescription)")
//            }
    }

    /**
     * Handler for when the active scan view is being dismantled.
     *
     * Calls the model's `onViewDisappear`, stops rendering the scan,
     * and enables the passive camera.
     */
    
    func scanDisappearing() {
        self.model?.onViewDisappear()
        self.cancelScan() /// should've been called already but just make sure
        self.model = nil
        self.torchEnabled = false
        self.renderingPassiveView = true
        
        do {
            let fileUrls = try FileManager.default.contentsOfDirectory(at:self.save_folder, includingPropertiesForKeys: nil)
                // process files
                print("#DEBUG check save_folder_is_empy \(fileUrls)")
            if fileUrls.count == 0{
                print("#DEBUG Delete empty folder afer scan")
                try? FileManager.default.removeItem(at: self.save_folder)
            }
            
            } catch {
                print("Error while enumerating files \(self.save_folder.path): \(error.localizedDescription)")
            }
    }

    /**
     * Call `saveScan` on the model, updating `message` as appropriate,
     * and cancel scan (returning to passive) when done.
     */
    func saveScan(scanStore: ScanStore) {
        guard let model = self.model
        else { fatalError("Call to saveScan() when no model is set") }
        
        model.saveScan(
            scanStore: scanStore,
            message: { msg in self.message = msg },
            done: { _ in self.cancelScan() }
        )
        
//        var save_folder_is_empy: [String]? = try? FileManager.default.contentsOfDirectory(at: self.save_folder, includingPropertiesForKeys: nil)
        
        do {
            let fileUrls = try FileManager.default.contentsOfDirectory(at:self.save_folder, includingPropertiesForKeys: nil)
                // process files
                print("#DEBUG check save_folder_is_empy \(fileUrls)")
            if fileUrls.count == 0{
                print("#DEBUG Delete empty folder afer scan")
                try? FileManager.default.removeItem(at: self.save_folder)
            }
            
            } catch {
                print("Error while enumerating files \(self.save_folder.path): \(error.localizedDescription)")
            }
    }

    func toggleTorch(_ enable: Bool) {
        self.torchEnabled = enable
    }

    func toggleDebug(_ enable: Bool) {
        self.debugEnabled = enable
    }

    func toggleMesh(_ enable: Bool) {
        self.meshEnabled = enable
    }
    
    func toggleAnchor(_ enable: Bool) {
        self.AnchorEnabled = enable
    }
    

    func updateCameraAccess(hasAccess: Bool) {
        self.cameraEnabled = hasAccess
    }
    
    func setupDetector() {
        let modelURL = Bundle.main.url(forResource: "yolov7x-original_with_NMS_IOU_Thrd_05_Conf_Thrd_04", withExtension: "mlmodelc")
    
        do {
            let visionModel = try VNCoreMLModel(for: MLModel(contentsOf: modelURL!))
            let recognitions = VNCoreMLRequest(model: visionModel)
            self.requests = [recognitions]
        } catch let error {
            print(error)
        }
    }
    
    
    
}
