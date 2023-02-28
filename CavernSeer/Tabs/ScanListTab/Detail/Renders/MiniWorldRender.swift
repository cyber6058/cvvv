//
//  MiniWorldRender.swift
//  CavernSeer
//
//  Created by Samuel Grush on 7/7/20.
//  Copyright © 2020 Samuel K. Grush. All rights reserved.
//
import SwiftUI
import SceneKit

struct MiniWorldRenderController: UIViewRepresentable {
    
    class Coordinator: NSObject, SCNSceneRendererDelegate {
        var parent: MiniWorldRenderController
        
        init(_ parent: MiniWorldRenderController) {
            self.parent = parent
        }
        
        func renderer(_ renderer: SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: TimeInterval) {
            self.parent.snapshotModel.viewUpdaterHandler(scnView: renderer as! SCNView)
            self.parent.renderModel.viewUpdateHandler(scnView: renderer as! SCNView)
        }
    }
    
    var snapshotModel: SnapshotExportModel
    var renderModel: GeneralRenderModel
    
    func makeUIView(context: Context) -> SCNView {
        let sceneView = SCNView(frame: .zero)
        sceneView.backgroundColor = UIColor.white
        sceneView.scene = makeaScene()
        sceneView.showsStatistics = true
        sceneView.allowsCameraControl = true
        sceneView.autoenablesDefaultLighting = true
        sceneView.isPlaying = true
        sceneView.delegate = context.coordinator
        
        return sceneView
    }
    
    func updateUIView(_ scnView: SCNView, context: Context) {
        scnView.defaultCameraController.interactionMode = self.renderModel.interactionMode3d
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }
    
    private func makeaScene() -> SCNScene {
        let scene = SCNScene()
        let cameraNode = SCNNode()
        cameraNode.name = "the-camera"
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(x: 0, y: 10, z: 35)
        scene.rootNode.addChildNode(cameraNode)
        renderModel.sceneNodes.forEach {
            node in
            scene.rootNode.addChildNode(node)
        }
        let ambientLightNode = SCNNode()
        ambientLightNode.name = "ambient-light"
        ambientLightNode.light = SCNLight()
        ambientLightNode.light!.type = .ambient
        if let ambientColor = renderModel.ambientColor {
            ambientLightNode.light!.color = ambientColor
        }
        scene.rootNode.addChildNode(ambientLightNode)
        return scene
    }
}

struct MiniWorldRender: View {

    @EnvironmentObject
    var imageSharer: ShareSheetUtility

    
    var scan: ScanFile
    var settings: SettingsStore
    var render_mode_for_renderer: String
    
    @State
    var stat_ind: Int = 0
    
    init(scan: ScanFile, settings: SettingsStore, render_mode_for_renderer: String){
        self.scan = scan
        self.settings = settings
        self.render_mode_for_renderer = render_mode_for_renderer
        self.renderModel = GeneralRenderModel(render_mode: render_mode_for_renderer)
    }

    @ObservedObject
    private var snapshotModel = SnapshotExportModel()

    @ObservedObject
    private var renderModel: GeneralRenderModel
    var body: some View {
        
        ZStack{
            MiniWorldRenderController(
                snapshotModel: snapshotModel, renderModel: renderModel
        )
        .snapshotMenus(for: _snapshotModel)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                [unowned snapshotModel, unowned renderModel, unowned imageSharer] in
                snapshotModel.promptButton(scan: scan, sharer: imageSharer)
                renderModel.doubleSidedButton()
            }
        }
        .onAppear(perform: self.appeared)
        }
    }

    private func appeared() {
        self.renderModel.updateScanAndSettings(scan: scan, settings: settings)
    }
}


