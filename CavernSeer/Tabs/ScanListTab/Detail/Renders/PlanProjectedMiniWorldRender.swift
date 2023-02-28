//
//  PlanProjectedMiniWorldRender.swift
//  CavernSeer
//
//  Created by Samuel Grush on 7/11/20.
//  Copyright © 2020 Samuel K. Grush. All rights reserved.
//

import SwiftUI /// View
import SceneKit /// SCN*
import RealityKit

struct PlanProjectedMiniWorldRender: View {

    @EnvironmentObject
    var imageSharer: ShareSheetUtility

    var scan: ScanFile
    var settings: SettingsStore

    var selection: SurveyStation? = nil

    var overlays: [SCNDrawSubview]? = nil

    var showUI: Bool = true

    var initialHeight: Float? = nil

    @State private var prevSelection: SurveyStation?

    @State private var scaleBarModel = ScaleBarModel()

    @State private var height: Float = 1.5
    
    @State private var zFar: Float = 15.0
    
    @State private var rendAsWireframe = false

    @ObservedObject private var snapshotModel = SnapshotExportModel()

    @ObservedObject private var renderModel = GeneralRenderModel(render_mode: "2D")
    

    var body: some View {
        
        VStack {
            PlanProjectedMiniWorldRenderController(
                height: $height,
                zFar: $zFar,
                rendAsWireframe: $rendAsWireframe,
                renderModel: renderModel,
                snapshotModel: snapshotModel,
                selection: selection,
                prevSelection: $prevSelection,
                overlays: overlays,
                scaleBarModel: scaleBarModel,
                showUI: self.showUI
            )
            
            
            
//            .gesture(
//                // DragGesture that is used to get the tap location.  DragGesture is used because there is no
//                // location value provided with the TapGesture().  The location is used to perform hit testing
//                // on the sceneView (ScenekitView), our only NSViewRepresentable portion of code.
//                // The first node hit, the one closest to the camera, is returned and the name is stored in the
//                // State var statusText, which is used in the double tap gesture to focus.
//
////                DragGesture(minimumDistance: 0.0, coordinateSpace: .local)
//                DragGesture(coordinateSpace: .local)
//                    .onEnded({ value in
//                        var startLocation = value.startLocation
//                        print("\(startLocation)")
//                        // pass the startLocation into the hitTest() method
////                        startLocation.y = geometry.size.height - startLocation.y
////                        let hits = self.view hitTest(startLocation, options: [:])
////
////                        if hits.count > 0 {
////                            viewModel.statusText = hits.first?.node.name ?? ".."
////                            debugPrint("ball: \(hits.first?.node.name ?? "..")")
////                        } else {
////                            viewModel.statusText = ".."
////                        }
//                    })
//            )
            
            if self.showUI {
                HStack {
//                    Text(String(scaleBarModel.pt_to_meter))
//                    Divider().frame(maxHeight: 50)
                    Text(stepperLabel).padding(30)
                    Divider().frame(maxHeight: 50)
                    
                    VStack {
                    Stepper(
                        onIncrement: { self.height += 0.5 },
                        onDecrement: { self.height -= 0.5 },
                        label: { Text("Scale 0.5") }
                    )
                    Stepper(
                        onIncrement: { self.height += 0.1 },
                        onDecrement: { self.height -= 0.1 },
                        label: { Text("Scale 0.1") }
                    )
                    }
                    .frame(maxWidth: 200)
                    .padding(30)
                    Divider().frame(maxHeight: 50)
                    
                    VStack{
                        Text("zFar: \(String(format: "%.2f", self.zFar))")
                        Slider(
                            value: $zFar,
                            in: 0.15...15,
                            step: 0.05
                        )
                    }
                    .frame(maxWidth: 200)
                    Divider().frame(maxHeight: 50)
                    

                    Text("Render as wire frame") //.frame(width: 200, alignment: .center) //.frame(alignment: .center)
                    Toggle("", isOn: $rendAsWireframe).frame(maxWidth: 50)
                    
//                    Divider().frame(maxHeight: 50)
                    
                }
                .frame(maxHeight: 100)
                .padding(.bottom, 8)
            }
        }
        .snapshotMenus(for: _snapshotModel)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                [unowned snapshotModel, unowned renderModel, unowned imageSharer] in
                snapshotModel.promptButton(scan: scan, sharer: imageSharer)
                renderModel.doubleSidedButton()
            }
        }
        .onAppear(perform: self.onAppear)
        .onDisappear(perform: self.onDisappear)
        
    }
    
    
    func handleTap(_ gestureRecognize: UITapGestureRecognizer) {
            // retrieve the SCNView
            let view = SCNView(frame: .zero)
            // check what nodes are tapped
            let p = gestureRecognize.location(in: view)
            let hitResults = view.hitTest(p, options: [:])
        
            print(p)

            // check that we clicked on at least one object
            if hitResults.count > 0 {
                // retrieved the first clicked object
                let result = hitResults[0]
                
                print("\(result)")

                // get material for selected geometry element
                let material = result.node.geometry!.materials[(result.geometryIndex)]
                // highlight it
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 0.5
                // on completion - unhighlight
                SCNTransaction.completionBlock = {
                    SCNTransaction.begin()
                    SCNTransaction.animationDuration = 0.5

                    material.emission.contents = UIColor.black

                    SCNTransaction.commit()
                }

                material.emission.contents = UIColor.green

                SCNTransaction.commit()
            }
        }
    
    

    private func onAppear() {
        if (self.initialHeight != nil) {
            self.height = self.initialHeight!
        }
        self.renderModel.updateScanAndSettings(scan: scan, settings: settings)
    }

    private func onDisappear() {
        self.renderModel.dismantle()
    }

    private var stepperLabel: String {
        var preferred = settings.UnitsLength.fromMetric(Double(height))
        preferred.value = preferred.value.roundedTo(places: 2)

        return "Height: \(preferred.description)"
    }
}


    
//    @objc func handleTap(_ gestureRecognize: UIGestureRecognizer) {
//        // check what nodes are tapped
//        let p = gestureRecognize.location(in: view)
//        let hitResults = view.hitTest(p, options: [:])
//        // check that we clicked on at least one object
//        if hitResults.count > 0 {
//            // retrieved the first clicked object
//            let result = hitResults[0]
//
//            // get material for selected geometry element
//            let material = result.node.geometry!.firstMaterial
//
//            // highlight it
//            SCNTransaction.begin()
//            SCNTransaction.animationDuration = 0.5
//
//            // on completion - unhighlight
//            SCNTransaction.completionBlock = {
//                SCNTransaction.begin()
//                SCNTransaction.animationDuration = 0.5
//
//                material?.emission.contents = UIColor.black
//
//                SCNTransaction.commit()
//            }
//
//            material?.emission.contents = UIColor.green
//
//            SCNTransaction.commit()
//        }
//    }


