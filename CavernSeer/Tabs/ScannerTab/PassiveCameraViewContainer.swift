//
//  PassiveCameraViewContainer.swift
//  CavernSeer
//
//  Created by Samuel Grush on 1/18/21.
//  Copyright © 2021 Samuel K. Grush. All rights reserved.
//

import SwiftUI /// UIViewRepresentable
import AVFoundation /// AVCaptureSession
import Combine /// Cancellable
import CoreML

struct PassiveCameraViewContainer : UIViewRepresentable {

    @ObservedObject
    var control: ScannerControlModel
    
//    let Detection_Model : yolov7x_original_with_NMS_IOU_Thrd_05_Conf_Thrd_04 = {
//        do {
//            let configuration = MLModelConfiguration()
//            return try _3cls_detect_b16_TL_Iteration_1000(configuration: configuration)
//        } catch let error {
//            fatalError(error.localizedDescription)
//        }
//    }()

    func makeUIView(context: Context) -> some UIView {
        PassiveCameraView(control: self.control)
    }

    func updateUIView(_ uiView: UIViewType, context: Context) {}
    
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }

    final class Coordinator : NSObject {
        var parent : PassiveCameraViewContainer
        
        init( _ parent : PassiveCameraViewContainer) {
            self.parent = parent
        }
    }
}

extension PassiveCameraViewContainer {
    /**
     * **Heaviliy** based on
     * [Asperi's example on Stack Overflow](https://stackoverflow.com/a/59064305)
     */
    
    class PassiveCameraView : UIView {
        var control: ScannerControlModel

        private var captureSession: AVCaptureSession?

        private var passiveCamEnabledSub: Cancellable?

        init(control: ScannerControlModel) {
            self.control = control
            
            
            super.init(frame: .zero)

            guard
                self.getCameraAccess(),
                let session = Self.setupSession()
            else {
                return
            }
            self.captureSession = session

            self.passiveCamEnabledSub =
                self.control.$renderingPassiveView.sink {
                    [weak self] enabled in
                    if !enabled {
                        self?.captureSession?.stopRunning()
                    }
                }
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }

        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
//            self.videoPreviewLayer.connection?.videoOrientation = .landscapeLeft
            return layer as! AVCaptureVideoPreviewLayer
        }

        override func didMoveToSuperview() {
            super.didMoveToSuperview()

            if nil != self.superview {
                self.videoPreviewLayer.session = self.captureSession
                self.videoPreviewLayer.videoGravity = .resizeAspect
                self.videoPreviewLayer.connection?.videoOrientation = .landscapeRight
//                self.videoPreviewLayer.
                self.captureSession?.startRunning()
            } else {
                self.captureSession?.stopRunning()
            }
        }

        /**
         * Try to get camera access, and set `control.cameraEnabled` with the result`
         */
        private func getCameraAccess() -> Bool {
            if self.control.cameraEnabled == nil {
                let blocker = DispatchGroup()
                blocker.enter()
                AVCaptureDevice.requestAccess(for: .video) {
                    flag in
                    self.control.updateCameraAccess(hasAccess: flag)
                    blocker.leave()
                }
                blocker.wait()
            }

            /// expect `cameraEnabled` is set since we called `updateCameraAccess`
            return self.control.cameraEnabled!
        }
        

        private static func setupSession() -> AVCaptureSession? {
            // setup session
            let session = AVCaptureSession()
            session.beginConfiguration()

            guard
                let device = AVCaptureDevice.default(for: .video),
                let deviceInput = try? AVCaptureDeviceInput(device: device),
                session.canAddInput(deviceInput)
            else {
                debugPrint("Failed to retrieve camera input")
                return nil
            }

            session.addInput(deviceInput)
            session.commitConfiguration()
            return session
        }
    }

}
