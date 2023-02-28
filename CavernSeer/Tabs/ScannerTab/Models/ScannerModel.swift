//
//  ScannerModel.swift
//  CavernSeer
//
//  Created by Samuel Grush on 6/28/20.
//  Copyright © 2020 Samuel K. Grush. All rights reserved.
//

import Foundation
import RealityKit /// ARView, SceneEvents
import ARKit /// other AR*, UIView, UIGestureRecognizer, NSLayoutConstraint
import Combine /// Cancellable
import SwiftUI
import ReplayKit


class ThresholdProvider: MLFeatureProvider {
    open var values = [
        "iouThreshold": MLFeatureValue(double: UserDefaults.standard.double(forKey: "iouThreshold")),
        "confidenceThreshold": MLFeatureValue(double: UserDefaults.standard.double(forKey: "confidenceThreshold"))
        ]

    var featureNames: Set<String> {
        return Set(values.keys)
    }

    func featureValue(for featureName: String) -> MLFeatureValue? {
        return values[featureName]
    }
}

//final class ScannerModel: UIViewController, UIGestureRecognizer, ARSessionDelegate, ObservableObject{
final class ScannerModel: UIViewController, ARSessionDelegate, ObservableObject, RPPreviewViewControllerDelegate{
    
    var numOfFrame = 0
    let Vid_folder: URL
    
    
    static let supportsScan = ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification)
    static let supportsTorch = isTorchSupported()
    
    weak var control: ScannerControlModel?
    private var thresholdProvider = ThresholdProvider()

    let clearingOptions: ARSession.RunOptions = [
        .resetSceneReconstruction,
        .removeExistingAnchors,
        .resetTracking,
//        .stopTrackedRaycasts
    ]

    #if !targetEnvironment(simulator)
    let showMeshOptions: ARView.DebugOptions = [
        .showSceneUnderstanding,
        .showWorldOrigin,
//        .showFeaturePoints,
//        .showAnchorOrigins
//        .showAnchorGeometry,
//        .showAnchorOrigins,
    ]
    #else
    let showMeshOptions: ARView.DebugOptions = [
        .showSceneUnderstanding,
        .showAnchorOrigins]
    #endif

    /// the layer containing the AR render of the scan; owned by the `ScannerContainerView`
//    weak var arView: ARView?
    weak var arView: ARView?
    /// the layer that can draw on top of the arView (e.g. for line drawing)
    weak var drawView: UIView?

    /// snapshot at the beginning of a scan
    var startSnapshot: SnapshotAnchor?
    /// the current state of survey scans
    var surveyStations: [SurveyStationEntity] = []
    
    var lineModel: [AnchorEntity] = []
    /// state manager for survey lines, currently the only Drawables in the scene
    var surveyLines: DrawableContainer?

    var savedAnchors = ARMeshAnchorSet()

    var Anchors_list: [AnchorEntity] = []
    
    
    var scanConfiguration: ARWorldTrackingConfiguration?

    private var tapRecognizer: UITapGestureRecognizer?
    private var cancelBag = Set<AnyCancellable>()
    
    var detectionLayer: CALayer! = nil
    var sceneView: ARSCNView! = nil
    var screenRect: CGRect! = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        guard ARWorldTrackingConfiguration.isSupported else {
            fatalError("""
                ARKit is not available on this device. For apps that require ARKit
                for core functionality, use the `arkit` key in the key in the
                `UIRequiredDeviceCapabilities` section of the Info.plist to prevent
                the app from installing. (If the app can't be installed, this error
                can't be triggered in a production scenario.)
                In apps where AR is an additive feature, use `isSupported` to
                determine whether to show UI for launching AR experiences.
            """) // For details, see https://developer.apple.com/documentation/arkit
        }

        arView!.session.delegate = self