class SCNDrawSubview : UIView {
    func parentMade(view: SCNView) {}
    func parentUpdated(view: SCNView) {}
    func parentRender(renderer: SCNSceneRenderer) {}
    func parentDismantled(view: SCNView) {}
}

//struct PlanProjectedMiniWorldRender: UIViewRepresentable {
//
//    func makeUIView(context: Context) -> UIView{
//        view
//    }
//
//    func updateUIView(_ uiView: UIViewType, context: Context) {
//    }
//}

final class PlanProjectedMiniWorldRenderController : UIViewController, BaseProjectedMiniWorldRenderController {

    let showUI: Bool

    var overlays: [SCNDrawSubview]?

    @Binding
    var height: Float
    @Binding
    var zFar: Float
    @Binding
    var rendAsWireframe: Bool
    
    var selectedStation: SurveyStation?
    @Binding
    var prevSelected: SurveyStation?
    unowned var scaleBarModel: ScaleBarModel
    unowned var snapshotModel: SnapshotExportModel
    unowned var renderModel: GeneralRenderModel

    init(
        height: Binding<Float>,
        zFar: Binding<Float>,
        rendAsWireframe: Binding<Bool>,
        renderModel: GeneralRenderModel,
        snapshotModel: SnapshotExportModel,
        selection: SurveyStation?,
        prevSelection: Binding<SurveyStation?>,
        overlays: [SCNDrawSubview]?,
        scaleBarModel: ScaleBarModel,
        showUI: Bool
    ) {
        self._height = height
        self._zFar = zFar
        self._rendAsWireframe = rendAsWireframe
        self.renderModel = renderModel
        self.snapshotModel = snapshotModel
        self.selectedStation = selection
        self._prevSelected = prevSelection
        self.overlays = overlays
        self.scaleBarModel = scaleBarModel
        self.showUI = showUI

        super.init(nibName: nil, bundle: nil)
        
        
    }


    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func postSceneAttachment(sceneView: SCNView) {
        sceneView.allowsCameraControl = true
        sceneView.defaultCameraController.interactionMode = .pan
        sceneView.backgroundColor = .white
        self.overlays?.forEach { $0.parentMade(view: sceneView) }
    }

    func viewUpdater(uiView: SCNView) {
        
        if rendAsWireframe {uiView.debugOptions = .renderAsWireframe}
//        uiView
        else {uiView.debugOptions.subtract(.renderAsWireframe)}
        
//        uiView.hitTest(<#T##CGPoint#>)
//        uiView.debugOptions = .showBoundingBoxes
//        uiView.debugOptions = .showWorldOrigin
        
        let pov = uiView.pointOfView
        if pov != nil {
            let pos = pov!.position
            
            let move = SCNAction.moveBy(
                x: 0,
                y: CGFloat(Float(height) - pos.y),
                z: 0, duration: 0.1
            )
            pov!.runAction(move)

            pov!.camera?.fieldOfView = uiView.frame.size.width
            pov!.camera?.zFar = Double(zFar)
        }

        self.snapshotModel.viewUpdaterHandler(
            scnView: uiView,
            overlay: self.scaleBarModel.scene
        )

        self.overlays?.forEach { $0.parentUpdated(view: uiView) }
        
        
    }

    func makeaCamera() -> SCNNode {
        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.orthographicScale = 1 //Init zoom
        camera.projectionDirection = .horizontal
        camera.zNear = 0.1
        camera.zFar = 1.0 //If zFar = 1000, View from zNear to the bottom; if zFar value decrease, see only one section

        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 0)
        cameraNode.eulerAngles = SCNVector3Make(.pi / -2, 0, 0)

        return cameraNode
    }
    

    func renderer(
        _ renderer: SCNSceneRenderer,
        willRenderScene scene: SCNScene,
        atTime time: TimeInterval
    ) {
        self.willRenderScene(renderer, scene: scene, atTime: time)
        self.overlays?.forEach { $0.parentRender(renderer: renderer) }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scaleBarModel.updateOverlay(bounds: view.frame)
    }

    static func dismantleUIView(_ uiView: SCNView, coordinator: ()) {
        uiView.subviews
            .compactMap { return $0 as? SCNDrawSubview }
            .forEach { $0.parentDismantled(view: uiView) }
    }
    
//    func setupGestures(uiView: SCNView) {
//        let tapRecognizer = UITapGestureRecognizer(
//            target: self,
//            action: #selector(handleTap(_:))
//        )
//        uiView.addGestureRecognizer(tapRecognizer)
//        self.tapRecognizer = tapRecognizer
//    }
}




