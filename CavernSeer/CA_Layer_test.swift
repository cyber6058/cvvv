//
//  CA_Layer_test.swift
//  CavernSeer
//
//  Created by Ho Tin Hung on 2022/9/5.
//  Copyright © 2022 Samuel K. Grush. All rights reserved.
//
import AVFoundation
import CoreML
import UIKit
import SwiftUI
import RealityKit
import Vision
import VideoToolbox



class BoundingBox_layer: UIViewController{
    
    var screenRect: CGRect! = nil // For view dimensions
    var detectionLayer: CALayer! = nil
    
    
//    convenience init(num: Int){
//        self.init(num: num)
////        self.num = num
//
//    }
//
//    required init?(coder: NSCoder) {
//        fatalError("init(coder:) has not been implemented")
//    }
    
    override func viewDidLoad() {
        detectionLayer = CALayer()
        screenRect = UIScreen.main.bounds
        detectionLayer.frame = CGRect(x: 0, y: 0, width: screenRect.size.width, height: screenRect.size.height)
        self.view.layer.addSublayer(detectionLayer)
        
//        let (boxLayer, boxLabelLayer) = self.drawBoundingBox(transformedBounds, with: objectObservation.labels[0].identifier)
        let (boxLayer, boxLabelLayer) = self.drawBoundingBox()
        detectionLayer.addSublayer(boxLayer)
        detectionLayer.addSublayer(boxLabelLayer)
        
        
        print("##DEBUG BoundingBox_layer: UIViewController - viewDidLoad - Hi")
    }
    
    
//    func drawBoundingBox(_ bounds: CGRect, with name: String) -> (CALayer, CATextLayer) {
    
    
    public func drawBoundingBox() -> (CALayer, CATextLayer) {
        let boxLayer = CALayer()
//        boxLayer.frame = bounds
        boxLayer.frame = CGRect(x: CGFloat.random(in: 100...600),
                                y: CGFloat.random(in: 100...600),
                                width: CGFloat.random(in: 100...600),
                                height: CGFloat.random(in: 100...600))
        
        boxLayer.borderWidth = 3.0
        boxLayer.borderColor = CGColor.init(red: 1.0, green: 1.0, blue: 0.0, alpha: 1.0)
        boxLayer.cornerRadius = 4
        
        let boxLabelLayer = CATextLayer()
        boxLabelLayer.frame = CGRect(x: 500, y: 500, width: 300, height: 200)
        boxLabelLayer.string = "Isaac"
        boxLabelLayer.fontSize = 16
        
        return (boxLayer, boxLabelLayer)
    }
    
    public func updateLayers() {
        detectionLayer.sublayers = nil
        let num_bbox: Int = Int.random(in: 1...6)
        
        for _ in 1...num_bbox {
            let (boxLayer, boxLabelLayer) = self.drawBoundingBox()
            detectionLayer.addSublayer(boxLayer)
            detectionLayer.addSublayer(boxLabelLayer)
        }
        
//        detectionLayer?.frame = CGRect(x: 0, y: 0, width: screenRect.size.width, height: screenRect.size.height)
    }
}

struct BoundingBox_layer_Controller: UIViewControllerRepresentable {

//    var Bbox_layer: UIViewController
    var num: Int

//    init(num: Int){
//        self.num = num
//        self.Bbox_layer = BoundingBox_layer(num: num)
//    }