//        sceneView.session.run(defaultConfiguration)

        UIApplication.shared.isIdleTimerDisabled = true
        
    }

    init(control: ScannerControlModel) {
//        super.init(target: nil, action: nil)
        self.Vid_folder = control.save_folder.appendingPathComponent("Vid")
        
        super.init(nibName: nil, bundle: nil)
        screenRect = UIScreen.main.bounds
        control.$meshEnabled.sink { [weak self] (mesh) in self?.showMesh(mesh) }
        .store(in: &cancelBag)

        control.$debugEnabled.sink { [weak self] (dbg) in self?.showDebug(dbg) }
        .store(in: &cancelBag)
        
        control.$AnchorEnabled.sink { [weak self] (anch) in self?.showAnchor(anch) }
        .store(in: &cancelBag)

        control.$torchEnabled
            .dropFirst() /// ignore first so we don't default-on the torch
            .sink { (on) in Self.toggleTorch(on: on) }
            .store(in: &cancelBag)
        
        
        
        self.control = control
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func onViewAppear(arView: ARView) {
        let surveyLines = DrawableContainer()
        let drawView = DrawOverlay(frame: arView.frame, toDraw: surveyLines)

        self.arView = arView
        self.drawView = drawView
        self.surveyLines = surveyLines
        self.savedAnchors.clear()

        setupARView(arView: arView)
        setupDrawView(drawView: drawView, arView: arView)
        arView.scene.subscribe(
            to: SceneEvents.Update.self
        ) {
            [weak self] in self?.updateScene(on: $0)
        }
        .store(in: &cancelBag)

        setupScanConfig()

        self.startScan()
        self.setupDetectionLayers()
//        self.setupSCNLayers()
        
    }

    func onViewDisappear() {
        NSLayoutConstraint.deactivate(self.getConstraints())

        self.stopScan()
        self.cleanupGestures()
        self.drawView?.removeFromSuperview()

//        #if !targetEnvironment(simulator)
//        self.arView?.session.delegate = nil
//        #endif
        
        arView!.session.delegate = self
        self.arView?.scene.anchors.removeAll()
        self.arView = nil
        self.drawView = nil

        self.scanConfiguration = nil
        
        self.startSnapshot = nil
        self.surveyStations = []
        self.surveyLines = nil

    }

    private func getConstraints() -> [NSLayoutConstraint] {
        guard
            let arView = self.arView,
            let drawView = self.drawView
        else { return [] }

        return [
            drawView.topAnchor.constraint(equalTo: arView.topAnchor),
            drawView.leadingAnchor.constraint(equalTo: arView.leadingAnchor),
            drawView.trailingAnchor.constraint(equalTo: arView.trailingAnchor),
            drawView.bottomAnchor.constraint(equalTo: arView.bottomAnchor)
        ]
    }


    private func showDebug(_ show: Bool) {
        if show {
            arView?.debugOptions.insert(.showStatistics)
        } else {
            arView?.debugOptions.remove(.showStatistics)
        }
    }

    private func showMesh(_ show: Bool) {
        if show {
            arView?.debugOptions.formUnion(showMeshOptions)
        } else {
            arView?.debugOptions.subtract(showMeshOptions)
        }
    }
    
    private func showAnchor(_ show: Bool) {
        if show {
            arView?.debugOptions.insert([.showAnchorOrigins, .showFeaturePoints])
        } else {
            arView?.debugOptions.remove([.showAnchorOrigins, .showFeaturePoints])
        }
    }

    /// stop the scan and export all data to a `ScanFile`
    func saveScan(
        scanStore: ScanStore,
        message: @escaping (_: String) -> Void,
        done: @escaping (_: Bool) -> Void
    ) {
        guard
            let arView = self.arView,
            let surveyLines = self.surveyLines
        else {
            done(false)
            return
        }

        message("Starting save...")
        pause()

        let startSnapshot = self.startSnapshot
        let stations = self.surveyStations
        let date = Date()

        let savedAnchors = self.savedAnchors.copyAndClear()

        #if !targetEnvironment(simulator)
        arView.session.getCurrentWorldMap { /* no self */ worldMap, error in

            message("Saving...")

            guard let map = worldMap
            else {
                message("WorldMap Error: \(error!.localizedDescription)")
                done(false)
                return
            }

            let endAnchor = SnapshotAnchor(
                capturing: arView.session,
                suffix: "end"
            )
            if endAnchor == nil {
                message("Failed to take snapshot")
            }

            let lines = surveyLines.drawables.compactMap {
                $0 as? SurveyLineEntity
            }

            let scanFile = ScanFile(
                map: map,
                meshAnchors: savedAnchors,
                startSnap: startSnapshot,
                endSnap: endAnchor,
                date: date,
                stations: stations,
                lines: lines,
                location: nil)

            do {
                _ = try scanStore.saveFile(file: scanFile, baseName: self.control!.save_name)
                message("Save successful!")
                scanStore.update() {
                    _ in done(true)
                }
            } catch {
                message("Error: \(error.localizedDescription)")
                done(false)
            }
            
            do {
                map.anchors.append(startSnapshot!)
                
                let data = try NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: true)
                try data.write(to: self.control!.save_folder.appendingPathComponent("\(self.control!.save_name)_map.arexperience") , options: [.atomic])
            } catch {
                fatalError("Can't save map: \(error.localizedDescription)")
            }
            
        }
        #else
        done(false)
        #endif
    }

    private func pause() {
        #if !targetEnvironment(simulator)
        arView?.session.pause()
        #endif
    }

    private func unpause() {
        #if !targetEnvironment(simulator)
        arView?.session.run(arView!.session.configuration!)
        #endif
    }

    /// Start a new scan with `scanConfiguration`
    private func startScan() {
        guard ScannerModel.supportsScan
        else {
            fatalError("""
                Scene reconstruction (for mesh generation) requires a device
                with a LiDAR Scanner, such as the fourth-generation iPad Pro.
            """)
        }
        guard
            let arView = self.arView,
            let scanConfiguration = self.scanConfiguration
        else { return }
        
        
        if self.control!.reloc_map_url != FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]{
            
            var mapDataFromFile: Data? {
                return try? Data(contentsOf: self.control!.reloc_map_url)
            }
            
            let worldMap: ARWorldMap = {
                guard let data = mapDataFromFile
                    else { fatalError("Map data should already be verified to exist before Load button is enabled.") }
                do {
                    guard let worldMap = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data)
                        else { fatalError("No ARWorldMap in archive.") }
                    return worldMap
                } catch {
                    fatalError("Can't unarchive ARWorldMap from file data: \(error)")
                }
            }()
            
            scanConfiguration.initialWorldMap = worldMap
            print("##Isaac_debug \(self.control!.reloc_map_url)")
            
            control!.Recolized = false
            
        }
        
        
        arView.environment.sceneUnderstanding.options = [ .collision ]
        arView.session.delegate = self
        arView.session.run(
            scanConfiguration,
            options: [self.clearingOptions, .resetTracking]
        )
        
        setupGestures(arView: arView)
    }

    /// transfer to passive-mode, clearing the current state
    func stopScan() {
        guard
            let arView = self.arView,
            let drawView = self.drawView,
            let surveyLines = self.surveyLines
        else { return }

        self.pause()

        arView.scene.anchors.removeAll()
        surveyStations.removeAll()
        surveyLines.drawables.removeAll()
        drawView.setNeedsDisplay()
    }
    
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        
    //Update AR status
        control!.Mapping_status = frame.worldMappingStatus.description
        control!.Tracking_status = frame.camera.trackingState.description
        control!.Cam_Loc = frame.camera.transform.toRoundPosition()
    
        let capturedImage = session.currentFrame!.capturedImage
        
        
    //Update Detection model
        self.control!.visionModel.featureProvider = self.thresholdProvider
        let handler = VNImageRequestHandler(cvPixelBuffer: capturedImage, orientation: .up)
        let VNRequest = VNCoreMLRequest(model: self.control!.visionModel, completionHandler: detectionDidComplete)
        
        
    //Detection!!!
        if self.control!.DetectEnabled{
            if self.numOfFrame%60 == 0{
                try? handler.perform([VNRequest])
                print("Vision requseted, \(Date.now)") //"\nNames: \(String(describing: self.control!.visionModel.featureProvider?.featureNames))")
            }
        }
        
        
    //Save frame
        if control!.frameCaptureEnabled{
            DispatchQueue.global().async{
                if self.numOfFrame%12 == 0{
                    let screen_capture = (UIImage(pixelBuffer: (session.currentFrame!.capturedImage)))!.scalePreservingAspectRatio(targetSize: CGSize(width: 400, height: 300))
                    let screen_capture_url_img = self.Vid_folder.appendingPathComponent("\(session.currentFrame!.timestamp).png")
                    
                    do { try screen_capture.pngData()!.write(to: screen_capture_url_img)}
                    catch { print(error.localizedDescription) }
                }
            }
        }

        
        numOfFrame += 1
        numOfFrame = numOfFrame%60
        
    } //Update ARStatus
    
    func detectionDidComplete(request: VNRequest, error: Error?) {
        print("###DEBUG Isaac Detected!!! \(Date.now)")
        DispatchQueue.main.async(execute: {
            if let results = request.results {
                self.thresholdProvider.values = [
                    "iouThreshold": MLFeatureValue(double: UserDefaults.standard.double(forKey: "iouThreshold")),
                    "confidenceThreshold": MLFeatureValue(double: UserDefaults.standard.double(forKey: "confidenceThreshold"))]
                
                self.control!.visionModel.featureProvider = self.thresholdProvider
                
                self.extractDetections(results)
            }
        })
    }
    
    func cleanBbox(){ detectionLayer.sublayers = nil }
    
    func extractDetections(_ results: [VNObservation]) {
        detectionLayer.sublayers = nil
        
        print("###DEBUG Results count \(results.count)")
        
        for observation in results where observation is VNRecognizedObjectObservation {
            guard let objectObservation = observation as? VNRecognizedObjectObservation else { continue }
            
            // Transformations
            let objectBounds = VNImageRectForNormalizedRect(objectObservation.boundingBox, Int(screenRect.size.width), Int(screenRect.size.height))
            
            
            
            let transformedBounds = CGRect(
                x: objectBounds.minX,
                y: screenRect.size.height - objectBounds.maxY,
                width: objectBounds.maxX - objectBounds.minX,
                height: objectBounds.maxY - objectBounds.minY)
            
            var Bbox_color = CGColor.init(red: 1.0, green: 1.0, blue: 0.0, alpha: 1.0)
            
            var properArea = true
            
            if objectBounds.width * objectBounds.height <= 6000 {
                Bbox_color = CGColor.init(red: 0.8, green: 0.8, blue: 0.8, alpha: 0.3)
                properArea = false }
            
            let (boxLayer, boxLabelLayer) = self.drawBoundingBox(transformedBounds,
                                                                 with: objectObservation.labels[0].identifier,
                                                                 with_color: Bbox_color)
            
            detectionLayer.addSublayer(boxLayer)
            detectionLayer.addSublayer(boxLabelLayer)
            
            let name = objectObservation.labels[0].identifier
            
            if control!.SphereEnabled && properArea{
                if (control!.Mapping_status == "Mapped") && (control!.Tracking_status == "Normal") {
                    self.handleTap_auto_mark_4_pts(
                        [CGPoint(x: objectBounds.minX,  y: screenRect.size.height - objectBounds.maxY),  //Top left
                         CGPoint(x: objectBounds.maxX,  y: screenRect.size.height - objectBounds.maxY),  //Top right
                         CGPoint(x: objectBounds.maxX , y: screenRect.size.height - objectBounds.minY),  //Bottom right
                         CGPoint(x: objectBounds.minX,  y: screenRect.size.height - objectBounds.minY)   //Bottom left
                        ], defect_name: name)
                }
            }
            print("Added sublayer")
        }
        
        
    }
    
    func drawBoundingBox(_ bounds: CGRect,
                         with name: String,
                         with_color color: CGColor = CGColor.init(red: 1.0, green: 1.0, blue: 0.0, alpha: 1.0))
    -> (CALayer, CATextLayer) {
        
        let boxLayer = CALayer()
        boxLayer.frame = bounds
        boxLayer.borderWidth = 3.0
        boxLayer.borderColor = color
        boxLayer.cornerRadius = 4
        
        let boxLabelLayer = CATextLayer()
        boxLabelLayer.frame = bounds
        boxLabelLayer.string = name
        boxLabelLayer.fontSize = 16
        
        return (boxLayer, boxLabelLayer)
    }
    
    func setupDetectionLayers() {
        detectionLayer = CALayer()
        detectionLayer.frame = CGRect(x: 0, y: 0, width: screenRect.size.width, height: screenRect.size.height)
        self.arView!.layer.addSublayer(detectionLayer)
    }
    
    var BBox_anchor = try! BboxRC.loadBbox()
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        
        savedAnchors.update(anchors.compactMap { $0 as? ARMeshAnchor })
        
        if self.startSnapshot == nil { self.startSnapshot = SnapshotAnchor( capturing: session, suffix: "start" ) }
        
        var anchors_list: [ARAnchor] = []
        
        if !(control!.Recolized){
            anchors.forEach { anchor in
                guard let anchor_name = anchor.name else { return }
                if anchor_name.contains("reloc"){ anchors_list.append(anchor) }
            }

        anchors_list.sort { $0.name! < $1.name! }
            
//            var BBox_side: Entity! = BBox_anchor.findEntity(named: "bbox_side")
//            var BBox_side_model: ModelEntity! = BBox_side.children.first as? ModelEntity


            for i in stride(from: 0, through: anchors_list.count-1, by: 6) { //6 anchor(pts) per defect

                let mesh = MeshResource.generateSphere(radius: 0.01)
                
                let materials = [SimpleMaterial(color: .red, isMetallic: false)]
                let modelEntity = ModelEntity(mesh: mesh, materials: materials)
                
                guard let arView = self.arView,
                      let surveyLines = self.surveyLines else { return }

                let temp_station = Array(self.surveyStations)
                let MarkerID: Int = Int(temp_station.count) / 6 + 1
                let defect_name = String(anchors_list[i].name!.split(separator: "_")[1])
                

                let cam_ancr = anchors_list[i+0]
                let cen_ancr = anchors_list[i+1]
                let pt1_ancr = anchors_list[i+2]
                let pt2_ancr = anchors_list[i+3]
                let pt3_ancr = anchors_list[i+4]
                let pt4_ancr = anchors_list[i+5]
                
                print("cam_ancr.transform: ", cam_ancr.transform)
                print("cen_ancr.transform: ", cen_ancr.transform)
                print("pt1_ancr.transform: ", pt1_ancr.transform)
                print("pt2_ancr.transform: ", pt2_ancr.transform)
                print("pt3_ancr.transform: ", pt3_ancr.transform)
                print("pt4_ancr.transform: ", pt4_ancr.transform)
                
                let station_pt1 = SurveyStationEntity(worldTransform: pt1_ancr.transform, bbox_loc: "\(MarkerID)_\(defect_name)_pt1", RayQuery: nil, ARscene: arView.scene)
                let station_pt2 = SurveyStationEntity(worldTransform: pt2_ancr.transform, bbox_loc: "\(MarkerID)_\(defect_name)_pt2", RayQuery: nil, ARscene: arView.scene)
                let station_pt3 = SurveyStationEntity(worldTransform: pt3_ancr.transform, bbox_loc: "\(MarkerID)_\(defect_name)_pt3", RayQuery: nil, ARscene: arView.scene)
                let station_pt4 = SurveyStationEntity(worldTransform: pt4_ancr.transform, bbox_loc: "\(MarkerID)_\(defect_name)_pt4", RayQuery: nil, ARscene: arView.scene)
                let station_center = SurveyStationEntity(worldTransform: cen_ancr.transform, bbox_loc: "\(MarkerID)_\(defect_name)_Center", RayQuery: nil, ARscene: arView.scene)
                let station_camera = SurveyStationEntity(worldTransform: cam_ancr.transform, bbox_loc: "\(MarkerID)_\(defect_name)_Camera", RayQuery: nil, ARscene: arView.scene)
                
                let cam_ancr_entity = AnchorEntity(world: cam_ancr.transform)
                let cen_ancr_entity = AnchorEntity(world: cen_ancr.transform)
                let pt1_ancr_entity = AnchorEntity(world: pt1_ancr.transform)
                let pt2_ancr_entity = AnchorEntity(world: pt2_ancr.transform)
                let pt3_ancr_entity = AnchorEntity(world: pt3_ancr.transform)
                let pt4_ancr_entity = AnchorEntity(world: pt4_ancr.transform)
                
                
                station_center.removeFromParent(preservingWorldTransform: false)
                station_camera.removeFromParent(preservingWorldTransform: false)
                station_pt1.removeFromParent(preservingWorldTransform: false)
                station_pt2.removeFromParent(preservingWorldTransform: false)
                station_pt3.removeFromParent(preservingWorldTransform: false)
                station_pt4.removeFromParent(preservingWorldTransform: false)
                
                station_center.removeFromParent(preservingWorldTransform: false)
                station_camera.removeFromParent(preservingWorldTransform: false)
                station_pt1.removeFromParent(preservingWorldTransform: false)
                station_pt2.removeFromParent(preservingWorldTransform: false)
                station_pt3.removeFromParent(preservingWorldTransform: false)
                station_pt4.removeFromParent(preservingWorldTransform: false)
                
                station_center.removeFromParent(preservingWorldTransform: false)
                station_camera.removeFromParent(preservingWorldTransform: false)
                station_pt1.removeFromParent(preservingWorldTransform: false)
                station_pt2.removeFromParent(preservingWorldTransform: false)
                station_pt3.removeFromParent(preservingWorldTransform: false)
                station_pt4.removeFromParent(preservingWorldTransform: false)
                
                cam_ancr_entity.addChild(station_camera)
                cen_ancr_entity.addChild(station_center)
                pt1_ancr_entity.addChild(station_pt1)
                pt2_ancr_entity.addChild(station_pt2)
                pt3_ancr_entity.addChild(station_pt3)
                pt4_ancr_entity.addChild(station_pt4)
                
                
                arView.scene.addAnchor(pt1_ancr_entity)
                arView.scene.addAnchor(pt2_ancr_entity)
                arView.scene.addAnchor(pt3_ancr_entity)
                arView.scene.addAnchor(pt4_ancr_entity)
                arView.scene.addAnchor(cam_ancr_entity)
                arView.scene.addAnchor(cen_ancr_entity)

                self.surveyStations.append(station_pt1)

        //        arView.scene.addAnchor(station_pt1)
//                camera.addChild(station_pt1)
                arView.installGestures(for: station_pt1)


                var lastEntity = self.surveyStations.last
                self.surveyStations.append(station_pt2)
        //        arView.scene.addAnchor(station_pt2)
//                camera.addChild(station_pt2)
                arView.installGestures(for: station_pt2)
                //Uncomment following to draw line between stations
                let line_pt1_to_pt2 = lastEntity!.lineTo(station_pt2, linked_bbox_loc: "\(MarkerID)_\(defect_name)_pt1_to_pt2")
                print("DEBUG line_pt1_to_pt2 \(line_pt1_to_pt2.linked_bbox_loc)")
                surveyLines.drawables.append(line_pt1_to_pt2)
                line_pt1_to_pt2.updateProjections(arView: arView) //@Isaac.debug, if comment below, line wont show on screen but still save and show in model viewer



                lastEntity = self.surveyStations.last
                self.surveyStations.append(station_pt3)
        //        arView.scene.addAnchor(station_pt3)
//                camera.addChild(station_pt3)
                arView.installGestures(for: station_pt3)
                //Uncomment following to draw line between stations
                let line_pt2_to_pt3 = lastEntity!.lineTo(station_pt3, linked_bbox_loc: "\(MarkerID)_\(defect_name)_pt2_to_pt3")
                print("DEBUG line_pt2_to_pt3 \(line_pt2_to_pt3.linked_bbox_loc)")
                surveyLines.drawables.append(line_pt2_to_pt3)
                line_pt2_to_pt3.updateProjections(arView: arView) //@Isaac.debug, if comment below, line wont show on screen but still save and show in model viewer



                lastEntity = self.surveyStations.last
                self.surveyStations.append(station_pt4)
        //        arView.scene.addAnchor(station_pt4)
//                camera.addChild(station_pt4)
                arView.installGestures(for: station_pt4)
                //Uncomment following to draw line between stations
                let line_pt3_to_pt4 = lastEntity!.lineTo(station_pt4, linked_bbox_loc: "\(MarkerID)_\(defect_name)_pt3_to_pt4")
                print("DEBUG line_pt3_to_pt4 \(line_pt3_to_pt4.linked_bbox_loc)")
                surveyLines.drawables.append(line_pt3_to_pt4)
                line_pt3_to_pt4.updateProjections(arView: arView) //@Isaac.debug, if comment below, line wont show on screen but still save and show in model viewer


                lastEntity = self.surveyStations.last
                let line_pt4_to_pt1 = lastEntity!.lineTo(station_pt1, linked_bbox_loc: "\(MarkerID)_\(defect_name)_pt4_to_pt1")
                print("DEBUG line_pt4_to_pt1 \(line_pt4_to_pt1.linked_bbox_loc)")
                surveyLines.drawables.append(line_pt4_to_pt1)
                line_pt4_to_pt1.updateProjections(arView: arView) //@Isaac.debug, if comment below, line wont show on screen but still save and show in model viewer



                self.surveyStations.append(station_center)
        //        arView.scene.addAnchor(station_center)
//                camera.addChild(station_center)
                arView.installGestures(for: station_center)

                lastEntity = self.surveyStations.last
                self.surveyStations.append(station_camera)
        //        arView.scene.addAnchor(station_camera)
//                camera.addChild(station_camera)
                arView.installGestures(for: station_camera)
                //Uncomment following to draw line between stations
                let line_center_to_cam = lastEntity!.lineTo(station_camera, linked_bbox_loc: "\(MarkerID)_\(defect_name)_center_to_cam")
                print("DEBUG line_center_to_cam \(line_center_to_cam.linked_bbox_loc)")
                surveyLines.drawables.append(line_center_to_cam)
                line_pt1_to_pt2.updateProjections(arView: arView)
                
            }
        }
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
//        print("DEBUG Update ARanchors")
//        anchors.forEach { anchor in
//            guard let name = anchor.name else {return}
//            print("DEBUG print anchor name \(name)")
//        }
        savedAnchors.update(anchors.compactMap { $0 as? ARMeshAnchor })
    }

    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        print("DEBUG remove ARanchors")
        savedAnchors.remove(anchors.compactMap { $0 as? ARMeshAnchor })
        