    func makeUIViewController(context: Context) -> UIViewController {
        return BoundingBox_layer()
        }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
//        let layer = self.Bbox_layer
//        print("Hi \(Date.now)")
    }
}
//
//class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
//    private var permissionGranted = false // Flag for permission
//    private let captureSession = AVCaptureSession()
//    private let sessionQueue = DispatchQueue(label: "sessionQueue")
//    private var previewLayer = AVCaptureVideoPreviewLayer()
//    var screenRect: CGRect! = nil // For view dimensions
//
//    // Detector
//    private var videoOutput = AVCaptureVideoDataOutput()
//    var requests = [VNRequest]()
//    var detectionLayer: CALayer! = nil
//
//
//    override func viewDidLoad() {
//        checkPermission()
//
//        sessionQueue.async { [unowned self] in
//            guard permissionGranted else { return }
//            self.setupCaptureSession()
//
//            self.setupDetector()
//            self.setupLayers()
//            self.captureSession.startRunning()
//        }
//    }
//
//    override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
//        screenRect = UIScreen.main.bounds
//        self.previewLayer.frame = CGRect(x: 0, y: 0, width: screenRect.size.width, height: screenRect.size.height)
//
//        switch UIDevice.current.orientation {
//            // Home button on top
//            case UIDeviceOrientation.portraitUpsideDown:
//                self.previewLayer.connection?.videoOrientation = .portraitUpsideDown
//
//            // Home button on right
//            case UIDeviceOrientation.landscapeLeft:
//                self.previewLayer.connection?.videoOrientation = .landscapeRight
//
//            // Home button on left
//            case UIDeviceOrientation.landscapeRight:
//                self.previewLayer.connection?.videoOrientation = .landscapeLeft
//
//            // Home button at bottom
//            case UIDeviceOrientation.portrait:
//                self.previewLayer.connection?.videoOrientation = .portrait
//
//            default:
//                break
//            }
//
//        // Detector
//        updateLayers()
//    }
//
//    func checkPermission() {
//        switch AVCaptureDevice.authorizationStatus(for: .video) {
//            // Permission has been granted before
//            case .authorized:
//                permissionGranted = true
//
//            // Permission has not been requested yet
//            case .notDetermined:
//                requestPermission()
//
//            default:
//                permissionGranted = false
//            }
//    }
//
//    func requestPermission() {
//        sessionQueue.suspend()
//        AVCaptureDevice.requestAccess(for: .video) { [unowned self] granted in
//            self.permissionGranted = granted
//            self.sessionQueue.resume()
//        }
//    }
//
//    func setupCaptureSession() {
//        // Camera input
//        guard let videoDevice = AVCaptureDevice.default(.builtInDualWideCamera,for: .video, position: .back) else { return }
//        guard let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice) else { return }
//
//        guard captureSession.canAddInput(videoDeviceInput) else { return }
//        captureSession.addInput(videoDeviceInput)
//
//        // Preview layer
//        screenRect = UIScreen.main.bounds
//
//        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
//        previewLayer.frame = CGRect(x: 0, y: 0, width: screenRect.size.width, height: screenRect.size.height)
//        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill // Fill screen
//        previewLayer.connection?.videoOrientation = .portrait
//
//        // Detector
//        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "sampleBufferQueue"))
//        captureSession.addOutput(videoOutput)
//
//        videoOutput.connection(with: .video)?.videoOrientation = .portrait
//
//        // Updates to UI must be on main queue
//        DispatchQueue.main.async { [weak self] in
//            self!.view.layer.addSublayer(self!.previewLayer)
//        }
//    }
//
//    func setupDetector() {
//        let modelURL = Bundle.main.url(forResource: "yolov7x-original_with_NMS_IOU_Thrd_05_Conf_Thrd_04", withExtension: "mlmodelc")
//
//        do {
//            let visionModel = try VNCoreMLModel(for: MLModel(contentsOf: modelURL!))
//            let recognitions = VNCoreMLRequest(model: visionModel, completionHandler: detectionDidComplete)
//            self.requests = [recognitions]
//        } catch let error {
//            print(error)
//        }
//    }
//
//    func detectionDidComplete(request: VNRequest, error: Error?) {
//        DispatchQueue.main.async(execute: {
//            if let results = request.results {
//                self.extractDetections(results)
//            }
//            print("###DEBUG Isaac Detected!!! \(Date.now)")
//        })
//    }
//
//    func extractDetections(_ results: [VNObservation]) {
//        detectionLayer.sublayers = nil
//
//        for observation in results where observation is VNRecognizedObjectObservation {
//            guard let objectObservation = observation as? VNRecognizedObjectObservation else { continue }
//
//            // Transformations
//            let objectBounds = VNImageRectForNormalizedRect(objectObservation.boundingBox, Int(screenRect.size.width), Int(screenRect.size.height))
//            let transformedBounds = CGRect(x: objectBounds.minX, y: screenRect.size.height - objectBounds.maxY, width: objectBounds.maxX - objectBounds.minX, height: objectBounds.maxY - objectBounds.minY)
//
//            let boxLayer = self.drawBoundingBox(transformedBounds)
//            print(objectObservation.labels)
//            detectionLayer.addSublayer(boxLayer)
//        }
//    }
//
//    func setupLayers() {
//        detectionLayer = CALayer()
//        detectionLayer.frame = CGRect(x: 0, y: 0, width: screenRect.size.width, height: screenRect.size.height)
//        self.view.layer.addSublayer(detectionLayer)
//    }
//
//    func updateLayers() {
//        detectionLayer?.frame = CGRect(x: 0, y: 0, width: screenRect.size.width, height: screenRect.size.height)
//    }
//
//    func drawBoundingBox(_ bounds: CGRect) -> CALayer {
//        let boxLayer = CALayer()
//        boxLayer.frame = bounds
////        boxLayer.frame = CGRect(x: 100, y: 100, width: 50, height: 50)
//        boxLayer.borderWidth = 3.0
//        boxLayer.borderColor = CGColor.init(red: 1.0, green: 0.0, blue: 1.0, alpha: 1.0)
//        boxLayer.cornerRadius = 4
//        return boxLayer
//    }
//
//    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
//        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
//        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:]) // Create handler to perform request on the buffer
//
//        do {
//            try imageRequestHandler.perform(self.requests) // Schedules vision requests to be performed
//        } catch {
//            print(error)
//        }
//    }
//}
//
//struct HostedViewController: UIViewControllerRepresentable {
//    func makeUIViewController(context: Context) -> UIViewController {
//        return ViewController()
//        }
//
//        func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
//        }
//}