//        anchors.forEach { anchor in
//            guard let name = anchor.name else {return}
//            print("DEBUG print anchor name \(name)")
//        }
        
//        DispatchQueue.global().async {
//            self.surveyStations.forEach { station in
//                guard let query = station.RayQuery else{ return }
//                session.trackedRaycast(query) { (results) in
//                    guard let result = results.first else { return }
//                    station.transform.matrix = result.worldTransform //.transform.matrix = worldTransform
//                }
//            }
//        }
    }

    
    private func setupScanConfig() {
        scanConfiguration = ARWorldTrackingConfiguration()
        scanConfiguration?.planeDetection = [.vertical, .horizontal]
        scanConfiguration!.sceneReconstruction = .meshWithClassification
        scanConfiguration!.environmentTexturing = .none
        //👆If automatic, manual -> Anchor will reflect the surrounding environment. But consume too much, then crash
        scanConfiguration!.worldAlignment = .gravityAndHeading
        scanConfiguration!.frameSemantics = .sceneDepth
    }

    private func setupARView(arView: ARView) {
        #if !targetEnvironment(simulator)
        arView.automaticallyConfigureSession = false
        arView.debugOptions = .showSceneUnderstanding
        arView.renderOptions = [
            .disablePersonOcclusion,
            .disableMotionBlur,
            .disableDepthOfField,
            .disableHDR,
            .disableCameraGrain,
            .disableFaceMesh,
            .disableAREnvironmentLighting,
        ]
        #endif
    }

    private func setupDrawView(drawView: DrawOverlay, arView: ARView) {
        drawView.translatesAutoresizingMaskIntoConstraints = false
        arView.addSubview(drawView)
        drawView.backgroundColor = UIColor.clear
        NSLayoutConstraint.activate(self.getConstraints())
    }

    private func updateScene(on event: SceneEvents.Update) {
        
//        print("DEBUG updateScene \(Date.now)")
        
        guard
            let arView = self.arView,
            let drawView = self.drawView,
            let surveyLines = self.surveyLines
            
        else { return }
        
        //@Isaac.debug If delete below, still show line on 2d screen and not moving
        
        if !surveyLines.drawables.isEmpty{
            surveyLines.drawables.forEach {
                line in
                line.prepareToDraw(arView: arView)
            }
        }
        drawView.setNeedsDisplay()
    }

    private static func toggleTorch(on: Bool) {
        guard
            supportsTorch,
            let device = AVCaptureDevice.default(for: .video)
        else { return }

        do {
            let currentlyOn = device.isTorchActive
            let max = AVCaptureDevice.maxAvailableTorchLevel

            if currentlyOn != on {
                try device.lockForConfiguration()
                if on {
                    try device.setTorchModeOn(level: max)
                } else {
                    device.torchMode = .off
                }
                device.unlockForConfiguration()
            } else {

            }

        } catch {
            fatalError("Failed to toggle torch, \(error.localizedDescription)")
        }
    }

    private static func isTorchSupported() -> Bool {
        guard let device = AVCaptureDevice.default(for: .video)
        else { return false }

        return device.hasTorch && device.isTorchModeSupported(.on)
    }
    
    
    
// +gestures
//extension ScannerModel {
    func setupGestures(arView: ARView) {
        let tapRecognizer = UITapGestureRecognizer(
            target: self,
            action: #selector(handleTap(_:))
        )
        arView.addGestureRecognizer(tapRecognizer)
        self.tapRecognizer = tapRecognizer
    }

    func cleanupGestures() {
        if
            let arView = self.arView,
            let tapRecog = self.tapRecognizer
        {
            arView.removeGestureRecognizer(tapRecog)
        }
        self.tapRecognizer = nil
    }

    
    @objc func handleTap(_ sender: UITapGestureRecognizer) {
        // Disable placing objects when the session is still relocalizing
        // Hit test to find a place for a virtual object.
        
        print(sender.location(in: arView))
        guard let hitTestResult = arView!
            .hitTest(sender.location(in: arView), types: [.existingPlaneUsingGeometry, .estimatedHorizontalPlane])
            .first
            else { return }
        
        // Remove exisitng anchor and add new anchor
//        if let existingAnchor = virtualObjectAnchor {
//            sceneView.session.remove(anchor: existingAnchor)
//        }
//        virtualObjectAnchor = ARAnchor(name: virtualObjectAnchorName, transform: hitTestResult.worldTransform)
//        arView!.session.add(anchor: virtualObjectAnchor!.copy() as! ARAnchor)
    }
    
    @objc func handleTap_auto(_ bbox: CGPoint, cap_img last_captured_image: CVPixelBuffer?) {
        
        guard let arView = self.arView else { return }
//        let tapLoc = sender.location(in: arView)
//        let camLoc = arView.cameraTransform.translation
        
        let hitResult: [CollisionCastHit] = arView.hitTest(bbox)
        if let hitFirst = hitResult.first {
            print("tappedOnEntity")
            tappedOnEntity(hitFirst: hitFirst)
            return
        } else {
            print("tappedOnNonentity")
//            print("Start")
//            print("\(last_captured_image!)")
//            print("End")
            tappedOnNonentity(tapLoc: bbox) //, cap_img: last_captured_image)
        }
        
    }
    
    func CG_mid(_ pt1: CGPoint, _ pt2: CGPoint) -> CGPoint{
        return CGPoint(x: (pt1.x + pt2.x)/2 , y: (pt1.y + pt2.y)/2 )
    }
    
    
    //### Detection complete handler
    @objc func handleTap_auto_mark_4_pts(_ bboxs: [CGPoint], defect_name : String) {
//        print("handleTap_auto_mark_4_pts")
        
//        DispatchQueue.main.async{
        
        guard let arView = self.arView else {return }
        // Reversed exsiting station list, -> Distance constains check fasters
        let temp_station = Array(self.surveyStations.reversed())

        var output_txt = ""
        
// 1. Define 4 pts of bbox, center == 5 pts in total
        
        //Top left || Top right || Bottom right || Bottom left
        //  ||          ||            ||               ||
        //  pt1,        pt2,          pt3,             pt4
        
            bboxs.forEach { box in
                if box.x < 0 || box.y < 0 {
                    print("#DEBUG negative bbox")
                    return
                }
            }
        
        let (pt1, pt2, pt3, pt4) = (bboxs[0], bboxs[1], bboxs[2], bboxs[3])
        let center: CGPoint = CGPoint(x: (pt1.x + pt2.x) / 2 , y: (pt1.y + pt4.y) / 2)
        
        
// 2. Check distance constains

        guard
             
            let raycast_pt1    = arView.raycast( from: pt1, allowing: .estimatedPlane , alignment: .any ).first,
            let raycast_pt2    = arView.raycast( from: pt2, allowing: .estimatedPlane, alignment: .any ).first,
            let raycast_pt3    = arView.raycast( from: pt3, allowing: .estimatedPlane, alignment: .any ).first,
            let raycast_pt4    = arView.raycast( from: pt4, allowing: .estimatedPlane, alignment: .any ).first,
            let raycast_center = arView.raycast( from: center, allowing: .estimatedPlane, alignment: .any).first,
            
            let raycast_mid_1_2    = arView.raycast(from: CG_mid(pt1, pt2), allowing: .estimatedPlane , alignment: .any ).first,
            let raycast_mid_2_3    = arView.raycast(from: CG_mid(pt2, pt3), allowing: .estimatedPlane, alignment: .any ).first,
            let raycast_mid_3_4    = arView.raycast(from: CG_mid(pt3, pt4), allowing: .estimatedPlane, alignment: .any ).first,
            let raycast_mid_4_1    = arView.raycast(from: CG_mid(pt4, pt1), allowing: .estimatedPlane, alignment: .any ).first
                
        else {
            print("#DEBUG 4 pts raycast not sucessed")
            return
        }
            
        print("#DEBUG 4 pts raycast sucessed")
    //2.1 Check camera to center <= 2 m
        let loc_3d_center = raycast_center.worldTransform.toPosition()
        let loc_3d_pt1 = raycast_pt1.worldTransform.toPosition()
        let loc_3d_pt2 = raycast_pt2.worldTransform.toPosition()
        let loc_3d_pt3 = raycast_pt3.worldTransform.toPosition()
        let loc_3d_pt4 = raycast_pt4.worldTransform.toPosition()
        let loc_3d_camera = arView.cameraTransform.matrix.toPosition()
        
        let dis_list: [Float] = [distance(loc_3d_camera, loc_3d_pt1),
                                 distance(loc_3d_camera, loc_3d_pt2),
                                 distance(loc_3d_camera, loc_3d_pt3),
                                 distance(loc_3d_camera, loc_3d_pt4),
                                ]
        
        if (Float(dis_list.max()!) - Float(dis_list.min()!)) >= Float(0.5) { return}
            
        if distance(loc_3d_center, loc_3d_camera) > 2.0 {
            print("#DEBUG Camera to center distance > 2.0 m --> return")
            return
        }
        
        print("#DEBUG Camera to center distance < 2.0 m --> OK!")
        
    //2.2 Check center to other stations' center distance >= 50 cm
        for station in temp_station where station.bbox_loc.contains("Center") {
            print("DEBUG: Check station centers' dist, \(station), \(station.bbox_loc)")
            let dist = distance(loc_3d_center, station.position) //Real world Dist between center and others' center
            if dist < control!.allow_dist {
                print("#DEBUG Center to center distance <= 0.5 cm --> return")
                return
            }
        }
        print("#DEBUG Center to center distance > 0.5 cm --> OK!")
        
        
// 3. Mark 6 pts and add lines
        
        guard let surveyLines = self.surveyLines else { return}
        
        
        let lineHeight: CGFloat = 0.02
        let font = MeshResource.Font.systemFont(ofSize: lineHeight)
        let textMaterial = SimpleMaterial(color: .black, isMetallic: true)
        
        
        let textMesh_1_2 = MeshResource.generateText(String(format: "%.2fm", distance(loc_3d_pt1, loc_3d_pt2)), extrusionDepth: Float(lineHeight * 0.1), font: font)
        let textMesh_2_3 = MeshResource.generateText(String(format: "%.2fm", distance(loc_3d_pt2, loc_3d_pt3)), extrusionDepth: Float(lineHeight * 0.1), font: font)
        let textMesh_3_4 = MeshResource.generateText(String(format: "%.2fm", distance(loc_3d_pt3, loc_3d_pt4)), extrusionDepth: Float(lineHeight * 0.1), font: font)
        let textMesh_4_1 = MeshResource.generateText(String(format: "%.2fm", distance(loc_3d_pt4, loc_3d_pt1)), extrusionDepth: Float(lineHeight * 0.1), font: font)
        let textMesh_center = MeshResource.generateText("\(Int(temp_station.count) / 6 + 1): \(defect_name)", extrusionDepth: Float(lineHeight * 0.1), font: font)
        
        let model_1_2 = ModelEntity(mesh: textMesh_1_2, materials: [textMaterial])
        let model_2_3 = ModelEntity(mesh: textMesh_2_3, materials: [textMaterial])
        let model_3_4 = ModelEntity(mesh: textMesh_3_4, materials: [textMaterial])
        let model_4_1 = ModelEntity(mesh: textMesh_4_1, materials: [textMaterial])
        let model_center = ModelEntity(mesh: textMesh_center, materials: [textMaterial])
        
        model_1_2.position.x -= model_1_2.visualBounds(relativeTo: nil).extents.x / 2
//        model_2_3.position.x -= model_2_3.visualBounds(relativeTo: nil).extents.x / 2
        model_3_4.position.x -= model_3_4.visualBounds(relativeTo: nil).extents.x / 2
        model_4_1.position.x -= model_4_1.visualBounds(relativeTo: nil).extents.x
        model_center.position.x -= model_center.visualBounds(relativeTo: nil).extents.x / 2
        
        let rayDirection_1_2 = normalize(raycast_mid_1_2.worldTransform.toPosition() - self.arView!.cameraTransform.translation)
        let rayDirection_2_3 = normalize(raycast_mid_2_3.worldTransform.toPosition() - self.arView!.cameraTransform.translation)
        let rayDirection_3_4 = normalize(raycast_mid_3_4.worldTransform.toPosition() - self.arView!.cameraTransform.translation)
        let rayDirection_4_1 = normalize(raycast_mid_4_1.worldTransform.toPosition() - self.arView!.cameraTransform.translation)
        let rayDirection_center = normalize(raycast_center.worldTransform.toPosition() - self.arView!.cameraTransform.translation)
        
        
        let textPositionInWorldCoordinates_1_2 = raycast_mid_1_2.worldTransform.toPosition() - (rayDirection_1_2 * 0.05)
        let textPositionInWorldCoordinates_2_3 = raycast_mid_2_3.worldTransform.toPosition() - (rayDirection_2_3 * 0.05)
        let textPositionInWorldCoordinates_3_4 = raycast_mid_3_4.worldTransform.toPosition() - (rayDirection_3_4 * 0.05)
        let textPositionInWorldCoordinates_4_1 = raycast_mid_4_1.worldTransform.toPosition() - (rayDirection_4_1 * 0.05)
        let textPositionInWorldCoordinates_center = raycast_center.worldTransform.toPosition() - (rayDirection_center * 0.05)
    
        var resultWithCameraOrientation_1_2 = self.arView!.cameraTransform
        var resultWithCameraOrientation_2_3 = self.arView!.cameraTransform
        var resultWithCameraOrientation_3_4 = self.arView!.cameraTransform
        var resultWithCameraOrientation_4_1 = self.arView!.cameraTransform
        var resultWithCameraOrientation_center = self.arView!.cameraTransform
        
        resultWithCameraOrientation_1_2.translation = textPositionInWorldCoordinates_1_2
        resultWithCameraOrientation_2_3.translation = textPositionInWorldCoordinates_2_3
        resultWithCameraOrientation_3_4.translation = textPositionInWorldCoordinates_3_4
        resultWithCameraOrientation_4_1.translation = textPositionInWorldCoordinates_4_1
        resultWithCameraOrientation_center.translation = textPositionInWorldCoordinates_center
        
        let Anchor_1_2 = AnchorEntity(world: resultWithCameraOrientation_1_2.matrix)
        let Anchor_2_3 = AnchorEntity(world: resultWithCameraOrientation_2_3.matrix)
        let Anchor_3_4 = AnchorEntity(world: resultWithCameraOrientation_3_4.matrix)
        let Anchor_4_1 = AnchorEntity(world: resultWithCameraOrientation_4_1.matrix)
        let Anchor_center = AnchorEntity(world: resultWithCameraOrientation_center.matrix)

        Anchor_1_2.addChild(model_1_2)
        Anchor_2_3.addChild(model_2_3)
        Anchor_3_4.addChild(model_3_4)
        Anchor_4_1.addChild(model_4_1)
        Anchor_center.addChild(model_center)
        
        self.lineModel.append(Anchor_1_2)
        self.lineModel.append(Anchor_2_3)
        self.lineModel.append(Anchor_3_4)
        self.lineModel.append(Anchor_4_1)
        
        arView.scene.addAnchor(Anchor_1_2)
        arView.scene.addAnchor(Anchor_2_3)
        arView.scene.addAnchor(Anchor_3_4)
        arView.scene.addAnchor(Anchor_4_1)
        
        
        let MarkerID: Int = Int(temp_station.count) / 6 + 1
        
        let station_pt1 = SurveyStationEntity(worldTransform: raycast_pt1.worldTransform, bbox_loc: "\(MarkerID)_\(defect_name)_pt1", RayQuery: nil, station_defect_type: defect_name, ARscene: arView.scene)
        let station_pt2 = SurveyStationEntity(worldTransform: raycast_pt2.worldTransform, bbox_loc: "\(MarkerID)_\(defect_name)_pt2", RayQuery: nil, station_defect_type: defect_name, ARscene: arView.scene)
        let station_pt3 = SurveyStationEntity(worldTransform: raycast_pt3.worldTransform, bbox_loc: "\(MarkerID)_\(defect_name)_pt3", RayQuery: nil, station_defect_type: defect_name, ARscene: arView.scene)
        let station_pt4 = SurveyStationEntity(worldTransform: raycast_pt4.worldTransform, bbox_loc: "\(MarkerID)_\(defect_name)_pt4", RayQuery: nil, station_defect_type: defect_name, ARscene: arView.scene)
        let station_center = SurveyStationEntity(worldTransform: raycast_center.worldTransform, bbox_loc: "\(MarkerID)_\(defect_name)_Center", RayQuery: nil, station_defect_type: defect_name, ARscene: arView.scene)
        let station_camera = SurveyStationEntity(worldTransform: arView.cameraTransform.matrix, bbox_loc: "\(MarkerID)_\(defect_name)_Camera", RayQuery: nil, station_defect_type: defect_name, ARscene: arView.scene)
        
        
        let station_pt1_Anchor    = ARAnchor( name: "\(MarkerID)_\(defect_name)_pt1_anchor_for_reloc",    transform: raycast_pt1.worldTransform)
        let station_pt2_Anchor    = ARAnchor( name: "\(MarkerID)_\(defect_name)_pt2_anchor_for_reloc",    transform: raycast_pt2.worldTransform)
        let station_pt3_Anchor    = ARAnchor( name: "\(MarkerID)_\(defect_name)_pt3_anchor_for_reloc",    transform: raycast_pt3.worldTransform)
        let station_pt4_Anchor    = ARAnchor( name: "\(MarkerID)_\(defect_name)_pt4_anchor_for_reloc",    transform: raycast_pt4.worldTransform)
        let station_center_Anchor = ARAnchor( name: "\(MarkerID)_\(defect_name)_Center_anchor_for_reloc", transform: raycast_center.worldTransform)
        let station_camera_Anchor = ARAnchor( name: "\(MarkerID)_\(defect_name)_Camera_anchor_for_reloc", transform: arView.cameraTransform.matrix)
        
        
        
        
        arView.session.add(anchor: station_pt1_Anchor)
        arView.session.add(anchor: station_pt2_Anchor)
        arView.session.add(anchor: station_pt3_Anchor)
        arView.session.add(anchor: station_pt4_Anchor)
        arView.session.add(anchor: station_center_Anchor)
        arView.session.add(anchor: station_camera_Anchor)
        

        let camera = AnchorEntity(.world(transform: raycast_center.worldTransform))
//        let camera = AnchorEntity(raycast_center)
//        let camera = AnchorEntity(raycastResult: raycast_center)
//        let camera = AnchorEntity(.plane(.any, classification: .any, minimumBounds: .one))
        
        
        arView.scene.addAnchor(camera)
        
        camera.addChild(Anchor_1_2)
        camera.addChild(Anchor_2_3)
        camera.addChild(Anchor_3_4)
        camera.addChild(Anchor_4_1)
        camera.addChild(Anchor_center)
        
        Anchors_list.append(camera)

        self.surveyStations.append(station_pt1)
        
        camera.addChild(station_pt1)
        arView.installGestures(for: station_pt1)
        
        
        var lastEntity = self.surveyStations.last
        self.surveyStations.append(station_pt2)
        camera.addChild(station_pt2)
        arView.installGestures(for: station_pt2)
        let line_pt1_to_pt2 = lastEntity!.lineTo(station_pt2, linked_bbox_loc: "\(MarkerID)_\(defect_name)_pt1_to_pt2")
        print("DEBUG line_pt1_to_pt2 \(line_pt1_to_pt2.linked_bbox_loc)")
        surveyLines.drawables.append(line_pt1_to_pt2)
        line_pt1_to_pt2.updateProjections(arView: arView) //@Isaac.debug, if comment below, line wont show on screen but still save and show in model viewer
        
            
            
        lastEntity = self.surveyStations.last
        self.surveyStations.append(station_pt3)
        camera.addChild(station_pt3)
        arView.installGestures(for: station_pt3)
        let line_pt2_to_pt3 = lastEntity!.lineTo(station_pt3, linked_bbox_loc: "\(MarkerID)_\(defect_name)_pt2_to_pt3")
        print("DEBUG line_pt2_to_pt3 \(line_pt2_to_pt3.linked_bbox_loc)")
        surveyLines.drawables.append(line_pt2_to_pt3)
        line_pt2_to_pt3.updateProjections(arView: arView) //@Isaac.debug, if comment below, line wont show on screen but still save and show in model viewer

            
            
        lastEntity = self.surveyStations.last
        self.surveyStations.append(station_pt4)
        camera.addChild(station_pt4)
        arView.installGestures(for: station_pt4)
        let line_pt3_to_pt4 = lastEntity!.lineTo(station_pt4, linked_bbox_loc: "\(MarkerID)_\(defect_name)_pt3_to_pt4")
        print("DEBUG line_pt3_to_pt4 \(line_pt3_to_pt4.linked_bbox_loc)")
        surveyLines.drawables.append(line_pt3_to_pt4)
        line_pt3_to_pt4.updateProjections(arView: arView) //@Isaac.debug, if comment below, line wont show on screen but still save and show in model viewer

        
        lastEntity = self.surveyStations.last
        let line_pt4_to_pt1 = lastEntity!.lineTo(station_pt1, linked_bbox_loc: "\(MarkerID)_\(defect_name)_pt4_to_pt1")
        print("DEBUG line_pt4_to_pt1 \(line_pt4_to_pt1.linked_bbox_loc)")
        surveyLines.drawables.append(line_pt4_to_pt1)
        line_pt4_to_pt1.updateProjections(arView: arView) //@Isaac.debug, if comment below, line wont show on screen but still save and show in model viewer
        
        
        self.surveyStations.append(station_center)
        camera.addChild(station_center)
        arView.installGestures(for: station_center)

        lastEntity = self.surveyStations.last
        self.surveyStations.append(station_camera)
        camera.addChild(station_camera)
        arView.installGestures(for: station_camera)
        let line_center_to_cam = lastEntity!.lineTo(station_camera, linked_bbox_loc: "\(MarkerID)_\(defect_name)_center_to_cam")
        print("DEBUG line_center_to_cam \(line_center_to_cam.linked_bbox_loc)")
        surveyLines.drawables.append(line_center_to_cam)
        line_pt1_to_pt2.updateProjections(arView: arView)
        
        
        
        output_txt.append("""
                            ####################################################################################
                            Defects \(Int(temp_station.count) / 6 + 1), \n
                            Type : \(defect_name), \n
                            pt1 : \(pt1),\(loc_3d_pt1) \n
                            pt2 : \(pt2),\(loc_3d_pt2) \n
                            pt3 : \(pt3),\(loc_3d_pt3) \n
                            pt4 : \(pt4),\(loc_3d_pt4) \n
                            Center : \(center), \(loc_3d_center)\n
                            Camera : #NA#, \(loc_3d_camera)\n
                            pt1-2 : \(distance(loc_3d_pt1, loc_3d_pt2)) \n
                            pt2-3 : \(distance(loc_3d_pt2, loc_3d_pt3)) \n
                            pt3-4 : \(distance(loc_3d_pt3, loc_3d_pt4)) \n
                            pt4-1 : \(distance(loc_3d_pt4, loc_3d_pt1)) \n
                            Time: \(Date.now)
                            \n\n
                            """)
        
        self.control!.Last_defect_name = "\(Int(temp_station.count) / 6 + 1): \(defect_name)"
        self.control!.Last_edge_1 = "Top: \(String(format: "%.2fm", distance(loc_3d_pt1, loc_3d_pt2)))"
        self.control!.Last_edge_2 = "Right: \(String(format: "%.2fm", distance(loc_3d_pt2, loc_3d_pt3)))"
        self.control!.Last_edge_3 = "Bottom: \(String(format: "%.2fm", distance(loc_3d_pt3, loc_3d_pt4)))"
        self.control!.Last_edge_4 = "Left: \(String(format: "%.2fm", distance(loc_3d_pt4, loc_3d_pt1)))"
        
        
        let url_txt = control!.save_folder.appendingPathComponent("\(Int(temp_station.count) / 6 + 1)_\(defect_name).txt")
            
        do { try output_txt.write(to: url_txt, atomically: true, encoding: String.Encoding.utf8) } catch {}
            
        
            
        let screen_capture = (UIImage(pixelBuffer: (self.arView?.session.currentFrame!.capturedImage)!))!
        let screen_capture_url_img = control!.save_folder.appendingPathComponent("\(Int(temp_station.count) / 6 + 1)_\(defect_name)_raw.png")
        
        do {
            try screen_capture.pngData()!.write(to: screen_capture_url_img)
        }
        catch {
            print(error.localizedDescription)
        }
        
        //👆 save camera capture
        //#################################################################################################################################################
//
//        let screen_with_Bbox = self.view.sna
//        let screen_with_Bbox_url_img = control!.save_folder.appendingPathComponent("\(Int(temp_station.count) / 6 + 1)_\(defect_name)_bbox.png")
//
//        do{ try screen_with_Bbox.pngData()!.write(to: screen_with_Bbox_url_img) }
//        catch{ print(error.localizedDescription) }
//
//        //👆 save user view (with Bbox)
        //#################################################################################################################################################

            
            
//        }
    }
    
    @objc func handleTap_for_yolo_4_pts(_ bboxs: [CGPoint], defectname: String = "NA") {
        print("handleTap_for_yolo_4_pts")
        
//        DispatchQueue.main.async{
        
        guard let arView = self.arView else {return }
        // Reversed exsiting station list, -> Distance constains check fasters
        let temp_station = Array(self.surveyStations.reversed())

        var output_txt = ""
        
// 1. Define 4 pts of bbox, center == 5 pts in total
        
        //Top left || Top right || Bottom right || Bottom left
        //  ||          ||            ||               ||
        //  pt1,        pt2,          pt3,             pt4
        
            bboxs.forEach { box in
                if box.x < 0 || box.y < 0 {
                    print("#DEBUG negative bbox")
                    return
                }
            }
        
        let (pt1, pt2, pt3, pt4) = (bboxs[0], bboxs[1], bboxs[2], bboxs[3])
            
//        print(pt1, pt2, pt3, pt4)
        let center: CGPoint = CGPoint(x: (pt1.x + pt2.x) / 2 , y: (pt1.y + pt4.y) / 2)
        
        
// 2. Check distance constains
        guard
//            let raycast_pt1 = arView.raycast( from: pt1, allowing: .estimatedPlane , alignment: .vertical ).first,
//            let raycast_pt2 = arView.raycast( from: pt2, allowing: .estimatedPlane, alignment: .vertical ).first,
//            let raycast_pt3 = arView.raycast( from: pt3, allowing: .estimatedPlane, alignment: .vertical ).first,
//            let raycast_pt4 = arView.raycast( from: pt4, allowing: .estimatedPlane, alignment: .vertical ).first,
//            let raycast_center = arView.raycast( from: center, allowing: .estimatedPlane, alignment: .vertical ).first
            
            let raycast_pt1 = arView.raycast( from: pt1, allowing: .estimatedPlane , alignment: .any ).first,
            let raycast_pt2 = arView.raycast( from: pt2, allowing: .estimatedPlane, alignment: .any ).first,
            let raycast_pt3 = arView.raycast( from: pt3, allowing: .estimatedPlane, alignment: .any ).first,
            let raycast_pt4 = arView.raycast( from: pt4, allowing: .estimatedPlane, alignment: .any ).first,
            let raycast_center = arView.raycast( from: center, allowing: .estimatedPlane, alignment: .any ).first,
            
            let raycast_mid_1_2    = arView.raycast(from: CG_mid(pt1, pt2), allowing: .estimatedPlane , alignment: .any ).first,
            let raycast_mid_2_3    = arView.raycast(from: CG_mid(pt2, pt3), allowing: .estimatedPlane, alignment: .any ).first,
            let raycast_mid_3_4    = arView.raycast(from: CG_mid(pt3, pt4), allowing: .estimatedPlane, alignment: .any ).first,
            let raycast_mid_4_1    = arView.raycast(from: CG_mid(pt4, pt1), allowing: .estimatedPlane, alignment: .any ).first

        else {
            print("#DEBUG 4 pts raycast not sucessed")
            return
        }
            
        print("#DEBUG 4 pts raycast sucessed")
        //2.1 Check camera to center <= 2 m
            let loc_3d_center = raycast_center.worldTransform.toPosition()
            let loc_3d_pt1 = raycast_pt1.worldTransform.toPosition()
            let loc_3d_pt2 = raycast_pt2.worldTransform.toPosition()
            let loc_3d_pt3 = raycast_pt3.worldTransform.toPosition()
            let loc_3d_pt4 = raycast_pt4.worldTransform.toPosition()
            let loc_3d_camera = arView.cameraTransform.matrix.toPosition()
            
            let dis_list: [Float] = [distance(loc_3d_camera, loc_3d_pt1),
                                     distance(loc_3d_camera, loc_3d_pt2),
                                     distance(loc_3d_camera, loc_3d_pt3),
                                     distance(loc_3d_camera, loc_3d_pt4) ]
            
//            if (Float(dis_list.max()!) - Float(dis_list.min()!)) >= Float(0.5) {
//                print("#DEBUG Camera to points distances difference > 0.5 m --> return")
//                return
//            }
//
//            if distance(loc_3d_center, loc_3d_camera) > 2.0 {
//                print("#DEBUG Camera to center distance > 2.0 m --> return")
//                return
//            }
//
//            print("#DEBUG Camera to center distance < 2.0 m --> OK!")
            
        //2.2 Check center to other stations' center distance >= 50 cm
        
        //Manual placement -> no need distance check
//            for station in temp_station where station.bbox_loc.contains("Center") {
//                print("DEBUG: Check station centers' dist, \(station), \(station.bbox_loc)")
//                let dist = distance(loc_3d_center, station.position) //Real world Dist between center and others' center
//                if dist < control!.allow_dist {
//                    print("#DEBUG Center to center distance <= 0.5 cm --> return")
//                    return
//                }
//            }
//            print("#DEBUG Center to center distance > 0.5 cm --> OK!")
        
        
// 3. Mark 6 pts and add lines
        
        
        let lineHeight: CGFloat = 0.02
        let font = MeshResource.Font.systemFont(ofSize: lineHeight)
//        let font_small = MeshResource.Font.systemFont(ofSize: 0.01)
        let textMaterial = SimpleMaterial(color: .black, isMetallic: true)
        
        let textMesh_1_2 = MeshResource.generateText(String(format: "%.2fm", distance(loc_3d_pt1, loc_3d_pt2)), extrusionDepth: Float(lineHeight * 0.1), font: font)
        let textMesh_2_3 = MeshResource.generateText(String(format: "%.2fm", distance(loc_3d_pt2, loc_3d_pt3)), extrusionDepth: Float(lineHeight * 0.1), font: font)
        let textMesh_3_4 = MeshResource.generateText(String(format: "%.2fm", distance(loc_3d_pt3, loc_3d_pt4)), extrusionDepth: Float(lineHeight * 0.1), font: font)
        let textMesh_4_1 = MeshResource.generateText(String(format: "%.2fm", distance(loc_3d_pt4, loc_3d_pt1)), extrusionDepth: Float(lineHeight * 0.1), font: font)
        let textMesh_center = MeshResource.generateText("\(Int(temp_station.count) / 6 + 1): \(defectname)", extrusionDepth: Float(lineHeight * 0.1), font: font)
//        let textMesh_center = MeshResource.generateText(String(format: "%.2fm", distance(loc_3d_pt3, loc_3d_pt4)), extrusionDepth: Float(lineHeight * 0.1), font: font)
        
        let model_1_2 = ModelEntity(mesh: textMesh_1_2, materials: [textMaterial])
        let model_2_3 = ModelEntity(mesh: textMesh_2_3, materials: [textMaterial])
        let model_3_4 = ModelEntity(mesh: textMesh_3_4, materials: [textMaterial])
        let model_4_1 = ModelEntity(mesh: textMesh_4_1, materials: [textMaterial])
        let model_center = ModelEntity(mesh: textMesh_center, materials: [textMaterial])
        
        model_1_2.position.x -= model_1_2.visualBounds(relativeTo: nil).extents.x / 2
//        model_2_3.position.x -= model_2_3.visualBounds(relativeTo: nil).extents.x / 2
        model_3_4.position.x -= model_3_4.visualBounds(relativeTo: nil).extents.x / 2
        model_4_1.position.x -= model_4_1.visualBounds(relativeTo: nil).extents.x
        model_center.position.x -= model_center.visualBounds(relativeTo: nil).extents.x / 2
        
        
        let rayDirection_1_2 = normalize(raycast_mid_1_2.worldTransform.toPosition() - self.arView!.cameraTransform.translation)
        let rayDirection_2_3 = normalize(raycast_mid_2_3.worldTransform.toPosition() - self.arView!.cameraTransform.translation)
        let rayDirection_3_4 = normalize(raycast_mid_3_4.worldTransform.toPosition() - self.arView!.cameraTransform.translation)
        let rayDirection_4_1 = normalize(raycast_mid_4_1.worldTransform.toPosition() - self.arView!.cameraTransform.translation)
        let rayDirection_center = normalize(raycast_center.worldTransform.toPosition() - self.arView!.cameraTransform.translation)
        
        let textPositionInWorldCoordinates_1_2 = raycast_mid_1_2.worldTransform.toPosition() - (rayDirection_1_2 * 0.05)
        let textPositionInWorldCoordinates_2_3 = raycast_mid_2_3.worldTransform.toPosition() - (rayDirection_2_3 * 0.05)
        let textPositionInWorldCoordinates_3_4 = raycast_mid_3_4.worldTransform.toPosition() - (rayDirection_3_4 * 0.05)
        let textPositionInWorldCoordinates_4_1 = raycast_mid_4_1.worldTransform.toPosition() - (rayDirection_4_1 * 0.05)
        let textPositionInWorldCoordinates_center = raycast_center.worldTransform.toPosition() - (rayDirection_center * 0.05)
    
        var resultWithCameraOrientation_1_2 = self.arView!.cameraTransform
        var resultWithCameraOrientation_2_3 = self.arView!.cameraTransform
        var resultWithCameraOrientation_3_4 = self.arView!.cameraTransform
        var resultWithCameraOrientation_4_1 = self.arView!.cameraTransform
        var resultWithCameraOrientation_center = self.arView!.cameraTransform
        
        resultWithCameraOrientation_1_2.translation = textPositionInWorldCoordinates_1_2
        resultWithCameraOrientation_2_3.translation = textPositionInWorldCoordinates_2_3
        resultWithCameraOrientation_3_4.translation = textPositionInWorldCoordinates_3_4
        resultWithCameraOrientation_4_1.translation = textPositionInWorldCoordinates_4_1
        resultWithCameraOrientation_center.translation = textPositionInWorldCoordinates_center
        
        let Anchor_1_2 = AnchorEntity(world: resultWithCameraOrientation_1_2.matrix)
        let Anchor_2_3 = AnchorEntity(world: resultWithCameraOrientation_2_3.matrix)
        let Anchor_3_4 = AnchorEntity(world: resultWithCameraOrientation_3_4.matrix)
        let Anchor_4_1 = AnchorEntity(world: resultWithCameraOrientation_4_1.matrix)
        let Anchor_center = AnchorEntity(world: resultWithCameraOrientation_center.matrix)
        
        
//        Anchor_1_2.look(at:self.arView!.cameraTransform.translation , from: Anchor_1_2.position(relativeTo: nil) , upVector: [0, 1, 0], relativeTo: nil)
//        Anchor_2_3.look(at:self.arView!.cameraTransform.translation , from: Anchor_2_3.position(relativeTo: nil) , upVector: [0, 1, 0], relativeTo: nil)
//        Anchor_3_4.look(at:self.arView!.cameraTransform.translation , from: Anchor_3_4.position(relativeTo: nil) , upVector: [0, 1, 0], relativeTo: nil)
//        Anchor_4_1.look(at:self.arView!.cameraTransform.translation , from: Anchor_4_1.position(relativeTo: nil) , upVector: [0, 1, 0], relativeTo: nil)
        
        print("#Debug entity look to others!")
//        self.lineModel.append(Anchor_1_2)
//        self.lineModel.append(Anchor_2_3)
//        self.lineModel.append(Anchor_3_4)
//        self.lineModel.append(Anchor_4_1)
//
        
        Anchor_1_2.addChild(model_1_2)
        Anchor_2_3.addChild(model_2_3)
        Anchor_3_4.addChild(model_3_4)
        Anchor_4_1.addChild(model_4_1)
        Anchor_center.addChild(model_center)
        
//        arView.scene.addAnchor(Anchor_1_2)
//        arView.scene.addAnchor(Anchor_2_3)
//        arView.scene.addAnchor(Anchor_3_4)
//        arView.scene.addAnchor(Anchor_4_1)
        
        
        guard let surveyLines = self.surveyLines else { return }
        let MarkerID: Int = Int(temp_station.count) / 6 + 1

        let station_pt1 = SurveyStationEntity(worldTransform: raycast_pt1.worldTransform, bbox_loc: "\(MarkerID)_\(defectname)_pt1_YOLO", RayQuery: nil, station_defect_type: defectname ,ARscene: arView.scene)
        let station_pt2 = SurveyStationEntity(worldTransform: raycast_pt2.worldTransform, bbox_loc: "\(MarkerID)_\(defectname)_pt2_YOLO", RayQuery: nil, station_defect_type: defectname, ARscene: arView.scene)
        let station_pt3 = SurveyStationEntity(worldTransform: raycast_pt3.worldTransform, bbox_loc: "\(MarkerID)_\(defectname)_pt3_YOLO", RayQuery: nil, station_defect_type: defectname, ARscene: arView.scene)
        let station_pt4 = SurveyStationEntity(worldTransform: raycast_pt4.worldTransform, bbox_loc: "\(MarkerID)_\(defectname)_pt4_YOLO", RayQuery: nil, station_defect_type: defectname, ARscene: arView.scene)
        let station_center = SurveyStationEntity(worldTransform: raycast_center.worldTransform, bbox_loc: "\(MarkerID)_\(defectname)_Center_YOLO", RayQuery: nil, station_defect_type: defectname, ARscene: arView.scene)
        let station_camera = SurveyStationEntity(worldTransform: arView.cameraTransform.matrix, bbox_loc: "\(MarkerID)_\(defectname)_Camera_YOLO", RayQuery: nil, station_defect_type: defectname, ARscene: arView.scene)
        
        
        let station_pt1_Anchor    = ARAnchor( name: "\(MarkerID)_\(defectname)_pt1_anchor_for_reloc",    transform: raycast_pt1.worldTransform)
        let station_pt2_Anchor    = ARAnchor( name: "\(MarkerID)_\(defectname)_pt2_anchor_for_reloc",    transform: raycast_pt2.worldTransform)
        let station_pt3_Anchor    = ARAnchor( name: "\(MarkerID)_\(defectname)_pt3_anchor_for_reloc",    transform: raycast_pt3.worldTransform)
        let station_pt4_Anchor    = ARAnchor( name: "\(MarkerID)_\(defectname)_pt4_anchor_for_reloc",    transform: raycast_pt4.worldTransform)
        let station_center_Anchor = ARAnchor( name: "\(MarkerID)_\(defectname)_Center_anchor_for_reloc", transform: raycast_center.worldTransform)
        let station_camera_Anchor = ARAnchor( name: "\(MarkerID)_\(defectname)_Camera_anchor_for_reloc", transform: arView.cameraTransform.matrix)
        
        
        arView.session.add(anchor: station_pt1_Anchor)
        arView.session.add(anchor: station_pt2_Anchor)
        arView.session.add(anchor: station_pt3_Anchor)
        arView.session.add(anchor: station_pt4_Anchor)
        arView.session.add(anchor: station_center_Anchor)
        arView.session.add(anchor: station_camera_Anchor)
        
        let camera = AnchorEntity(world: raycast_center.worldTransform) //.world(transform: raycast_center.worldTransform))
//        let camera = AnchorEntity(anchor: station_center_Anchor)
//        let camera = AnchorEntity(raycastResult: raycast_center)
        
        
//        let camera = AnchorEntity(.plane(.any, classification: .any, minimumBounds: .one))
        
        arView.scene.addAnchor(camera)
        
        camera.addChild(Anchor_1_2)
        camera.addChild(Anchor_2_3)
        camera.addChild(Anchor_3_4)
        camera.addChild(Anchor_4_1)
        camera.addChild(Anchor_center)
        
        // reloc_jump
//        arView.scene.anchors.append(virtualObjectAnchor)
//        arView.scene.addAnchor(virtualObjectAnchor!)
        
        Anchors_list.append(camera)
        

        self.surveyStations.append(station_pt1)
//        arView.scene.addAnchor(station_pt1)
        camera.addChild(station_pt1)
        arView.installGestures(for: station_pt1)
        
        
        var lastEntity = self.surveyStations.last
        self.surveyStations.append(station_pt2)
//        arView.scene.addAnchor(station_pt2)
        camera.addChild(station_pt2)
        arView.installGestures(for: station_pt2)
        //Uncomment following to draw line between stations
        let line_pt1_to_pt2 = lastEntity!.lineTo(station_pt2, linked_bbox_loc: "\(MarkerID)_\(defectname)_pt1_to_pt2_YOLO")
        print("DEBUG line_pt1_to_pt2 \(line_pt1_to_pt2.linked_bbox_loc)")
        surveyLines.drawables.append(line_pt1_to_pt2)
        line_pt1_to_pt2.updateProjections(arView: arView) //@Isaac.debug, if comment below, line wont show on screen but still save and show in model viewer
        
            
            
        lastEntity = self.surveyStations.last
        self.surveyStations.append(station_pt3)
//        arView.scene.addAnchor(station_pt3)
        camera.addChild(station_pt3)
        arView.installGestures(for: station_pt3)
        //Uncomment following to draw line between stations
        let line_pt2_to_pt3 = lastEntity!.lineTo(station_pt3, linked_bbox_loc: "\(MarkerID)_\(defectname)_pt2_to_pt3_YOLO")
        print("DEBUG line_pt2_to_pt3 \(line_pt2_to_pt3.linked_bbox_loc)")
        surveyLines.drawables.append(line_pt2_to_pt3)
        line_pt2_to_pt3.updateProjections(arView: arView) //@Isaac.debug, if comment below, line wont show on screen but still save and show in model viewer

            
            
        lastEntity = self.surveyStations.last
        self.surveyStations.append(station_pt4)
//        arView.scene.addAnchor(station_pt4)
        camera.addChild(station_pt4)
        arView.installGestures(for: station_pt4)
        //Uncomment following to draw line between stations
        let line_pt3_to_pt4 = lastEntity!.lineTo(station_pt4, linked_bbox_loc: "\(MarkerID)_\(defectname)_pt3_to_pt4_YOLO")
        print("DEBUG line_pt3_to_pt4 \(line_pt3_to_pt4.linked_bbox_loc)")
        surveyLines.drawables.append(line_pt3_to_pt4)
        line_pt3_to_pt4.updateProjections(arView: arView) //@Isaac.debug, if comment below, line wont show on screen but still save and show in model viewer

            
        lastEntity = self.surveyStations.last
        let line_pt4_to_pt1 = lastEntity!.lineTo(station_pt1, linked_bbox_loc: "\(MarkerID)_\(defectname)_pt4_to_pt1_YOLO")
        print("DEBUG line_pt4_to_pt1 \(line_pt4_to_pt1.linked_bbox_loc)")
        surveyLines.drawables.append(line_pt4_to_pt1)
        line_pt4_to_pt1.updateProjections(arView: arView) //@Isaac.debug, if comment below, line wont show on screen but still save and show in model viewer
        
            
            
        self.surveyStations.append(station_center)
//        arView.scene.addAnchor(station_center)
        camera.addChild(station_center)
        arView.installGestures(for: station_center)

        lastEntity = self.surveyStations.last
        self.surveyStations.append(station_camera)
//        arView.scene.addAnchor(station_camera)
        camera.addChild(station_camera)
        arView.installGestures(for: station_camera)
        //Uncomment following to draw line between stations
        let line_center_to_cam = lastEntity!.lineTo(station_camera, linked_bbox_loc: "\(MarkerID)_\(defectname)_center_to_cam_YOLO")
        print("DEBUG line_center_to_cam \(line_center_to_cam.linked_bbox_loc)")
        surveyLines.drawables.append(line_center_to_cam)
        line_pt1_to_pt2.updateProjections(arView: arView)
        
        output_txt.append("""
                            ####################################################################################
                            Defects \(Int(temp_station.count) / 6 + 1), \n
                            Defect's name: \(defectname), \n
                            pt1 : \(pt1),\(loc_3d_pt1) \n
                            pt2 : \(pt2),\(loc_3d_pt2) \n
                            pt3 : \(pt3),\(loc_3d_pt3) \n
                            pt4 : \(pt4),\(loc_3d_pt4) \n
                            Center : \(center), \(loc_3d_center)\n
                            Camera : #NA#, \(loc_3d_camera)\n
                            pt1-2 : \(distance(loc_3d_pt1, loc_3d_pt2)) \n
                            pt2-3 : \(distance(loc_3d_pt2, loc_3d_pt3)) \n
                            pt3-4 : \(distance(loc_3d_pt3, loc_3d_pt4)) \n
                            pt4-1 : \(distance(loc_3d_pt4, loc_3d_pt1)) \n
                            Time: \(Date.now)
                            \n\n
                            """)
        
//        self.control!.Captured_image = self.arView!.session.currentFrame!.capturedImage
        
        self.control!.Last_defect_name = "\(Int(temp_station.count) / 6 + 1): \(defectname)"
        self.control!.Last_edge_1 = "Top: \(String(format: "%.2fm", distance(loc_3d_pt1, loc_3d_pt2)))"
        self.control!.Last_edge_2 = "Right: \(String(format: "%.2fm", distance(loc_3d_pt2, loc_3d_pt3)))"
        self.control!.Last_edge_3 = "Bottom: \(String(format: "%.2fm", distance(loc_3d_pt3, loc_3d_pt4)))"
        self.control!.Last_edge_4 = "Left: \(String(format: "%.2fm", distance(loc_3d_pt4, loc_3d_pt1)))"
        
        let url_txt = control!.save_folder.appendingPathComponent("YOLO_\(MarkerID)_\(defectname).txt")
            
        do { try output_txt.write(to: url_txt, atomically: true, encoding: String.Encoding.utf8) } catch {}
            
        let url_img = control!.save_folder.appendingPathComponent("YOLO_\(MarkerID)_\(defectname)_raw.png")
            
        let screen_capture = (UIImage(pixelBuffer: (self.arView?.session.currentFrame!.capturedImage)!))!
            
        do {
            try screen_capture.pngData()!.write(to: url_img)
        } catch {
            print(error.localizedDescription)
        }

    }
    
    @objc func handleTap_for_yolo_4_pts_old_non_use(_ bboxs: [CGPoint], defectname: String = "NA") {
        print("handleTap_for_yolo_4_pts")
        
//        DispatchQueue.main.async{
        
        guard let arView = self.arView else {return }
        // Reversed exsiting station list, -> Distance constains check fasters
        let temp_station = Array(self.surveyStations.reversed())

        var output_txt = ""
        
// 1. Define 4 pts of bbox, center == 5 pts in total
        
        //Top left || Top right || Bottom right || Bottom left
        //  ||          ||            ||               ||
        //  pt1,        pt2,          pt3,             pt4
        
            bboxs.forEach { box in
                if box.x < 0 || box.y < 0 {
                    print("#DEBUG negative bbox")
                    return
                }
            }
        
        let (pt1, pt2, pt3, pt4) = (bboxs[0], bboxs[1], bboxs[2], bboxs[3])
        // 2D pixel coor
            
//        print(pt1, pt2, pt3, pt4)
        let center: CGPoint = CGPoint(x: (pt1.x + pt2.x) / 2 , y: (pt1.y + pt4.y) / 2)
        
        
// 2. Check distance constains
        guard
            let raycast_pt1 = arView.raycast( from: pt1, allowing: .estimatedPlane, alignment: .any ).first,
            let raycast_pt2 = arView.raycast( from: pt2, allowing: .estimatedPlane, alignment: .any ).first,
            let raycast_pt3 = arView.raycast( from: pt3, allowing: .estimatedPlane, alignment: .any ).first,
            let raycast_pt4 = arView.raycast( from: pt4, allowing: .estimatedPlane, alignment: .any ).first,
            let raycast_center = arView.raycast( from: center, allowing: .estimatedPlane, alignment: .any ).first,
             
            let raycast_query_pt1    = arView.makeRaycastQuery( from: pt1, allowing: .estimatedPlane , alignment: .any ),
            let raycast_query_pt2    = arView.makeRaycastQuery( from: pt2, allowing: .estimatedPlane, alignment: .any ),
            let raycast_query_pt3    = arView.makeRaycastQuery( from: pt3, allowing: .estimatedPlane, alignment: .any ),
            let raycast_query_pt4    = arView.makeRaycastQuery( from: pt4, allowing: .estimatedPlane, alignment: .any ),
            let raycast_query_center = arView.makeRaycastQuery( from: center, allowing: .estimatedPlane, alignment: .any )
        else {
            print("#DEBUG 4 pts raycast not sucessed")
            return
        }
            
        print("#DEBUG 4 pts raycast sucessed")
        //2.1 Check camera to center <= 2 m
        let loc_3d_center = raycast_center.worldTransform.toPosition()
        let loc_3d_camera = arView.cameraTransform.matrix.toPosition()
        
            
//        if distance(loc_3d_center, loc_3d_camera) > 2.0 {
//            print("#DEBUG Camera to center distance > 2.0 m --> return")
//            return
//        }
//        print("#DEBUG Camera to center distance < 2.0 m --> OK!")
//
//        //2.2 Check center to other stations' center distance >= 50 cm
//        for station in temp_station where station.bbox_loc == "Center" {
//            print("DEBUG: Check station centers' dist, \(station), \(station.bbox_loc)")
//            let dist = distance(loc_3d_center, station.position) //Real world Dist between center and others' center
//            if dist < 0.5 {
//                print("#DEBUG Center to center distance <= 0.5 cm --> return")
//                return
//            }
//        }
//        print("#DEBUG Center to center distance > 0.5 cm --> OK!")
        
        
// 3. Mark 6 pts and add lines
        
        guard let surveyLines = self.surveyLines else { return}
        

        let station_pt1 = SurveyStationEntity(worldTransform: raycast_pt1.worldTransform, bbox_loc: "\(Int(temp_station.count) / 6 + 1)_\(defectname)_YOLO_pt1", RayQuery: raycast_query_pt1, station_defect_type: defectname, ARscene: arView.scene)
        let station_pt2 = SurveyStationEntity(worldTransform: raycast_pt2.worldTransform, bbox_loc: "\(Int(temp_station.count) / 6 + 1)_\(defectname)_YOLO_pt2", RayQuery: raycast_query_pt2, station_defect_type: defectname, ARscene: arView.scene)
        let station_pt3 = SurveyStationEntity(worldTransform: raycast_pt3.worldTransform, bbox_loc: "\(Int(temp_station.count) / 6 + 1)_\(defectname)_YOLO_pt3", RayQuery: raycast_query_pt3, station_defect_type: defectname, ARscene: arView.scene)
        let station_pt4 = SurveyStationEntity(worldTransform: raycast_pt4.worldTransform, bbox_loc: "\(Int(temp_station.count) / 6 + 1)_\(defectname)_YOLO_pt4", RayQuery: raycast_query_pt4, station_defect_type: defectname, ARscene: arView.scene)
        let station_center = SurveyStationEntity(worldTransform: raycast_center.worldTransform, bbox_loc: "\(Int(temp_station.count) / 6 + 1)_\(defectname)_YOLO_Center", RayQuery: raycast_query_center, station_defect_type: defectname, ARscene: arView.scene)
        let station_camera = SurveyStationEntity(worldTransform: arView.cameraTransform.matrix, bbox_loc: "\(Int(temp_station.count) / 6 + 1)_\(defectname)_YOLO_Camera", RayQuery: nil, station_defect_type: defectname, ARscene: arView.scene)

        self.surveyStations.append(station_pt1)
        arView.scene.addAnchor(station_pt1)
        
        
        arView.installGestures(for: station_pt1)


        var lastEntity = self.surveyStations.last
        self.surveyStations.append(station_pt2)
        arView.scene.addAnchor(station_pt2)
        arView.installGestures(for: station_pt2)
        //Uncomment following to draw line between stations
        let line_pt1_to_pt2 = lastEntity!.lineTo(station_pt2, linked_bbox_loc: "\(Int(temp_station.count) / 6 + 1)_\(defectname)_YOLO_pt1_to_pt2")
        print("DEBUG line_pt1_to_pt2 \(line_pt1_to_pt2.linked_bbox_loc)")
        surveyLines.drawables.append(line_pt1_to_pt2)
        line_pt1_to_pt2.updateProjections(arView: arView) //@Isaac.debug, if comment below, line wont show on screen but still save and show in model viewer



        lastEntity = self.surveyStations.last
        self.surveyStations.append(station_pt3)
        arView.scene.addAnchor(station_pt3)
        arView.installGestures(for: station_pt3)
        //Uncomment following to draw line between stations
        let line_pt2_to_pt3 = lastEntity!.lineTo(station_pt3, linked_bbox_loc: "\(Int(temp_station.count) / 6 + 1)_\(defectname)_YOLO_pt2_to_pt3")
        print("DEBUG line_pt2_to_pt3 \(line_pt2_to_pt3.linked_bbox_loc)")
        surveyLines.drawables.append(line_pt2_to_pt3)
        line_pt2_to_pt3.updateProjections(arView: arView) //@Isaac.debug, if comment below, line wont show on screen but still save and show in model viewer



        lastEntity = self.surveyStations.last
        self.surveyStations.append(station_pt4)
        arView.scene.addAnchor(station_pt4)
        arView.installGestures(for: station_pt4)
        //Uncomment following to draw line between stations
        let line_pt3_to_pt4 = lastEntity!.lineTo(station_pt4, linked_bbox_loc: "\(Int(temp_station.count) / 6 + 1)_\(defectname)_YOLO_pt3_to_pt4")
        print("DEBUG line_pt3_to_pt4 \(line_pt3_to_pt4.linked_bbox_loc)")
        surveyLines.drawables.append(line_pt3_to_pt4)
        line_pt3_to_pt4.updateProjections(arView: arView) //@Isaac.debug, if comment below, line wont show on screen but still save and show in model viewer


        lastEntity = self.surveyStations.last
        let line_pt4_to_pt1 = lastEntity!.lineTo(station_pt1, linked_bbox_loc: "\(Int(temp_station.count) / 6 + 1)_\(defectname)_YOLO_pt4_to_pt1")
        print("DEBUG line_pt4_to_pt1 \(line_pt4_to_pt1.linked_bbox_loc)")
        surveyLines.drawables.append(line_pt4_to_pt1)
        line_pt4_to_pt1.updateProjections(arView: arView) //@Isaac.debug, if comment below, line wont show on screen but still save and show in model viewer



        self.surveyStations.append(station_center)
        arView.scene.addAnchor(station_center)
        arView.installGestures(for: station_center)
        
        lastEntity = self.surveyStations.last
        self.surveyStations.append(station_camera)
        arView.scene.addAnchor(station_camera)
        arView.installGestures(for: station_camera)
        //Uncomment following to draw line between stations
        let line_center_to_cam = lastEntity!.lineTo(station_camera, linked_bbox_loc: "\(Int(temp_station.count) / 6 + 1)_\(defectname)_YOLO_center_to_cam")
        print("DEBUG line_center_to_cam \(line_center_to_cam.linked_bbox_loc)")
        surveyLines.drawables.append(line_center_to_cam)
        line_center_to_cam.updateProjections(arView: arView)
        
        let path = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        output_txt.append("""
                            ####################################################################################
                            Defects \(Int(temp_station.count) / 6 + 1), \n
                            Defect's name: \(defectname), \n
                            pt1 : \(pt1),\(raycast_pt1.worldTransform.toPosition()) \n
                            pt2 : \(pt2),\(raycast_pt2.worldTransform.toPosition()) \n
                            pt3 : \(pt3),\(raycast_pt3.worldTransform.toPosition()) \n
                            pt4 : \(pt4),\(raycast_pt4.worldTransform.toPosition()) \n
                            Center : \(center), \(loc_3d_center)\n
                            Camera : #NA#, \(loc_3d_camera)\n
                            Time: \(Date.now)
                            \n\n
                            """)
        let url_txt = control!.save_folder.appendingPathComponent("YOLO_\(Int(temp_station.count) / 6 + 1).txt")
            
        do { try output_txt.write(to: url_txt, atomically: true, encoding: String.Encoding.utf8) } catch {}
            
        let url_img = control!.save_folder.appendingPathComponent("YOLO_\(Int(temp_station.count) / 6 + 1).png")
            
        let screen_capture = (UIImage(pixelBuffer: (self.arView?.session.currentFrame!.capturedImage)!))!
            
        do {
            try screen_capture.pngData()!.write(to: url_img)
        } catch {
            print(error.localizedDescription)
        }
            
            
//        }
    }
    
    @objc func handleTaps_info_4_pts(_ bboxs: [CGPoint]) -> [Float]{
        
        print("handleTaps_info_4_pts")
        
        guard let arView = self.arView else { return []}
        
        var Pts : [[Float]] = []
        var Distance : [Float] = []
        
        var output: String = ""
        var pt = 1
        
        for bbox in bboxs {
            
//            print("Hi")
            let hitResult: [CollisionCastHit] = arView.hitTest(bbox)
            
            if let hitFirst = hitResult.first { return [0, 0, 0, 0]}
            
            else {
                guard
                    let arView = self.arView,
                    let raycast = arView.raycast(
                        from: bbox,
                        allowing: .estimatedPlane,
                        alignment: .any
                    ).first
                else {
                    return [0, 0, 0, 0]///  no surface detected
                }
//                print(raycast)
                let xyz_col = raycast.worldTransform.columns.3
                
//                print("\(pt): \(pos.columns.3.x), \(pos.columns.3.y), \(pos.columns.3.z)")
                
                if !(Pts.isEmpty){
                    let last_pt = Pts.last
                    let dist = simd_distance(simd_float3(xyz_col.x, xyz_col.y, xyz_col.z), simd_float3(x: last_pt![0], y: last_pt![1], z: last_pt![2]))
                    Distance.append(dist)
                }
                
                Pts.append([xyz_col.x, xyz_col.y, xyz_col.z])
                
                output.append("\(pt): \(xyz_col.x), \(xyz_col.y), \(xyz_col.z)")
                output.append("\n")
                pt += 1
            }
        }
        let first_pt = Pts[0]
        let last_pt = Pts[3]
        
        let dist = simd_distance(simd_float3(x: first_pt[0], y: first_pt[1], z: first_pt[2]),
                                 simd_float3(x: last_pt[0], y: last_pt[1], z: last_pt[2]))
        Distance.append(dist)
        
        output.append("\(Distance)")
        
//        let path = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
//        var url = path.appendingPathComponent("\(Date.now).txt")
        
//        do {
//            try output.write(to: url, atomically: true, encoding: .utf8)
//        } catch {
//            print(error.localizedDescription)
//        }
        
//        print(output)
        
        return Distance
    }
    
    private func tappedOnEntity(hitFirst: CollisionCastHit) {
        let entity = hitFirst.entity
        print("entity")
        print("parameters \(entity.parameters)")
        print("name \(entity.name)")
        
        if let stationEntity = entity as? SurveyStationEntity {
            print("Highlighted")
            stationEntity.highlight(true)
        }
    }

    private func tappedOnNonentity(tapLoc: CGPoint) { //}, cap_img last_captured_image: CVPixelBuffer?) {
        #if !targetEnvironment(simulator)
        guard
//            let camLoc = self.arView?,
            let arView = self.arView,
            let surveyLines = self.surveyLines,
            let raycast = arView.raycast(
                from: tapLoc,
                allowing: .estimatedPlane,
                alignment: .any
            ).first,
            let raycast_query = arView.makeRaycastQuery( from: tapLoc, allowing: .estimatedPlane, alignment: .any )
        else {
            return ///  no surface detected
        }
        
        let result = SurveyStationEntity(worldTransform: raycast.worldTransform, RayQuery: nil, ARscene: arView.scene) //, image: last_captured_image)
        self.surveyStations.append(result)
        arView.scene.addAnchor(result)
        arView.installGestures(for: result)

        let lastEntity = self.surveyStations.last
        
        let result2 = SurveyStationEntity(worldTransform: arView.cameraTransform.matrix, RayQuery: raycast_query, ARscene: arView.scene)
        self.surveyStations.append(result2)
        arView.scene.addAnchor(result2)
        arView.installGestures(for: result2)
        //Uncomment following to draw line between stations
        
        if lastEntity != nil {
            let line = lastEntity!.lineTo(result2, linked_bbox_loc: "Screen_touch")
            surveyLines.drawables.append(line)
            
            //@Isaac.debug, if comment below, line wont show on screen but still save and show in model viewer
            line.updateProjections(arView: arView)
        }
        
        
        #endif
    }

    
}


